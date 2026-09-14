vim.o.foldcolumn = '1' -- show fold indicators in the gutter
vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
vim.o.foldlevelstart = 99
vim.o.foldenable = true

-- Filetypes where treesitter-based folds are worthwhile (parsers installed via
-- treesitter.lua's ensure_installed). Everything else falls back to indent
-- folding, which is cheap and requires no parser.
local ts_fold_filetypes = {
  c = true,
  cpp = true,
  rust = true,
  javascript = true,
  javascriptreact = true,
  typescript = true,
  typescriptreact = true,
  tsx = true,
  java = true,
  markdown = true,
}

require('ufo').setup({
  provider_selector = function(bufnr, filetype, buftype)
    -- Don't run any fold provider on big files -- bigfile.lua already forced
    -- foldmethod=manual / foldenable=false for those buffers.
    if vim.b[bufnr] and vim.b[bufnr].is_big_file then
      return ''
    end
    -- Don't fold special/non-file buffers (terminals, pickers, dap UI, ...).
    if buftype ~= '' then
      return ''
    end
    -- Treesitter folds for selected filetypes, indent as the universal fallback.
    if ts_fold_filetypes[filetype] then
      return { 'treesitter', 'indent' }
    end
    return { 'indent' }
  end,
})

-- Using ufo provider need remap `zR` and `zM`. If Neovim is 0.6.1, remap yourself
vim.keymap.set('n', 'zR', require('ufo').openAllFolds)
vim.keymap.set('n', 'zM', require('ufo').closeAllFolds)
