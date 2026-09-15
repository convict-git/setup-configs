-- line-highlight.lua
--
-- Tints the whole screen line (full window width) of every line containing
-- a configured piece of text -- e.g. `todo convict`, `FIXME`. The rest of the
-- highlighting (treesitter/syntax foreground colors) is kept on top of it.
--
-- Setup (see init.lua):
--   require('plugins/line-highlight').setup({
--     extensions = { 'lua', 'ts', 'tsx' }, -- optional; omit for all files
--     rules = {
--       { text = 'todo convict', hl = 'DiffText' },       -- literal substring
--       { pattern = '%f[%w]FIXME%f[%W]', hl = 'DiffDelete' }, -- Lua pattern
--     },
--   })
-- Rules are tried in order; the first one that matches a line wins. Prefer
-- `text`: a literal search is several times cheaper per redrawn line than a
-- pattern with classes/frontiers (a pattern without magic chars is searched
-- literally anyway).
--
-- `extensions` applies to the whole plugin: a buffer whose file name doesn't
-- end in one of them is never looked at. Matching is case-insensitive, a
-- leading dot is optional (`'.ts'` == `'ts'`), and only the last extension
-- counts (`foo.test.ts` is `ts`; `.env`, `Makefile` and unnamed buffers have
-- none). Not given (or empty) means every file.
--
-- Performance: this runs inside Neovim's redraw loop and does no work outside
-- of it. A decoration provider sets *ephemeral* extmarks from on_line, i.e.
-- only for lines Neovim is already redrawing -- no autocmds, no
-- nvim_buf_attach, no timers, and no persistent extmarks to keep in sync with
-- edits (the built-in treesitter highlighter works the same way). on_win
-- returns false for non-file buffers (terminals, help, quickfix, plugin
-- sidebars), files with a non-allowed extension, diff windows and big files
-- (see bigfile.lua), so on_line is never called for them. Per redrawn line it costs one nvim_buf_get_lines plus a
-- string.find per rule, searching at most MAX_COLS bytes so a long (e.g.
-- minified) line can't turn a redraw into a scan.
--
-- Why not an existing plugin: paint.nvim and todo-comments.nvim only
-- highlight the matched text, not the line; mini.hipatterns can be bent into
-- line highlights but syncs persistent extmarks via buffer attach, debounce
-- timers and whole-buffer rescans.
--
-- Uses `hl_group` + `hl_eol` over the line rather than `line_hl_group`:
-- ephemeral extmarks don't render `line_hl_group` (checked on Nvim 0.11).

local api = vim.api
local bigfile = require('plugins/bigfile')

local M = {}

local ns = api.nvim_create_namespace('line_highlight')

-- Only this many leading bytes of a line are searched.
local MAX_COLS = 1000

-- Below the default extmark priority (4096) and treesitter's (100), so any
-- other highlight on the line -- search, diagnostics, DAP -- stays on top.
local PRIORITY = 10

---@type { needle: string, plain: boolean, hl: string }[]
local rules = {}

-- Set of allowed lowercase extensions (no dot); nil = every file.
---@type table<string, true>|nil
local extensions = nil

local function has_allowed_extension(bufnr)
  if not extensions then
    return true
  end
  -- The [^/] keeps a leading-dot name (`/x/.env`) from counting as `env`.
  local ext = api.nvim_buf_get_name(bufnr):match('[^/]%.([^./]+)$')
  return ext ~= nil and extensions[ext:lower()] == true
end

-- Diff windows are skipped too: a tint there would read as a diff hunk.
local function on_win(_, winid, bufnr)
  return api.nvim_get_option_value('buftype', { buf = bufnr }) == ''
    and has_allowed_extension(bufnr)
    and not api.nvim_get_option_value('diff', { win = winid })
    and not bigfile.is_big_buffer(bufnr)
end

local function on_line(_, _, bufnr, row)
  local line = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  if not line or line == '' then
    return
  end
  if #line > MAX_COLS then
    line = line:sub(1, MAX_COLS)
  end
  for i = 1, #rules do
    local rule = rules[i]
    if line:find(rule.needle, 1, rule.plain) then
      api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
        end_row = row + 1,
        end_col = 0,
        hl_group = rule.hl,
        hl_eol = true,
        priority = PRIORITY,
        ephemeral = true,
      })
      return
    end
  end
end

local function notify_error(msg)
  vim.notify('[line-highlight] ' .. msg, vim.log.levels.ERROR)
end

function M.setup(opts)
  opts = opts or {}

  -- Invalid config is reported and skipped rather than raised: an error here
  -- would abort the rest of init.lua.
  extensions = nil
  if opts.extensions ~= nil and type(opts.extensions) ~= 'table' then
    notify_error('`extensions` must be a list of strings; enabling for all files')
  end
  for i, ext in ipairs(type(opts.extensions) == 'table' and opts.extensions or {}) do
    local name = type(ext) == 'string' and ext:gsub('^%.', ''):lower() or ''
    if name ~= '' then
      extensions = extensions or {}
      extensions[name] = true
    else
      notify_error(('extension %d skipped: must be a non-empty string'):format(i))
    end
  end

  rules = {}
  for i, rule in ipairs(opts.rules or {}) do
    local needle = rule.text or rule.pattern
    local plain = rule.text ~= nil
    -- A malformed Lua pattern would otherwise error on every redraw.
    local ok = type(needle) == 'string' and needle ~= '' and type(rule.hl) == 'string'
      and pcall(string.find, '', needle, 1, plain)
    if ok then
      table.insert(rules, { needle = needle, plain = plain, hl = rule.hl })
    else
      notify_error(('rule %d skipped: needs `text` or a valid Lua `pattern`, and `hl`'):format(i))
    end
  end

  if #rules == 0 then
    api.nvim_set_decoration_provider(ns, {})
    return
  end
  api.nvim_set_decoration_provider(ns, { on_win = on_win, on_line = on_line })
end

return M
