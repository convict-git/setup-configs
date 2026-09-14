vim.opt.rtp:append("~/.local/share/nvim") -- Must be always kept at the top to avoid any unnecessary bugs of referring before importing

-- ***************************************************************************
-- Settings

vim.opt.guifont = "Deimos:h18:b"
vim.opt.linespace = 10
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
-- foldmethod is managed by nvim-ufo (avoid slow syntax/expr folding on big files)
vim.opt.mouse = "a" -- Enable mouse
vim.opt.mousemoveevent = true
vim.opt.previewheight = 25 -- Preview window height
vim.opt.background = "light"
vim.cmd("syntax enable")
vim.cmd("match Todo /todo convict[^*/]*/") -- todo convict matches as Todo


-- Statusline is managed by lualine (see lua/plugins/lualine-config.lua).
-- vim.opt.completeopt:remove("preview") -- Completion options
vim.opt.completeopt:append("popup")  -- enable if using popup menu
vim.opt.compatible = false -- Not compatible with old vi
vim.cmd("filetype off") -- Required for plugins (used to be needed with vim-plug or pathogen)
vim.cmd("filetype plugin indent on")
vim.cmd("syntax on") -- Enable syntax highlighting (again, for good measure)

-- ***************************************************************************
-- Big-file performance guard: disables heavy features (treesitter, CoC, syntax,
-- folding) for buffers >= 512 KB or >= 2500 lines. Registered early so its
-- autocmds fire before any plugin attaches to a buffer.
require('plugins/bigfile')

-- ***************************************************************************
local cwd = vim.fn.getcwd()
local is_java_project = vim.fn.getcwd():match("sprinklr.app/?$") ~= nil

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
  -- Removed 'octol/vim-cpp-enhanced-highlight': redundant regex C/C++ highlighting,
  -- superseded by the treesitter `cpp` parser (and slow on large C/C++ files).
  {
    'nvim-lualine/lualine.nvim',
    lazy = false,
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('plugins/lualine-config')
    end,
  },
  {
    'akinsho/bufferline.nvim',
    version = "*",
    lazy = false,
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('plugins/bufferline-config')
    end,
  },
  -- Removed 'ap/vim-css-color': duplicate of 'brenoprata10/nvim-highlight-colors'
  -- below (two plugins highlighting the same color codes).
  { 'jiangmiao/auto-pairs', lazy = false },
  { 'preservim/tagbar', cmd = { "TagbarToggle", "TagbarOpen", "Tagbar" } },
  { 'NLKNguyen/papercolor-theme' },
  -- {
  --   'duarteocarmo/cursor-themes.nvim',
  --   lazy = false,
  --   priority = 1000,
  -- },
  { 'voldikss/vim-floaterm',
    cmd = { "FloatermNew", "FloatermToggle" },
    keys = { "<S-t>", "<leader>tr" },
    config = function()
      vim.keymap.set("n", "<S-t>", ":FloatermToggle!<CR>", { silent = true })
      vim.keymap.set("n", "<leader>tr", ":FloatermNew --height=0.15 --width=0.3 --autoclose=2 --position=topright<CR>", { silent = true })
      vim.g.floaterm_position = 'topright'
      vim.g.floaterm_width = 0.4
      vim.g.floaterm_height = 0.4
    end
  },
--{ 'vifm/vifm.vim' }, -- Replaced with Yazi

-- colorschemes
 { 'nordtheme/vim' },
 {'sainnhe/gruvbox-material' },
 { 'sainnhe/everforest' },
 {
   "EdenEast/nightfox.nvim",
   lazy = false,
   priority = 1000, -- load (and apply the colorscheme) before lualine/bufferline read colors
   config = function()
     vim.cmd.colorscheme("duskfox")
   end,
 },
 {
   "oxfist/night-owl.nvim",
   lazy = false, -- make sure we load this during startup if it is your main colorscheme
   priority = 1000, -- make sure to load this before all the other start plugins
   config = function()
     -- load the colorscheme here
     -- require("night-owl").setup()
     -- vim.cmd.colorscheme("night-owl")
   end,
 },
 { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
 -- Tokyo night
 {
  "folke/tokyonight.nvim",
  lazy = false,
  priority = 1000,
  opts = {},
  config = function()
    require('tokyonight').setup({})
  end,
  },
 {
   'projekt0n/github-nvim-theme',
   name = 'github-theme',
   lazy = false, -- make sure we load this during startup if it is your main colorscheme
   priority = 1000, -- make sure to load this before all the other start plugins
   config = function()
     require('github-theme').setup({})
     -- vim.cmd('colorscheme github_light')
   end,
 },
 -- === highlighting colors in neovim ===
 { 'brenoprata10/nvim-highlight-colors',
   event = "BufReadPost",
   config = function()
     vim.opt.termguicolors = true
     require('nvim-highlight-colors').setup({})
   end
 },


 -- === Test coverage ===
 {
    "andythigpen/nvim-coverage",
    version = "*",
    cmd = { "Coverage", "CoverageLoad", "CoverageShow", "CoverageHide", "CoverageToggle", "CoverageClear", "CoverageSummary" },
    config = function()
      require("coverage").setup({
        auto_reload = true,
      })
    end,
  },

 -- === Flash (better motion) ===
 {
    "folke/flash.nvim",
    event = "VeryLazy",
    ---@type Flash.Config
    opts = {
      labels = "sfghjklqwetyzvbnm",
      modes = {
        -- options used when flash is activated through
        -- a regular search with `/` or `?`
        search = {
          -- when `true`, flash will be activated during regular search by default.
          -- You can always toggle when searching with `require("flash").toggle()`
          enabled = true,
          highlight = { backdrop = false },
          jump = { history = false, register = false, nohlsearch = true },
        },
        char = {
          keys = { "f", "F" },
        },
      }
    },
    -- stylua: ignore
    keys = {
      { "s", mode = { "n" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    },
  },

 -- -- === Typescript === -- Just Doesn't work!! Worst ever
 -- {
 --  "pmizio/typescript-tools.nvim",
 --  dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
 --  opts = {
 --    settings = {
 --      tsserver_log_level = 'verbose',
 --      tsserver_max_memory = 24000,
 --      separate_diagnostic_server = true
 --    }
 --  },
 -- },

 -- Trying out
 -- {
 --    "Mr-LLLLL/cool-chunk.nvim",
 --    event = { "CursorHold", "CursorHoldI" },
 --    dependencies = {
 --        "nvim-treesitter/nvim-treesitter",
 --    },
 --    config = function()
 --        require("cool-chunk").setup({})
 --    end
 --  },
 --
  -- == Render markdown ==
  {
    'MeanderingProgrammer/render-markdown.nvim',
     dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
      -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' }, -- if you use standalone mini plugins
      -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
      ---@module 'render-markdown'
      ---@type render.md.UserConfig
     ft = { "markdown" },
     opts = {},
  },
  -- == Floating todo ==
  {
    'vimichael/floatingtodo.nvim',
    cmd = "Td",
    keys = { "<leader>1" },
    config = function()
      require('floatingtodo').setup({
        target_file = "~/notes/todo.md",
        border = "single", -- single, rounded, etc.
        width = 0.9, -- width of window in % of screen size
        height = 0.6, -- height of window in % of screen size
        position = "center", -- topleft, topright, bottomleft, bottomright
      })
      vim.keymap.set("n", "<leader>1", ":Td<CR>", { silent = true })
    end,
  },
  -- == Search and replace for bigger projects ==
  {
    'MagicDuck/grug-far.nvim',
    cmd = "GrugFar",
    config = function()
      require('grug-far').setup({
      });
    end
  },

  -- === Tree view ===
  {
    'nvim-tree/nvim-tree.lua',
    init = function()
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
      -- optionally enable 24-bit colour
      vim.opt.termguicolors = true
    end,
    cond = false, -- disable for now
    config = function()
      require("nvim-tree").setup({
        sort = {
          sorter = "case_sensitive",
        },
        view = {
          width = 30,
        },
        renderer = {
          group_empty = true,
        },
        filters = {
          dotfiles = true,
        },
      })
    end,
  },
  -- === CoC ===
  {
    "neoclide/coc.nvim",
    branch = "release",
    -- build = "npm ci",
    cond = function()
      return not is_java_project -- Don't load coc for java projects, we will use some other plugins
    end,
    config = function()
      require('plugins/coc-config')
    end,
  },

  -- === Avante ===
  require('plugins/avante-config').get_avante_lazy_config(false),

  -- === Telescope and Extensions ===
  { "nvim-lua/plenary.nvim" },
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "isak102/telescope-git-file-history.nvim",
        dependencies = {
          "nvim-lua/plenary.nvim",
          "tpope/vim-fugitive"
        }
      }
    }
  },
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release",
  },
  { "nvim-telescope/telescope-frecency.nvim" },
  { "nvim-telescope/telescope-file-browser.nvim" },
  {
    "fannheyward/telescope-coc.nvim",
    dependencies = {
      "neoclide/coc.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("telescope").setup({
        extensions = {
          coc = {
              theme = 'ivy',
              prefer_locations = true, -- always use Telescope locations to preview definitions/declarations/implementations etc
              push_cursor_on_edit = true, -- save the cursor position to jump back in the future
              timeout = 3000, -- timeout for coc commands
          }
        },
      })
      require('telescope').load_extension('coc')
    end
  },
  -- === fzf.vim ===
  { "junegunn/fzf" },
  {
    "junegunn/fzf.vim",
    dependencies = { "junegunn/fzf" },
    config = function()
      require('plugins/fzf-nvim')
      -- FuzzyGitRange / FuzzyGitSince: fuzzy content search scoped to files in
      -- given commit ranges + tracked/staged files. Depends on fzf.vim.
      require('plugins/fuzzy-git-range')
    end,
  },

  -- === neogit ===
  {
    "NeogitOrg/neogit",
    cmd = { "Neogit", "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewFileHistory" },
    keys = { "<leader>gs", "<leader>sg" },
    dependencies = {
      'nvim-tree/nvim-web-devicons',
      "nvim-lua/plenary.nvim",         -- required
      "sindrets/diffview.nvim",        -- optional - Diff integration

      -- Only one of these is needed.
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      vim.keymap.set("n", "<leader>gs", ":DiffviewOpen<CR>", { silent = true })
      vim.keymap.set("n", "<leader>sg", ":DiffviewClose<CR>", { silent = true })
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
    -- 👇 if you use `open_for_directories=true`, this is recommended
    init = function()
      vim.g.loaded_netrwPlugin = 1
    end,
    config = function()
      local yazi = require('yazi')
      yazi.setup({
        -- if you want to open yazi instead of netrw
        open_for_directories = true,
        floating_window_scaling_factor = { height =  0.5, width = 0.8 },
        keymaps = {
          show_help = "<f1>",
        },
         set_keymappings_function = function(yazi_buffer, config, context)
            -- Adding custom mapping: <leader>ro => Open all files recursively from hovered directory
            vim.keymap.set({ "t" }, "<leader>ro", function()
              local hovered_url = context.ya_process.hovered_url
              local cwd = vim.fn.getcwd()
              local rel_path = vim.fn.fnamemodify(hovered_url, ":." )  -- relative to cwd

              vim.cmd("close") -- Yazi creates an autocmd for WinLeave where it clears the window

              vim.defer_fn(function()
                  vim.cmd("OpenAllFilesRecursive " .. rel_path)
              end, 10)
            end, { buffer = yazi_buffer, desc = "Recursively open files from hovered dir" })

            -- New mapping for quickfix
            vim.keymap.set({ "t" }, "<leader>rq", function()
              local hovered_url = context.ya_process.hovered_url
              local rel_path = vim.fn.fnamemodify(hovered_url, ":.")
              vim.cmd("close")
              vim.defer_fn(function()
                vim.cmd("QuickfixAllFilesRecursive " .. rel_path)
              end, 10)
            end, { buffer = yazi_buffer, desc = "Recursively add files from hovered dir to quickfix" })
          end,
      })
    end,
  },

  -- -- === nvim-java === wait for some time
  -- {
  --   "nvim-java/nvim-java",
  --   dependencies = {
  --     "neovim/nvim-lspconfig",
  --   }
  -- },

  -- === Treesitter ===
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
  },

  -- === Mason ===
  require('plugins/lsp-java-config').get(not is_java_project),

  -- === Dropbar ===
  { "Bekaboo/dropbar.nvim",
     event = "BufReadPost",
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

  -- === Outline (symbols sidebar) ===
  { "hedyhli/outline.nvim",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require('plugins/outline-config')
    end,
  },

  -- === DAP ===
  -- The whole DAP stack loads lazily on the first breakpoint keymap. nvim-dap,
  -- nvim-nio and nvim-dap-virtual-text are pulled in as dependencies of dap-ui.
  { "mfussenegger/nvim-dap",
    lazy = true,
    config = function()
      require('plugins/dap')
    end
  },
  { "nvim-neotest/nvim-nio", lazy = true },
  { "rcarriga/nvim-dap-ui",
    keys = {
      { "<Leader>br", desc = "Toggle Breakpoint" },
      { "<Leader>db", desc = "Close Dap UI" },
    },
    dependencies = {
     "mfussenegger/nvim-dap",
     "nvim-neotest/nvim-nio",
     "theHamsta/nvim-dap-virtual-text",
    },
    config = function()
      require('dapui').setup({})
      local dap, dapui = require("dap"), require("dapui")
      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end

      vim.keymap.set('n', '<Leader>br', ':DapToggleBreakpoint<CR>', { desc = 'Toggle Breakpoint', silent = true })
      vim.keymap.set('n', '<Leader>db', function()
        vim.cmd('DapTerminate')
        dapui.close()
      end, { desc = 'Close Dap UI', silent = true })
      --  dap.listeners.before.event_terminated.dapui_config = function()
      --    dapui.close()
      --  end
      --  dap.listeners.before.event_exited.dapui_config = function()
      --    dapui.close()
      --  end
    end,
  },
  { "theHamsta/nvim-dap-virtual-text",
    lazy = true,
    config = function()
      require("nvim-dap-virtual-text").setup()
    end,
  },

  -- === UFO Folding ===
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = "BufReadPost",
    config = function()
      require('plugins/nvim-ufo')
    end,
  },


  -- === Sprinklr Supercharged (scanProject / references / traceImports) ===
  require("plugins/spr-supercharged"),

  -- === text-case ===
  {
    "johmsalas/text-case.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
      require("textcase").setup({})
      require("telescope").load_extension("textcase")
    end,
    keys = {
      "cs", -- Default invocation prefix
      { "cs.", "<cmd>TextCaseOpenTelescope<CR>", mode = { "n", "x" }, desc = "Telescope" },
    },
    cmd = {
      -- NOTE: The Subs command name can be customized via the option "substitude_command_name"
      "Subs",
      "TextCaseOpenTelescope",
      "TextCaseOpenTelescopeQuickChange",
      "TextCaseOpenTelescopeLSPChange",
      "TextCaseStartReplacingCommand",
    },
    -- If you want to use the interactive feature of the `Subs` command right away, text-case.nvim
    -- has to be loaded on startup. Otherwise, the interactive feature of the `Subs` will only be
    -- available after the first executing of it or after a keymap of text-case.nvim has been used.
    lazy = true,
  }
})

-- ***************************************************************************
-- Telescope settings
require('plugins/telescope-config')

-- ***************************************************************************
-- Treesitter
require('plugins/treesitter')

-- ***************************************************************************
-- Others
--
-- Send all files recursively to quickfix list
vim.api.nvim_create_user_command("QuickfixAllFilesRecursive", function(opts)
  local dir = opts.args ~= "" and opts.args or vim.fn.getcwd()
  local handle = io.popen("fd -t f . " .. vim.fn.shellescape(dir))
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result ~= "" then
      local qf_list = {}
      for file in result:gmatch("[^\r\n]+") do
        table.insert(qf_list, { filename = file, lnum = 1, col = 1, text = "" })
      end
      vim.fn.setqflist(qf_list, "r") -- replace quickfix list
      vim.cmd("copen")
    end
  end
end, {
  nargs = "?", -- optional argument
  complete = "dir" -- tab-completion for directories
})

-- Open all files recursive
vim.api.nvim_create_user_command("OpenAllFilesRecursive", function(opts)
  local dir = opts.args ~= "" and opts.args or vim.fn.getcwd()
  local handle = io.popen("fd -t f . " .. vim.fn.shellescape(dir))
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result ~= "" then
      local files = {}
      for file in result:gmatch("[^\r\n]+") do
        table.insert(files, file)
      end
      vim.cmd("args " .. table.concat(files, " "))
      vim.cmd("argdo edit")
    end
  end
end, {
  nargs = "?", -- optional argument
  complete = "dir" -- tab-completion for directories
})

-- Normal mode: vertical split
vim.keymap.set("n", "<leader>v", ":vsplit<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>d", function()
  vim.cmd('b#') -- switch to alternate buffer
  vim.cmd('bd#') -- delete the previous buffer
end, { desc = 'Close the current buffer and switch to previous' })

local is_gui = vim.fn.has("gui_running") == 1
    or vim.g.neovide
    or vim.g.goneovim
    or vim.g.nvy
    or vim.g.vscode

if is_gui then
  vim.g.neovide_position_animation_length = 0
  vim.g.neovide_cursor_animation_length = 0.00
  vim.g.neovide_cursor_trail_size = 0
  vim.g.neovide_cursor_animate_in_insert_mode = false
  vim.g.neovide_cursor_animate_command_line = false
  vim.g.neovide_scroll_animation_far_lines = 0
  vim.g.neovide_scroll_animation_length = 0.00
  -- Clipboard
  vim.opt.clipboard:append { "unnamedplus" }
  vim.keymap.set("v", "<D-c>", '"+y', { noremap = true, silent = true })
  vim.keymap.set("n", "<D-v>", '"+p', { noremap = true, silent = true })
  vim.keymap.set("i", "<D-v>", '<C-r>+', { noremap = true, silent = true })
-- else
--   vim.cmd("set background=dark")
--   -- vim.g.airline_theme = 'tomorrow'
--   -- vim.cmd("colorscheme gruvbox-material")
--   -- vim.g.airline_theme = 'gruvbox_material'
--   -- vim.cmd('colorscheme catppuccin')
--   -- vim.cmd('colorscheme miniwinter')
--   --vim.cmd('colorscheme nord')
--   vim.cmd('colorscheme everforest')
--   if vim.g.colors_name == "miniwinter" then
--     vim.api.nvim_set_hl(0, 'DiffAdd',    { bg = '#c1e1c1' })
--     vim.api.nvim_set_hl(0, 'DiffChange', { bg = '#a5d8ff' })
--     vim.api.nvim_set_hl(0, 'DiffDelete', { bg = '#ffb3b3' })
--     vim.api.nvim_set_hl(0, 'DiffText',   { bg = '#ffeaa7' })
--   end
end

-- Colorscheme is applied from the nightfox.nvim plugin spec above (priority
-- 1000, lazy = false) so it's active before lualine/bufferline configure
-- themselves against it -- applying it here (after lazy.setup()) left
-- bufferline reading the wrong colors until a manual :colorscheme rerun.

vim.api.nvim_create_user_command("W", function()
  if vim.bo.modified then
    vim.cmd("write")
  end
end, {})

vim.keymap.set("n", "<leader>ad", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("+", path)
  print(path)
end, { desc = "Copy absolute file path to clipboard" })

vim.keymap.set("n", "<leader>rd", function()
  local abs_path = vim.fn.expand("%:p")
  local cwd = vim.fn.getcwd()
  local rel_path = vim.fn.fnamemodify(abs_path, ":." )
  vim.fn.setreg("+", rel_path)
  print(rel_path)
end, { desc = "Copy file path relative to CWD to clipboard" })

vim.keymap.set("n", "<F5>", function()
  local schemes = vim.fn.getcompletion("", "color")
  local next = schemes[math.random(#schemes)]
  pcall(vim.cmd.colorscheme, next)
  print("Colorscheme: " .. next)
end, { desc = "Random Colorscheme" })

local function kill_all_buffers()
  vim.cmd("bufdo bd")
end

vim.keymap.set("n", "<leader>bd", kill_all_buffers, { desc = "Kill all buffers" })

-- Restore cursor to last position on buffer read.
--
-- Must run synchronously (not via vim.schedule/defer_fn): coc.nvim, Telescope,
-- and fzf all open the target buffer and then immediately set the cursor to
-- the jump destination in the same tick. Deferring this callback let it run
-- *after* that jump, so it clobbered the correct position with the stale '"
-- mark -- landing on the wrong line the first time a buffer was read (it
-- "worked" on a subsequent jump only because some plugins reuse an
-- already-loaded buffer via :buffer, which doesn't re-fire BufReadPost).
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
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
  end,
})

-- Remove trailing whitespace on save (skipped for big files; preserves cursor
-- position and search history via keeppatterns + winsaveview/winrestview)
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    if vim.b.is_big_file then
      return
    end
    local view = vim.fn.winsaveview()
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- Vifm
-- vim.keymap.set("n", "<C-g>", ":Vifm<CR>", { noremap = true, silent = true })
-- vim.g.vifm_replace_netrw_cmd = 1
-- vim.g.vifm_keep_cwd = 1

-- This shit was causing lot of bugs. *NOTE* <C-x> decrements a number, so map it to just save the file
vim.keymap.set("n", "<C-x>", ":w<CR>", { noremap = true, silent = true })

-- Faster vertical navigation
vim.keymap.set({ "n", "v" }, "{", "8k", { noremap = true, silent = true })
vim.keymap.set({ "n", "v" }, "}", "8j", { noremap = true, silent = true })
vim.keymap.set("n", "<C-e>", "8<C-e>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-y>", "8<C-y>", { noremap = true, silent = true })

-- Tab/Buffers workflow
-- vim.keymap.set("n", "<C-j>", ":tabNext<CR>", { noremap = true, silent = true })
-- vim.keymap.set("n", "<C-k>", ":tabnext<CR>", { noremap = true, silent = true })
-- vim.keymap.set("n", "<C-t>", ":tabnew<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-j>", ":bprev<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-k>", ":bnext<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-t>", ":enew<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "[", ":cnext<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "]", ":cprev<CR>", { noremap = true, silent = true })

-- Folding is fully managed by nvim-ufo (see lua/plugins/nvim-ufo.lua).
-- The old `foldexpr = nvim_treesitter#foldexpr()` was a major slowdown on large
-- files, so it has been removed in favor of UFO's lazy, on-demand fold provider.

-- nvim-ufo is now loaded lazily via its plugin spec (event = "BufReadPost").
require('plugins/remote_file_server')

-- ingest log server: POST/GET http://127.0.0.1:<port>/ingest/<channel> -> log file
-- Useful for debugging Node apps & React components via fetch(). Not started
-- automatically -- run :IngestStart when you want to capture logs. See :IngestOpen
require('plugins/ingest_server').setup({ port = 9099 })

-- Visual mode: yank to system clipboard
vim.keymap.set("x", "<leader>y", '"+y', { silent = true })


-- Open init.lua in a new tab
vim.keymap.set("n", "<leader>rc", ":tabnew ~/.config/nvim/init.lua<CR>", { silent = true })

-- ***************************************************************************
-- Highlights
-- Applied via a ColorScheme autocmd so they survive theme switches (markdown
-- <-> code) instead of being wiped by the next :colorscheme. Also applied once
-- immediately for the current theme.

local function set_custom_highlights()
  -- color settings for diff
  -- vim.api.nvim_set_hl(0, 'DiffAdd',    { bg = '#c1e1c1' })
  -- vim.api.nvim_set_hl(0, 'DiffChange', { bg = '#a5d8ff' })
  -- vim.api.nvim_set_hl(0, 'DiffDelete', { bg = '#ffb3b3' })
  -- vim.api.nvim_set_hl(0, 'DiffText',   { bg = '#ffeaa7' })

  vim.api.nvim_set_hl(0, '@operator', { bold = true })
  vim.api.nvim_set_hl(0, '@punctuation', { bold = true })
  vim.api.nvim_set_hl(0, '@punctuation.bracket', { bold = true })
  vim.api.nvim_set_hl(0, '@keyword', { bold = true })
  vim.api.nvim_set_hl(0, '@type', { italic = true, bold = true })
  vim.api.nvim_set_hl(0, 'Number', { bold = true })

  -- typescript
  vim.api.nvim_set_hl(0, '@function.call.tsx', { bold = true })

  -- Diagnostics: straight underline instead of the colorscheme's default
  -- squiggly undercurl, keeping whatever color the theme assigned.
  for _, severity in ipairs({ 'Error', 'Warn', 'Info', 'Hint' }) do
    local group = 'DiagnosticUnderline' .. severity
    local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
    hl.undercurl = false
    hl.underline = true
    if hl.cterm then
      hl.cterm.undercurl = false
      hl.cterm.underline = true
    end
    vim.api.nvim_set_hl(0, group, hl)
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = set_custom_highlights,
})
set_custom_highlights()

-- require("plugins/tsconfig-alias-path") ToDo yet to debug it; Not working yet
