-- Fzf.vim
-- https://github.com/junegunn/fzf?tab=readme-ov-file#respecting-gitignore
vim.env.FZF_DEFAULT_COMMAND = "fd --type f --strip-cwd-prefix --hidden --follow --exclude .git"
vim.cmd([[
  let g:fzf_vim = {} " Initialize configuration dictionary
  let g:fzf_vim.preview_window = ['down,50%', 'ctrl-/']
  let g:fzf_vim.commits_log_options = "--graph --abbrev-commit --decorate --date=relative --format=format:'%C(bold cyan)%h%C(reset) %C(bold yellow)%d%C(reset) %C(bold blue)%<(10,trunc)%an%C(reset) %C(white)%<(50,trunc)%s%C(reset) %C(green)(%ar)%C(reset)'"
]])

vim.g.fzf_layout = {
  window = {
   width = 0.9,
   height = 0.9,
   border = 'rounded' -- optional: 'single', 'double', 'sharp', 'rounded'
  },
}

vim.keymap.set("n", "<C-p>", function()
  vim.cmd("tabnew")     -- open a new tab
  vim.cmd("Files")     -- run Files in the new tab
end, { silent = true })

vim.keymap.set("n", "<C-S-p>", ":Files<CR>", { silent = true })

-- Grep on files
vim.keymap.set("n", "<C-f>", function()
  vim.cmd("vsplit") -- open vertical split
  vim.cmd("Rg") -- opens Rg
end, { silent = true })

-- Normal mode: vertical split
vim.keymap.set("n", "<leader>v", function()
  vim.cmd("vsplit") -- open vertical split
  vim.cmd("Files") -- opens Files, escape if want to continue on the same file
end, { silent = true })
