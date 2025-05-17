local telescope = require('telescope')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local function open_all_in_tabs(prompt_bufnr)
  local picker = action_state.get_current_picker(prompt_bufnr)
  local entries = picker:get_multi_selection()

  if vim.tbl_isempty(entries) then
    print("No entries selected!")
    return
  end

  actions.close(prompt_bufnr)

  for _, entry in ipairs(entries) do
    vim.cmd(string.format("tabnew %s", entry.filename))
    vim.cmd(string.format("%d", entry.lnum))
  end
end

telescope.setup{
  defaults = {
    path_display = { "truncate", "absolute" },
    vimgrep_timeout = 10000,
    mappings = {
      n = {
        ["t"] = function(prompt_bufnr)
          open_all_in_tabs(prompt_bufnr)
        end,
        ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
        ["<C-a>"] = actions.toggle_all,
      },
      i = {
        ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
        ["<C-a>"] = actions.toggle_all,
      },
    },
  },
  -- Uncomment and customize pickers here if needed
  -- pickers = {
  --   git_commits = {
  --     mappings = {
  --       i = {
  --         ["<C-f>"] = cf_actions.find_changed_files,
  --         ["<CR>"] = function(prompt_bufnr)
  --           local entry = require("telescope.actions.state").get_selected_entry()
  --           require("telescope.actions").close(prompt_bufnr)
  --           vim.cmd('DiffviewOpen ' .. entry.value)
  --         end,
  --       }
  --     }
  --   },s
  -- },
}

telescope.load_extension('fzf')

-- Keymaps:
local builtin = require('telescope.builtin')
local opts = { silent = true }

-- Full repo find_files (for now using fzf.vim's GFiles, too fast to avoid)
 -- vim.keymap.set("n", "<C-p>", function()
 --   vim.cmd("tabnew")
 --   builtin.git_files({
 --     previewer = false,
 --   })
 -- end, opts)
 --
 -- -- Old files in cache
 -- vim.keymap.set("n", "<C-S-p>", function()
 --   vim.cmd("tabnew")
 --   builtin.oldfiles()
 -- end, opts)

-- live grep on whole repo and open in a new tab (for now using fzf.vim's Rg, too fast to avoid)
-- vim.keymap.set("n", "<C-f>", function()
--   vim.cmd("tabnew")
--   builtin.live_grep()
-- end, opts)

vim.keymap.set("n", "<C-S-f>", builtin.current_buffer_fuzzy_find, opts) -- Find in current buffer

vim.keymap.set("n", "<leader>gs", builtin.git_status, opts)
vim.keymap.set("n", "<leader>gc", builtin.git_commits, opts)
vim.keymap.set("n", "<S-l>", builtin.treesitter, opts)
