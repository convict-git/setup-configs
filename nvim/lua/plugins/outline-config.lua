-- Outline.nvim -- persistent symbols sidebar, always open on the right.
--
-- 'coc' is listed before 'lsp' in the provider priority since this config
-- uses coc.nvim (not native vim.lsp) for every language server.
require('outline').setup({
  providers = {
    priority = { 'coc', 'lsp', 'markdown', 'man' },
  },
  outline_window = {
    position = 'right',
    width = 17,
    relative_width = true,
    -- Opening/switching buffers shouldn't steal focus from the source
    -- window; the sidebar updates itself via outline_items.auto_update_events.
    focus_on_open = false,
  },
})

-- Keep it open for the whole session, across buffer/window switches --
-- outline.nvim's own auto_update_events (WinEnter/BufEnter/...) already
-- refreshes the symbol tree to match whatever buffer or pane is active.
vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    vim.cmd('OutlineOpen')
  end,
})

vim.keymap.set('n', '<leader>o', ':Outline<CR>', { silent = true, desc = 'Toggle symbols outline' })
