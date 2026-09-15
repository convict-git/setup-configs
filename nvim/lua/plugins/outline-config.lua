-- Outline.nvim -- persistent symbols sidebar, always open on the right.
--
-- 'coc' is listed before 'lsp' in the provider priority since this config
-- uses coc.nvim (not native vim.lsp) for every language server.

-- outline.nvim's coc provider feeds coc's documentSymbols result straight
-- into its local convert_symbols(), which assumes a non-empty list. coc
-- answers null (vim.NIL, userdata on the Lua side) whenever the buffer has no
-- symbols to give yet -- e.g. right after switching files while the language
-- server is still attaching -- and convert_symbols() dies on pairs(vim.NIL);
-- an empty list dies too, on s[#s].level. Re-issue the same request but hand
-- anything that isn't a non-empty list to outline as an empty outline, and
-- only run the plugin's own converter on real results. convert_symbols is
-- local to the provider, so it's pulled off request_symbols' upvalues; if a
-- plugin update renames it, the provider is left unpatched.
--
-- The require path must be the slash form: outline's find_provider() does
-- require('outline/providers/' .. name), and package.loaded is keyed by the
-- literal string, so require('outline.providers.coc') would load (and patch)
-- a second, separate copy of the module that outline never calls.
do
  local coc_provider = require('outline/providers/coc')
  local name, convert_symbols = debug.getupvalue(coc_provider.request_symbols, 1)
  if name == 'convert_symbols' and type(convert_symbols) == 'function' then
    coc_provider.request_symbols = function(on_symbols, opts)
      vim.fn.call('CocActionAsync', {
        'documentSymbols',
        function(_, symbols)
          if type(symbols) ~= 'table' or #symbols == 0 then
            on_symbols({}, opts)
          else
            on_symbols(convert_symbols(symbols), opts)
          end
        end,
      })
    end
  end
end

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
