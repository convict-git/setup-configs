-- ingest_server.lua
--
-- Orchestrates a standalone Node.js HTTP "log ingest" server (see
-- ingest_server.server.js next to this file). The heavy lifting -- reading
-- request bodies and writing the log file -- runs in a separate Node process so
-- it can never block Neovim's event loop. This plugin only manages that
-- process: start / stop / status (health check) / open the log / clear it.
--
-- POST/GET anything to `http://127.0.0.1:<port>/ingest/<channel>` and it gets
-- appended to the log file. Meant for debugging Node.js apps and React
-- components straight from the browser/runtime:
--
--   fetch('http://127.0.0.1:9099/ingest/render', {
--     method: 'POST',
--     headers: { 'Content-Type': 'application/json' },
--     body: JSON.stringify({ props, state }),
--   });
--
-- Setup (see init.lua):
--   require('plugins/ingest_server').setup({ port = 9099 })
--
-- Commands:
--   :IngestStart    start the Node server
--   :IngestStop     stop the Node server
--   :IngestStatus   report whether it's running + hit the /health endpoint
--   :IngestOpen     open the log file in a split and tail it live
--   :IngestClear    truncate the log file

local uv = vim.loop

local M = {}

-- Directory of this Lua file, so we can locate the sibling server.js.
local this_dir = (debug.getinfo(1, "S").source:sub(2)):match("(.*[/\\])") or "./"

local defaults = {
  port = 9099,
  host = "127.0.0.1",
  logfile = vim.fn.stdpath("state") .. "/ingest/ingest.log",
  -- Node executable and the server script (resolved next to this file).
  node = "node",
  script = this_dir .. "ingest_server.server.js",
  -- Start the server automatically when setup() is called. Off by default --
  -- use :IngestStart when you actually want to capture logs.
  auto_start = false,
  -- Reject request bodies larger than this many bytes (10 MB by default).
  max_body = 10 * 1024 * 1024,
  -- Keep the log file capped to the most recent N lines.
  max_lines = 50,
  -- Throttle interval (ms) for batching in-memory writes to disk.
  flush_ms = 500,
}

local state = {
  config = vim.deepcopy(defaults),
  job = nil, -- jobstart() id of the Node process
  running = false,
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function ensure_log_dir()
  local dir = vim.fn.fnamemodify(state.config.logfile, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

local function notify(msg, level)
  vim.notify("[ingest] " .. msg, level or vim.log.levels.INFO)
end

local function node_available()
  return vim.fn.executable(state.config.node) == 1
end

-- ---------------------------------------------------------------------------
-- Server lifecycle
-- ---------------------------------------------------------------------------

function M.start()
  if state.running then
    notify("already running on " .. state.config.host .. ":" .. state.config.port)
    return
  end

  if not node_available() then
    notify("'" .. state.config.node .. "' not found in PATH; cannot start server", vim.log.levels.ERROR)
    return
  end

  if vim.fn.filereadable(state.config.script) == 0 then
    notify("server script missing: " .. state.config.script, vim.log.levels.ERROR)
    return
  end

  ensure_log_dir()

  local cmd = {
    state.config.node,
    state.config.script,
    "--port", tostring(state.config.port),
    "--host", state.config.host,
    "--logfile", state.config.logfile,
    "--max-body", tostring(state.config.max_body),
    "--max-lines", tostring(state.config.max_lines),
    "--flush-ms", tostring(state.config.flush_ms),
  }

  local job = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      for _, line in ipairs(data or {}) do
        if line ~= "" then
          notify(line:gsub("^%[ingest%]%s*", ""))
        end
      end
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data or {}) do
        if line ~= "" then
          notify(line:gsub("^%[ingest%]%s*", ""), vim.log.levels.ERROR)
        end
      end
    end,
    on_exit = function(_, code)
      state.running = false
      state.job = nil
      if code ~= 0 then
        notify("server exited (code " .. code .. ")", vim.log.levels.WARN)
      end
    end,
  })

  if job <= 0 then
    notify("failed to launch node process", vim.log.levels.ERROR)
    return
  end

  state.job = job
  state.running = true
end

function M.stop()
  if not state.running or not state.job then
    notify("not running")
    return
  end
  vim.fn.jobstop(state.job)
  state.running = false
  state.job = nil
  notify("stopped")
end

function M.restart()
  M.stop()
  vim.defer_fn(function() M.start() end, 200)
end

-- Report process state, then probe the /health endpoint (async) to confirm the
-- server actually answers HTTP.
function M.status()
  if not state.running or not state.job then
    notify("stopped (configured port " .. state.config.port .. ")")
    return
  end

  local base = "http://" .. state.config.host .. ":" .. state.config.port
  notify("process running (job " .. state.job .. ") -> " .. base .. "/ingest/")

  if vim.fn.executable("curl") ~= 1 then
    return
  end

  vim.system(
    { "curl", "-s", "-m", "2", base .. "/health" },
    { text = true },
    vim.schedule_wrap(function(res)
      if res.code == 0 and res.stdout and res.stdout:find("\"status\"") then
        notify("health: " .. vim.trim(res.stdout))
      else
        notify("health check failed (server not answering yet)", vim.log.levels.WARN)
      end
    end)
  )
end

-- Open the log file and keep it tailing (autoread + checktime on a timer).
function M.open()
  ensure_log_dir()
  if vim.fn.filereadable(state.config.logfile) == 0 then
    local fh = io.open(state.config.logfile, "a")
    if fh then fh:close() end
  end

  vim.cmd("botright split " .. vim.fn.fnameescape(state.config.logfile))
  local bufnr = vim.api.nvim_get_current_buf()
  vim.bo[bufnr].autoread = true

  local timer = uv.new_timer()
  timer:start(0, 1000, vim.schedule_wrap(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      timer:stop()
      timer:close()
      return
    end
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("silent! checktime")
      vim.cmd("normal! G")
    end)
  end))
end

function M.clear()
  ensure_log_dir()
  local fh = io.open(state.config.logfile, "w")
  if fh then fh:close() end
  notify("cleared " .. state.config.logfile)
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------

local function create_commands()
  vim.api.nvim_create_user_command("IngestStart", function() M.start() end, { desc = "Start the ingest log server" })
  vim.api.nvim_create_user_command("IngestStop", function() M.stop() end, { desc = "Stop the ingest log server" })
  vim.api.nvim_create_user_command("IngestRestart", function() M.restart() end, { desc = "Restart the ingest log server" })
  vim.api.nvim_create_user_command("IngestStatus", function() M.status() end, { desc = "Show ingest server status + health" })
  vim.api.nvim_create_user_command("IngestOpen", function() M.open() end, { desc = "Open and tail the ingest log file" })
  vim.api.nvim_create_user_command("IngestClear", function() M.clear() end, { desc = "Clear the ingest log file" })
end

function M.setup(opts)
  state.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})

  create_commands()

  -- Stop the Node process when Neovim exits so the port is freed.
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      if state.running then M.stop() end
    end,
  })

  if state.config.auto_start then
    M.start()
  end

  return M
end

return M
