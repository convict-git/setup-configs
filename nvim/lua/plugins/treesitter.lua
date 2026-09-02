-- Disable treesitter highlighting for big files. Honors the per-buffer flag set
-- by bigfile.lua, and also does an independent size check as a safety net (in
-- case treesitter attaches to a buffer bigfile.lua never saw).
local function disable_for_big(_lang, buf)
  if vim.b[buf] and vim.b[buf].is_big_file then
    return true
  end
  local max_filesize = 512 * 1024 -- 512 KB
  local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
  if ok and stats and stats.size > max_filesize then
    return true
  end
  return false
end

require'nvim-treesitter.configs'.setup {
  -- A list of parser names, or "all" (the listed parsers MUST always be installed)
  ensure_installed = { "c",  "cpp", "rust", "typescript", "tsx", "javascript", "java", "markdown", "markdown_inline" },

  -- Install parsers synchronously (only applied to `ensure_installed`)
  sync_install = false,

  -- Don't auto-compile parsers when entering an unfamiliar filetype. This avoids
  -- surprise `tree-sitter` compiles (which can stall on opening a file). The
  -- parsers we actually use are covered by `ensure_installed` above.
  auto_install = false,

  highlight = {
    enable = true,

    -- Turn treesitter highlight off for large buffers so editing stays snappy.
    disable = disable_for_big,

    -- Keep only one highlighter active (treesitter). Running :syntax alongside
    -- it is slower and causes duplicate highlights.
    additional_vim_regex_highlighting = false,
  },
}
