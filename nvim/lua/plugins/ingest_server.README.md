# ingest_server

A tiny HTTP log-ingest server for debugging Node.js apps and React components
straight from the browser/runtime via `fetch()`. Send anything to
`http://127.0.0.1:<port>/ingest/<channel>` and it gets appended to a log file.

## Architecture

The actual HTTP server runs as a **standalone Node.js process**
(`ingest_server.server.js`), spawned and supervised by the Lua plugin
(`ingest_server.lua`). Request bodies are read in that separate process, so a
slow or large POST can **never block Neovim's event loop** (the reason the old
pure-Lua/libuv version hung). The Lua side only handles orchestration:
start / stop / status (health check) / open the log / clear it.

To keep the log small and cheap, entries are **batched in memory**, the view is
**capped to the last `max_lines` lines** (default 50), and the file is rewritten
on a **throttled timer** (`flush_ms`, default 500 ms) rather than on every
request.

The server is **not started automatically** — run `:IngestStart` when you want
to capture logs.

Requires `node` on your `PATH`. No npm dependencies.

## Setup (`init.lua`)

```lua
-- ingest log server: POST/GET http://127.0.0.1:<port>/ingest/<channel> -> log file
require('plugins/ingest_server').setup({ port = 9099 })
```

### Options

| Option       | Default                                    | Description                                     |
| ------------ | ------------------------------------------ | ----------------------------------------------- |
| `port`       | `9099`                                     | Port bound on `host`.                           |
| `host`       | `"127.0.0.1"`                              | Interface to bind (keep on loopback).           |
| `logfile`    | `stdpath("state") .. "/ingest/ingest.log"` | Absolute path of the log file.                  |
| `node`       | `"node"`                                   | Node executable used to run the server.         |
| `script`     | `<plugin dir>/ingest_server.server.js`     | Path to the server script.                      |
| `auto_start` | `false`                                    | Start the server when `setup()` runs.           |
| `max_body`   | `10 * 1024 * 1024`                         | Reject request bodies larger than this (bytes). |
| `max_lines`  | `50`                                       | Cap the log file to the most recent N lines.    |
| `flush_ms`   | `500`                                      | Throttle interval for batched disk writes (ms). |

## Commands

| Command          | Description                                        |
| ---------------- | -------------------------------------------------- |
| `:IngestStart`   | Start the Node server on the configured port.      |
| `:IngestStop`    | Stop the Node server and free the port.            |
| `:IngestRestart` | Restart the server.                                |
| `:IngestStatus`  | Report process state and probe `/health`.          |
| `:IngestOpen`    | Open the log file in a split and tail it live.     |
| `:IngestClear`   | Truncate the log file.                             |

A typical session: `:IngestOpen` to tail the log in a split, then trigger
`fetch()` calls from your app and watch entries stream in. The Node process is
stopped automatically when Neovim exits.

## Endpoints

| Method            | Path                | Behaviour                                        |
| ----------------- | ------------------- | ------------------------------------------------ |
| `POST`/`GET`/`PUT`| `/ingest/<channel>` | Append the payload (or query string) to the log. |
| `GET`             | `/health`           | `{"status":"ok", ...}` for health checks.        |
| `OPTIONS`         | `*`                 | CORS preflight (`204`).                           |

## JavaScript `fetch()` examples

The path segment after `/ingest/` becomes the channel label in the log. CORS is
enabled (including preflight), so browser-side requests from any dev origin work.

```js
// React component — log props/state on render
fetch('http://127.0.0.1:9099/ingest/render', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ props, state }),
});

// Node.js — plain-text log line
fetch('http://127.0.0.1:9099/ingest/api', { method: 'POST', body: 'request received' });

// Quick GET ping — the query string is logged (no body needed)
fetch('http://127.0.0.1:9099/ingest/debug?msg=reached%20here');
```

A tiny helper you can drop into a project:

```js
const ingest = (channel, data) =>
  fetch(`http://127.0.0.1:9099/ingest/${channel}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: typeof data === 'string' ? data : JSON.stringify(data),
  }).catch(() => {}); // never let logging break the app

ingest('cart', { items: cart.length, total });
```

## Log format

Single-line payloads are written inline; multi-line payloads get a header line
followed by the raw body:

```
[2026-09-02T11:00:03] [api] request received
[2026-09-02T11:00:05] [render]
{"props":1,"state":"ok"}

[2026-09-02T11:00:09] [debug] msg=reached here
```
