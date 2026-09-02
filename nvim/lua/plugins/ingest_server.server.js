#!/usr/bin/env node
"use strict";

// Standalone HTTP log-ingest server for the `ingest_server` Neovim plugin.
//
// Runs as its own Node.js process (spawned/managed by ingest_server.lua) so the
// blocking work of reading request bodies never touches Neovim's event loop.
//
// The log is kept small: entries are batched in memory, the in-memory view is
// capped to the last N lines, and the file is rewritten on a throttled timer
// instead of on every request.
//
// Endpoints:
//   POST|GET|PUT /ingest/<channel>  -> appends the payload to the log
//   GET          /health            -> {"status":"ok", ...} for health checks
//   OPTIONS *                       -> CORS preflight (204)
//
// Usage:
//   node ingest_server.server.js --port 9099 --logfile /path/to/ingest.log \
//        --max-lines 50 --flush-ms 500
//
// Env fallbacks: INGEST_PORT, INGEST_HOST, INGEST_LOGFILE, INGEST_MAX_BODY,
//                INGEST_MAX_LINES, INGEST_FLUSH_MS.

const http = require("http");
const fs = require("fs");
const path = require("path");

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--port") out.port = argv[++i];
    else if (a === "--host") out.host = argv[++i];
    else if (a === "--logfile") out.logfile = argv[++i];
    else if (a === "--max-body") out.maxBody = argv[++i];
    else if (a === "--max-lines") out.maxLines = argv[++i];
    else if (a === "--flush-ms") out.flushMs = argv[++i];
  }
  return out;
}

const args = parseArgs(process.argv.slice(2));

const PORT = parseInt(args.port || process.env.INGEST_PORT || "9099", 10);
const HOST = args.host || process.env.INGEST_HOST || "127.0.0.1";
const LOGFILE =
  args.logfile ||
  process.env.INGEST_LOGFILE ||
  path.join(process.cwd(), "ingest.log");
const MAX_BODY = parseInt(
  args.maxBody || process.env.INGEST_MAX_BODY || String(10 * 1024 * 1024),
  10,
);
const MAX_LINES = Math.max(
  1,
  parseInt(args.maxLines || process.env.INGEST_MAX_LINES || "50", 10),
);
const FLUSH_MS = Math.max(
  50,
  parseInt(args.flushMs || process.env.INGEST_FLUSH_MS || "500", 10),
);

fs.mkdirSync(path.dirname(LOGFILE), { recursive: true });

// ---------------------------------------------------------------------------
// In-memory batched, line-capped log
// ---------------------------------------------------------------------------

// The complete, capped view of the file lives in `lines`. Requests mutate it in
// memory; a throttled timer rewrites the whole (small) file only when dirty.
let lines = loadExisting();
let dirty = false;

function loadExisting() {
  try {
    const raw = fs.readFileSync(LOGFILE, "utf8");
    const existing = raw.split("\n");
    if (existing.length && existing[existing.length - 1] === "") existing.pop();
    return existing.slice(-MAX_LINES);
  } catch {
    return [];
  }
}

function timestamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return (
    d.getFullYear() +
    "-" +
    pad(d.getMonth() + 1) +
    "-" +
    pad(d.getDate()) +
    "T" +
    pad(d.getHours()) +
    ":" +
    pad(d.getMinutes()) +
    ":" +
    pad(d.getSeconds())
  );
}

function writeLog(channel, payload) {
  const label = channel && channel.length ? channel : "-";
  const header = `[${timestamp()}] [${label}]`;
  const body = payload == null ? "" : String(payload);

  if (body.indexOf("\n") !== -1) {
    // Multi-line: header line, raw body lines, then a blank separator.
    lines.push(header);
    for (const l of body.split("\n")) lines.push(l);
    lines.push("");
  } else {
    lines.push(`${header} ${body}`);
  }

  // Cap to the most recent MAX_LINES lines.
  if (lines.length > MAX_LINES) lines = lines.slice(-MAX_LINES);
  dirty = true;
}

function flush() {
  if (!dirty) return;
  dirty = false;
  const out = lines.length ? lines.join("\n") + "\n" : "";
  fs.writeFile(LOGFILE, out, (err) => {
    if (err) {
      // Retry on the next tick by marking dirty again.
      dirty = true;
      process.stderr.write(`[ingest] log write failed: ${err.message}\n`);
    }
  });
}

const flushTimer = setInterval(flush, FLUSH_MS);
flushTimer.unref();

// ---------------------------------------------------------------------------
// HTTP
// ---------------------------------------------------------------------------

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, OPTIONS",
  "Access-Control-Allow-Headers": "*",
};

function channelFromPath(pathname) {
  const m = pathname.match(/^\/ingest\/(.*)$/);
  if (m) return m[1].replace(/\/+$/, "");
  if (pathname === "/ingest") return "";
  return null;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${HOST}:${PORT}`);
  const pathname = url.pathname;

  if (req.method === "OPTIONS") {
    res.writeHead(204, CORS);
    res.end();
    return;
  }

  if (pathname === "/health") {
    res.writeHead(200, { "Content-Type": "application/json", ...CORS });
    res.end(
      JSON.stringify({
        status: "ok",
        port: PORT,
        logfile: LOGFILE,
        pid: process.pid,
        maxLines: MAX_LINES,
        bufferedLines: lines.length,
      }),
    );
    return;
  }

  const channel = channelFromPath(pathname);
  if (channel === null) {
    res.writeHead(404, { "Content-Type": "text/plain", ...CORS });
    res.end("not found (use /ingest/<channel>)\n");
    return;
  }

  let size = 0;
  let tooLarge = false;
  const chunks = [];

  req.on("data", (chunk) => {
    size += chunk.length;
    if (size > MAX_BODY) {
      tooLarge = true;
      req.destroy();
      return;
    }
    chunks.push(chunk);
  });

  req.on("end", () => {
    if (tooLarge) return;
    let payload = Buffer.concat(chunks).toString("utf8");
    if (!payload && url.search) payload = url.search.replace(/^\?/, "");
    writeLog(channel, payload);
    res.writeHead(200, { "Content-Type": "text/plain", ...CORS });
    res.end("ok\n");
  });

  req.on("error", () => {
    if (!res.headersSent) {
      res.writeHead(400, { "Content-Type": "text/plain", ...CORS });
      res.end("bad request\n");
    }
  });
});

server.on("error", (err) => {
  process.stderr.write(`[ingest] server error: ${err.message}\n`);
  process.exit(1);
});

server.listen(PORT, HOST, () => {
  process.stdout.write(
    `[ingest] listening on http://${HOST}:${PORT}/ingest/  ->  ${LOGFILE} (cap ${MAX_LINES} lines)\n`,
  );
});

function shutdown() {
  clearInterval(flushTimer);
  // Final synchronous flush so nothing batched is lost on exit.
  try {
    if (dirty)
      fs.writeFileSync(LOGFILE, lines.length ? lines.join("\n") + "\n" : "");
  } catch {}
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 1000).unref();
}

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
