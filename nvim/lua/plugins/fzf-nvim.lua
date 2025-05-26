-- Fzf.vim
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

vim.cmd([[
  command! -bang -nargs=* RgSubstring call fzf#vim#grep("rg --fixed-strings --column --line-number --no-heading --color=always --smart-case -- " . fzf#shellescape(<q-args>), fzf#vim#with_preview(), <bang>0)
]])

-- Grep on files
vim.keymap.set("n", "<C-f>", function()
  local query = vim.fn.input("Rg -F -S: ")
  if query == nil or query == "" then
    return -- exit if no input
  end

  vim.cmd("tabnew") -- open vertical split
  vim.cmd("RgSubstring " .. query) -- opens Rg
end, { silent = true })

-- Normal mode: vertical split
vim.keymap.set("n", "<leader>v", function()
  vim.cmd("vsplit") -- open vertical split
  vim.cmd("Files") -- opens Files, escape if want to continue on the same file
end, { silent = true })

-- https://github.com/junegunn/fzf?tab=readme-ov-file#respecting-gitignore
-- vim.env.FZF_DEFAULT_COMMAND = "fd --type f --strip-cwd-prefix --hidden --follow --exclude .git"
--
-- The above is suggested but, it takes 12.85 seconds on a large repo,
-- fd --type f --strip-cwd-prefix --hidden --follow --exclude .git > /dev/null ->  1.44s user 7.37s system 68% cpu [12.845 total]
--
-- and without any arguments, it takes around 3.971 seconds
-- fd --type f > /dev/null  1.33s user 7.56s system 223% cpu 3.972 total
-- Not stripping current working directory prefix saves a lot of time:
-- fd --type f --hidden --follow --exclude .git > /dev/null  1.37s user 7.27s system 109% cpu 7.867 total
-- And not following symlinks saves a lot of time too!
-- fd --type f --hidden --exclude .git > /dev/null  1.41s user 7.02s system 209% cpu 4.016 total
--
-- Hence, after a lot of consideration and profiling, I wrote a fd-cache version which,
-- Caches fd results based on arguments and working directory to improve speed, while:
-- Serving from cache if available and fresh
-- Refreshing cache in the background
-- Purging expired caches asynchronously
--
-- Checkout the fd-cache script here: https://github.com/convict-git/setup-configs/blob/main/scripts/fd-cache.sh
--
-- First call
-- fd-cache --type f --strip-cwd-prefix --hidden --follow --exclude .git > /dev/null   1.30s user 7.24s system 251% cpu 3.398 total
-- Subsequent calls - 55 times faster!! Holy shit!
-- fd-cache --type f --strip-cwd-prefix --hidden --follow --exclude .git >   0.00s user 0.01s system 29% cpu 0.062 total
vim.env.FZF_DEFAULT_COMMAND = "fd-cache --type f --strip-cwd-prefix --hidden --follow --exclude .git"
