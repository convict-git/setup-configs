-- Adds in react dev tools:
-- "Settings" -> "General" -> "Open in Editor URL" -> "Custom" -> "http://localhost:4000/file/{path}:{line}:{column}"

local M = {}
local uv = vim.loop

local PORT = 4000
local server_started = false

local function parse_request(data)
  local method, path = data:match("^(%u+)%s+(/[^%s]*)")
  if not method or not path then
    return nil
  end

  local file_req = path:match("^/file/(.*)")
  if not file_req then
    return nil
  end

  local filepath, line, col = file_req:match("^(.*):(%d+):(%d+)$")
  if not filepath then
    return nil
  end

  return filepath, tonumber(line), tonumber(col)
end

local function open_file(filepath, line, col)
  vim.schedule(function()
    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
    vim.api.nvim_win_set_cursor(0, { line, col })
  end)
end

local server_handle = nil

function start()
  if server_started then
    vim.notify("[file_server] Server already running", vim.log.levels.INFO)
    return
  end

  local server = uv.new_tcp()
  local ok, bind_err = pcall(function()
    assert(server:bind("127.0.0.1", PORT))
  end)
  if not ok then
    vim.notify(
      "[file_server] Could not bind port " .. PORT .. " (" .. tostring(bind_err) .. ")",
      vim.log.levels.WARN
    )
    pcall(function() server:close() end)
    return
  end
  server_handle = server

  server:listen(128, function(err)
    if err then
      print("Server error: ", err)
      return
    end

    local client = uv.new_tcp()
    server:accept(client)

    client:read_start(function(err, data)
      if err then
        print("Read error: ", err)
        return
      end

      if data then
        local filepath, line, col = parse_request(data)

        if filepath then
          open_file(filepath, line, col)
        end

        local response = table.concat({
            "HTTP/1.1 200 OK",
            "Content-Type: text/html; charset=utf-8",
            "Connection: close",   -- ensures browser knows server is done
            "",
            [[
          <!DOCTYPE html>
          <html>
          <body>
          <script>
            window.close();
          </script>
          <p>If the tab does not close automatically, close it manually.</p>
          </body>
          </html>
          ]]
          }, "\r\n")


        -- local response =
        --   "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nOK"
        client:write(response)
      else
        client:close()
      end
    end)
  end)

  server_started = true
  vim.notify("[file_server] Running on http://localhost:" .. PORT)
end

local function stop()
  if server_handle then
    pcall(function() server_handle:close() end)
    server_handle = nil
  end
  server_started = false
  vim.notify("[file_server] Stopped", vim.log.levels.INFO)
end

vim.api.nvim_create_user_command("FileServerStart", start, {})
vim.api.nvim_create_user_command("FileServerStop", stop, {})

-- Not started automatically -- run :FileServerStart when you need the React
-- "Open in Editor URL" workflow. Use :FileServerStop to stop it.
