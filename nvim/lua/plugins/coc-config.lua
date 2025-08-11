-- Coc settings
vim.g.coc_global_extensions = {
  'coc-clangd', 'coc-cmake', 'coc-docker', 'coc-emmet', 'coc-eslint', 'coc-graphql',
  'coc-json', 'coc-git', 'coc-prettier', 'coc-rust-analyzer', 'coc-sh', 'coc-tsserver', 'coc-yaml', 'coc-floaterm', 'coc-java'
}

vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.signcolumn = 'yes'

vim.api.nvim_create_augroup("AirlineCoc", { clear = true })

vim.api.nvim_create_autocmd("User", {
  group = "AirlineCoc",
  pattern = { "CocStatusChange", "CocDiagnosticChange" },
  callback = function()
    vim.cmd("AirlineRefresh")
  end,
})

-- -- tab completion -- ToDo NOT yet able to migrate to LUA due to bugs
vim.cmd([[
  " Use tab for trigger completion with characters ahead and navigate
  " NOTE: There's always complete item selected by default, you may want to enable
  " no select by `"suggest.noselect": true` in your configuration file
  " NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
  " other plugin before putting this into your config
  inoremap <silent><expr><TAB>
        \ coc#pum#visible() ? coc#pum#next(1) :
        \ CheckBackspace() ? "\<Tab>" :
        \ coc#refresh()
  inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

  " Make <CR> to accept selected completion item or notify coc.nvim to format
  " <C-g>u breaks current undo, please make your own choice
  inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                                \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

  function! CheckBackspace() abort
    let col = col('.') - 1
    return !col || getline('.')[col - 1]  =~# '\s'
  endfunction

  " Use <c-space> to trigger completion
  inoremap <silent><expr> <c-@> coc#refresh()

  " Use K to show documentation in preview window
  nnoremap <silent> K :call ShowDocumentation()<CR>

  function! ShowDocumentation()
    if CocAction('hasProvider', 'hover')
      call CocActionAsync('doHover')
    else
      call feedkeys('K', 'in')
    endif
  endfunction
]])

-- diagnostics navigation
vim.keymap.set("n", "<C-S-m>", "<Plug>(coc-diagnostic-prev)", { silent = true })
vim.keymap.set("n", "<C-m>", "<Plug>(coc-diagnostic-next)", { silent = true })

-- git bindings
vim.keymap.set("n", "<C-S-n>", "<Plug>(coc-git-nextchunk)")
vim.keymap.set("n", "<leader>gnc", "<Plug>(coc-git-nextconflict)")
vim.keymap.set("n", "<leader>gci", "<Plug>(coc-git-chunkinfo)")
vim.keymap.set("n", "<leader>kr", ":CocCommand git.chunkUndo<CR>")

-- navigation
vim.keymap.set("n", "gD", "<Plug>(coc-definition)", { silent = true })
vim.keymap.set("n", "gv", ":call CocActionAsync('jumpDefinition')<CR>:wincmd v<CR>", { silent = true })
vim.keymap.set("n", "gy", "<Plug>(coc-type-definition)", { silent = true })
vim.keymap.set("n", "gi", "<Plug>(coc-implementation)", { silent = true })
vim.keymap.set("n", "gr", "<Plug>(coc-references)", { silent = true })


-- highlight symbol under cursor
vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    vim.fn.CocActionAsync('highlight')
  end
})

-- rename
vim.keymap.set("n", "<leader>rn", "<Plug>(coc-rename)")

-- code actions
vim.keymap.set("x", "<leader>as", "<Plug>(coc-codeaction-selected)")
vim.keymap.set("n", "<leader>ac", "<Plug>(coc-codeaction-cursor)")
vim.keymap.set("n", "<leader>qf", "<Plug>(coc-fix-current)")
vim.keymap.set("n", "<leader>re", "<Plug>(coc-codeaction-refactor)")
vim.keymap.set("x", "<leader>rs", "<Plug>(coc-codeaction-refactor-selected)")
vim.keymap.set("n", "<leader>rs", "<Plug>(coc-codeaction-refactor-selected)")
vim.keymap.set("n", "<leader>cl", "<Plug>(coc-codelens-action)")

-- selection ranges
vim.keymap.set("n", "<C-s>", "<Plug>(coc-range-select)", { silent = true })
vim.keymap.set("x", "<C-s>", "<Plug>(coc-range-select)", { silent = true })

-- coc list mappings
vim.keymap.set("n", "<space>a", ":<C-u>Telescope coc diagnostics<CR>", { silent = true })
vim.keymap.set("n", "<space>e", ":<C-u>Telescope coc extensions<CR>", { silent = true })
vim.keymap.set("n", "<space>c", ":<C-u>Telescope coc commands<CR>", { silent = true })
vim.keymap.set("n", "<space>o", ":<C-u>CocList outline<CR>", { silent = true })
vim.keymap.set("n", "<space>s", ":<C-u>CocList -I symbols<CR>", { silent = true })
vim.keymap.set("n", "<space>j", ":<C-u>CocNext<CR>", { silent = true })
vim.keymap.set("n", "<space>k", ":<C-u>CocPrev<CR>", { silent = true })
vim.keymap.set("n", "<space>p", ":<C-u>CocListResume<CR>", { silent = true })


-- commands
vim.api.nvim_create_user_command("Format", function()
  vim.fn.CocActionAsync('format')
end, {})

vim.api.nvim_create_user_command("Fold", function(opts)
  vim.fn.CocAction('fold', opts.args)
end, { nargs = '?' })

vim.api.nvim_create_user_command("OR", function()
  vim.fn.CocActionAsync('runCommand', 'editor.action.organizeImport')
end, {})

-- formatting expr
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "typescript", "json" },
  callback = function()
    vim.bo.formatexpr = "v:lua.vim.fn.CocAction('formatSelected')"
  end
})

vim.api.nvim_create_autocmd("User", {
  pattern = "CocJumpPlaceholder",
  callback = function()
    vim.fn.CocActionAsync('showSignatureHelp')
  end
})

-- statusline
vim.o.statusline = vim.o.statusline .. '%{coc#status()}%{get(b:,"coc_current_function","")}'

-- Highlight groups
-- vim.api.nvim_set_hl(0, 'CocInlayHint', { italic = true, fg = '#d5d8da', bg = '#e7ebec' }) -- use in case of colorscheme morning
-- vim.api.nvim_set_hl(0, 'CocInlayParameterHint', { italic = true, fg = '#ff8800' })
-- vim.api.nvim_set_hl(0, 'CocInlayTypeHint', { italic = true, fg = '#ff8800' })
-- vim.api.nvim_set_hl(0, 'CocHintFloat', { italic = true, fg = '#ff8800' })
-- vim.api.nvim_set_hl(0, 'CocHintSign', { italic = true, fg = '#ff8800' })


-- === coc-settings.json ===
-- "java.trace.server": "verbose",
-- "java.eclipse.downloadSources": false,
-- "java.autobuild.enabled": false,
-- "java.sharedIndexes.enabled": "on",
-- "java.import.gradle.wrapper.enabled": true,
-- "java.import.gradle.user.home": "/Users/priyanshu.shrivastav/.gradle",
-- "java.import.gradle.home": "/Users/priyanshu.shrivastav/.gradle/wrapper/dists/gradle-8.6-bin/afr5mpiioh2wthjmwnkmdsd5w/gradle-8.6/bin",
-- "java.import.gradle.java.home": "/Users/priyanshu.shrivastav/Library/Java/JavaVirtualMachines/corretto-21.0.5/Contents/Home",
-- "java.import.gradle.offline.enabled": true,
-- "java.import.gradle.arguments": "--offline",
-- "java.configuration.updateBuildConfiguration": "disabled",
-- "java.jdt.ls.java.home": "/Users/priyanshu.shrivastav/Library/Java/JavaVirtualMachines/corretto-21.0.5/Contents/Home",
-- "java.configuration.runtimes": [
--   {
--     "name": "JavaSE-21",
--     "path": "/Users/priyanshu.shrivastav/Library/Java/JavaVirtualMachines/corretto-21.0.5/Contents/Home",
--     "default": true
--   }
-- ]

