-- bigfile.lua
--
-- Performance guard for large buffers. When a file is "big" (>= 512 KB OR
-- >= 2500 lines), we strip every heavy feature *for that buffer only* so it
-- behaves like plain Vim and stays responsive:
--   - no treesitter highlight (see treesitter.lua's `disable`)
--   - no CoC (b:coc_enabled = 0, set before CoC attaches)
--   - no syntax, no folding machinery (foldmethod = manual)
--   - misc O(lines) editor features turned off (wrap/spell/list/undofile ...)
--
-- Detection runs in two passes so both thresholds work reliably:
--   - BufReadPre  : file size via fs_stat (buffer not loaded yet, so no line
--                   count available here). Runs *before* any plugin attaches.
--   - BufReadPost : line count fallback (still fires before FileType, i.e.
--                   before treesitter/CoC attach), for files that are long but
--                   under the byte threshold.
--
-- `vim.b.is_big_file` is the single source of truth; other configs read it.

local M = {}

local MAX_BYTES = 512 * 1024 -- 512 KB
local MAX_LINES = 2500

-- Apply the per-buffer "big file" treatment. Idempotent.
local function apply_big(bufnr)
  if vim.b[bufnr].is_big_file then
    return
  end
  vim.b[bufnr].is_big_file = true

  -- Prevent CoC from ever attaching to this buffer.
  vim.b[bufnr].coc_enabled = 0

  -- These are window/buffer local; the buffer being read is current for the
  -- BufReadPre/BufReadPost events, so opt_local targets the right place.
  vim.opt_local.foldmethod = "manual"
  vim.opt_local.foldenable = false
  vim.opt_local.foldcolumn = "0"
  vim.opt_local.signcolumn = "no"
  vim.opt_local.syntax = "off"
  vim.opt_local.spell = false
  vim.opt_local.list = false
  vim.opt_local.wrap = false
  vim.opt_local.undofile = false

  -- Belt and suspenders: stop treesitter if it somehow already started.
  pcall(vim.treesitter.stop, bufnr)

  vim.notify(
    "[bigfile] Large file detected -- heavy features disabled for this buffer",
    vim.log.levels.WARN
  )
end

-- Exposed so other configs can query without duplicating the flag name.
function M.is_big_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.b[bufnr].is_big_file == true
end

local group = vim.api.nvim_create_augroup("BigFilePerf", { clear = true })

-- Pass 1: byte size (most reliable, runs before anything attaches).
vim.api.nvim_create_autocmd("BufReadPre", {
  group = group,
  callback = function(args)
    local name = vim.api.nvim_buf_get_name(args.buf)
    local ok, stats = pcall(vim.loop.fs_stat, name)
    if ok and stats and stats.size > MAX_BYTES then
      apply_big(args.buf)
    end
  end,
})

-- Pass 2: line count (fires before FileType, so still pre-attach).
vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  callback = function(args)
    if vim.b[args.buf].is_big_file then
      return
    end
    if vim.api.nvim_buf_line_count(args.buf) > MAX_LINES then
      apply_big(args.buf)
    end
  end,
})

return M
