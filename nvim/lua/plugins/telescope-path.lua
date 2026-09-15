-- Shared `path_display` for Telescope pickers.
--
-- Shows the path relative to cwd and elides it on the LEFT, so the filename --
-- the part anyone actually scans for -- always stays visible:
--
--   …ercharged/lua/spr/ai-assistants/providers.lua
--
-- Telescope's built-in { "truncate" } elides on the left too, but it always
-- measures against the whole results window rather than the column the path is
-- rendered in. Pickers that put the path in a fixed-width column (quickfix, LSP
-- locations, coc locations) then clip the already-elided string on the right,
-- cutting off the filename from both ends. This measures the actual column when
-- the picker declares one (`fname_width`) and falls back to the results window.

local M = {}

-- room for the ":lnum:col" some pickers append after the path
local SUFFIX_RESERVE = 9

local function results_width()
  local ok, status = pcall(require("telescope.state").get_status, vim.api.nvim_get_current_buf())
  if not ok or not status.results_win or not vim.api.nvim_win_is_valid(status.results_win) then
    return vim.o.columns
  end
  local caret = status.picker and #status.picker.selection_caret or 0
  return vim.api.nvim_win_get_width(status.results_win) - caret - 2
end

function M.display(opts, path)
  local rel = vim.fn.fnamemodify(path, ":.")
  local width = (opts.fname_width or results_width()) - SUFFIX_RESERVE
  if width > 0 and #rel > width then
    rel = "…" .. rel:sub(#rel - width + 1)
  end
  return rel
end

return M
