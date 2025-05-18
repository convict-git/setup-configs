-- ***************************************************************************
-- Settings

vim.opt.backspace = { "indent", "eol", "start" } -- Backspace behavior (2 means: indent, eol, start)
vim.opt.number = true -- Line Numbers
vim.opt.updatetime = 100 -- Faster CursorHold (useful for plugins)
vim.opt.history = 500 -- Command history length
vim.opt.autoindent = true -- Auto indentation
vim.opt.smartindent = true
vim.opt.splitbelow = true -- Split window behavior
vim.opt.splitright = true -- Split window behavior
vim.opt.swapfile = false -- No swap file
-- Tabs and indentation
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smarttab = true
vim.opt.autowrite = true -- Auto-write modified buffers
vim.opt.wrap = true -- Text wrapping
vim.opt.fileformat = "unix" -- File format
vim.opt.autoread = true -- Auto read file if changed outside
vim.opt.wildmenu = true -- Wildmenu for command-line completion
vim.opt.showcmd = true -- Show command in bottom right
vim.opt.ignorecase = true -- Case-insensitive search, unless uppercase is used
vim.opt.smartcase = true
vim.opt.incsearch = true
vim.opt.hlsearch = false -- Don't highlight after search
vim.opt.encoding = "utf-8" -- Encoding
vim.opt.matchpairs = { "(:)", "{:}", "[:]", "<:>", "':'", "\":\"" } -- Matching pairs
vim.opt.errorbells = false -- Disable error bells
vim.opt.belloff = "all"
vim.opt.foldmethod = "syntax" -- Syntax-based folding
vim.opt.mouse = "a" -- Enable mouse
vim.opt.mousemoveevent = true
vim.opt.previewheight = 25 -- Preview window height
vim.opt.background = "light"
vim.cmd("syntax enable")

-- Statusline
vim.opt.statusline = "%<%f%h%m%r%=char=%b=0x%B\\ \\ %l,%c%V\\ %P"
-- vim.opt.completeopt:remove("preview") -- Completion options
vim.opt.completeopt:append("popup")  -- enable if using popup menu
vim.opt.compatible = false -- Not compatible with old vi
vim.cmd("filetype off") -- Required for plugins (used to be needed with vim-plug or pathogen)
vim.cmd("filetype plugin indent on")
vim.cmd("syntax on") -- Enable syntax highlighting (again, for good measure)

-- ***************************************************************************
-- Lazy.nvim bootstrap
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ***************************************************************************
-- Plugins

require("lazy").setup({
  { 'tpope/vim-fugitive' },
  -- { 'rust-lang/rust.vim' }, // ToDo
  { 'rhysd/vim-clang-format' },
  { 'octol/vim-cpp-enhanced-highlight' },
  { 'vim-airline/vim-airline' },
  { 'vim-airline/vim-airline-themes' },
  { 'ap/vim-css-color'},
  { 'jiangmiao/auto-pairs', lazy = false },
  { 'preservim/tagbar' },
--{ 'vifm/vifm.vim' }, -- Replaced with Yazi

-- colorschemes
--{ 'sainnhe/gruvbox-material' },
--{ 'sainnhe/everforest' },
--{
--  "oxfist/night-owl.nvim",
--  lazy = false, -- make sure we load this during startup if it is your main colorscheme
--  priority = 1000, -- make sure to load this before all the other start plugins
--  config = function()
--    -- load the colorscheme here
--    require("night-owl").setup()
--    vim.cmd.colorscheme("night-owl")
--  end,
--},
 {
   'projekt0n/github-nvim-theme',
   name = 'github-theme',
   lazy = false, -- make sure we load this during startup if it is your main colorscheme
   priority = 1000, -- make sure to load this before all the other start plugins
   config = function()
     require('github-theme').setup({})
     vim.cmd('colorscheme github_light')
   end,
 },

-- === CoC ===
  {
    "neoclide/coc.nvim",
    branch = "release",
    build = "npm ci",
  },

  -- === Telescope and Extensions ===
  { "nvim-lua/plenary.nvim" },
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = { "nvim-lua/plenary.nvim" },
  },
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release",
  },
  { "nvim-telescope/telescope-frecency.nvim" },
  { "nvim-telescope/telescope-file-browser.nvim" },

  -- === fzf.vim ===
  { "junegunn/fzf" },
  {
    "junegunn/fzf.vim",
    dependencies = { "junegunn/fzf" },
    config = function()
      require('plugins/fzf-nvim')
    end,
  },

  -- === neogit ===
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",         -- required
      "sindrets/diffview.nvim",        -- optional - Diff integration

      -- Only one of these is needed.
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      vim.keymap.set("n", "<leader>gs", ":DiffViewOpen<CR>", { silent = true })
    end,
  },

  -- === Yazi (file-manager) ===
  {
    "mikavilpas/yazi.nvim",
    event = "VeryLazy",
    dependencies = {
      -- check the installation instructions at
      -- https://github.com/folke/snacks.nvim
      "folke/snacks.nvim"
    },
    keys = {
      -- 👇 in this section, choose your own keymappings!
      {
        "<C-g>",
        mode = { "n", "v" },
        "<cmd>Yazi<cr>",
        desc = "Open yazi at the current file",
      },
    },
    ---@type YaziConfig | {}
    opts = {
      -- if you want to open yazi instead of netrw
      open_for_directories = true,
      keymaps = {
        show_help = "<f1>",
      },
    },
    -- 👇 if you use `open_for_directories=true`, this is recommended
    init = function()
      vim.g.loaded_netrwPlugin = 1
    end,
  },

  -- === Treesitter ===
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
  },

  -- === Dropbar ===
  { "Bekaboo/dropbar.nvim",
     dependencies = {
       'nvim-telescope/telescope-fzf-native.nvim',
      },
     config = function ()
       local dropbar_api = require('dropbar.api')
       vim.keymap.set('n', '<Leader>;', dropbar_api.pick, { desc = 'Pick symbols in winbar' })
       vim.keymap.set('n', '[;', dropbar_api.goto_context_start, { desc = 'Go to start of current context' })
       vim.keymap.set('n', '];', dropbar_api.select_next_context, { desc = 'Select next context' })
     end
  },

  -- === DAP ===
  { "mfussenegger/nvim-dap" },
  { "nvim-neotest/nvim-nio" },
  { "rcarriga/nvim-dap-ui" },
  { "theHamsta/nvim-dap-virtual-text" },

  -- === UFO Folding ===
  { "kevinhwang91/promise-async" },
  { "kevinhwang91/nvim-ufo" },

  { "karb94/neoscroll.nvim" }, -- === Smooth Scrolling ===
})

-- ***************************************************************************
-- Coc settings
vim.g.coc_global_extensions = {
  'coc-clangd', 'coc-cmake', 'coc-docker', 'coc-emmet', 'coc-eslint', 'coc-graphql',
  'coc-json', 'coc-git', 'coc-java', 'coc-prettier', 'coc-rust-analyzer',
  'coc-sh', 'coc-tsserver', 'coc-yaml'
}

vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.signcolumn = 'yes'

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
vim.keymap.set("n", "gd", "<Plug>(coc-definition)", { silent = true })
vim.keymap.set("n", "gD", ":call CocActionAsync('jumpDefinition')<CR>:wincmd v<CR>", { silent = true })
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
vim.keymap.set("n", "<space>a", ":<C-u>CocList diagnostics<CR>", { silent = true })
vim.keymap.set("n", "<space>e", ":<C-u>CocList extensions<CR>", { silent = true })
vim.keymap.set("n", "<space>c", ":<C-u>CocList commands<CR>", { silent = true })
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

-- ***************************************************************************
-- Telescope settings
require('plugins/telescope-config')

-- ***************************************************************************
-- Treesitter
require('plugins/treesitter')

-- ***************************************************************************
-- Airline
vim.g.airline_powerline_fonts = 1
vim.g.airline_theme = 'github_light'

vim.g['airline#extensions#tabline#enabled'] = 1
vim.g['airline#extensions#tabline#left_sep'] = ' '
vim.g['airline#extensions#tabline#left_alt_sep'] = '|'

-- Customize section_z to include clock
vim.api.nvim_create_autocmd("User", {
  pattern = "AirlineAfterInit",
  callback = function()
    vim.g.airline_section_z = vim.fn['airline#section#create']({
      'clock',
      vim.g.airline_symbols and vim.g.airline_symbols.space or ' ',
      vim.g.airline_section_z
    })
  end
})

-- ***************************************************************************
-- Others

vim.keymap.set("n", "<leader>ad", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("+", path)
  print(path)
end, { desc = "Copy absolute file path to clipboard" })

local function kill_all_buffers()
  local file = vim.fn.expand("%:p")
  vim.cmd("bufdo bd")
  vim.cmd("edit " .. file)
end

vim.keymap.set("n", "<leader>bd", kill_all_buffers, { desc = "Kill all buffers and reload current file" })

-- Restore cursor to last position on buffer read
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    vim.schedule(function()
      local mark = vim.api.nvim_buf_get_mark(0, '"')
      local lcount = vim.api.nvim_buf_line_count(0)
      local line = mark[1]
      local col = mark[2]

      if line > 0 and line <= lcount then
        pcall(function()
          local line_length = #vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]
          if col > line_length then
            col = line_length
          end
          vim.api.nvim_win_set_cursor(0, {line, col})
        end)
      end
    end)
  end,
})

-- Remove trailing whitespace on save
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    vim.cmd([[%s/\s\+$//e]])
  end,
})

-- Vifm
-- vim.keymap.set("n", "<C-g>", ":Vifm<CR>", { noremap = true, silent = true })
-- vim.g.vifm_replace_netrw_cmd = 1
-- vim.g.vifm_keep_cwd = 1

-- This shit was causing lot of bugs. *NOTE* <C-x> decrements a number, so map it to just save the file
vim.keymap.set("n", "<C-x>", ":w<CR>", { noremap = true, silent = true })

-- Faster vertical navigation
vim.keymap.set("n", "{", "8k", { noremap = true, silent = true })
vim.keymap.set("n", "}", "8j", { noremap = true, silent = true })
vim.keymap.set("n", "<C-e>", "8<C-e>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-y>", "8<C-y>", { noremap = true, silent = true })

-- Tab workflow
vim.keymap.set("n", "<C-j>", ":tabNext<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-k>", ":tabnext<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-t>", ":tabnew<CR>", { noremap = true, silent = true })

-- Treesitter folding
vim.opt.foldmethod = 'expr'
vim.opt.foldexpr = 'nvim_treesitter#foldexpr()'
vim.opt.foldlevel = 99

-- nvim-ufo -- Source external Vimscript config (for backward compatibility)
require('plugins/nvim-ufo')

-- Visual mode: yank to system clipboard
vim.keymap.set("x", "<leader>y", '"+y', { silent = true })


-- Open init.lua in a new tab
vim.keymap.set("n", "<leader>rc", ":tabnew ~/.config/nvim/init.lua<CR>", { silent = true })

-- ***************************************************************************
-- Highlights

vim.api.nvim_set_hl(0, '@operator', { bold = true })
vim.api.nvim_set_hl(0, '@punctuation', { bold = true })
vim.api.nvim_set_hl(0, '@punctuation.bracket', { bold = true })
vim.api.nvim_set_hl(0, '@keyword', { bold = true })
vim.api.nvim_set_hl(0, '@type', { italic = true })
vim.api.nvim_set_hl(0, 'Number', { bold = true, bg = '#e9f7ef' })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineError', { bold = true, bg = '#fdedec' })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineWarn', { bold = true, bg = '#fef9e7' })


