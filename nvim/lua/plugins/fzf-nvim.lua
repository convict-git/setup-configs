-- Fzf.vim
vim.cmd([[
  let g:fzf_vim = {} " Initialize configuration dictionary
  let g:fzf_vim.preview_window = ['down,50%', 'ctrl-/']
  let g:fzf_vim.commits_log_options = "--graph --abbrev-commit --decorate --date=relative --format=format:'%C(bold cyan)%h%C(reset) %C(bold yellow)%d%C(reset) %C(bold blue)%<(10,trunc)%an%C(reset) %C(white)%<(50,trunc)%s%C(reset) %C(green)(%ar)%C(reset)'"
  let g:fzf_buffers_options = '--preview ""'
  let g:fzf_files_options = '--preview ""'
]])


vim.g.fzf_layout = {
  window = {
   width = 0.9,
   height = 0.9,
   border = 'rounded' -- optional: 'single', 'double', 'sharp', 'rounded'
  },
}

-- vim.keymap.set("n", "<C-p>", function()
--   vim.cmd("tabnew")     -- open a new tab
--   vim.cmd("Files")     -- run Files in the new tab
-- end, { silent = true })

vim.keymap.set("n", "<C-p>", ":ConBuffersWithMultiDelete<CR>", { silent = true })
vim.keymap.set("n", "<C-S-p>", ":Files<CR>", { silent = true })

vim.api.nvim_create_user_command('ConBuffersWithMultiDelete', function()
  local buffers = {}
  local max_width = vim.fn.winwidth(0) * 0.5  -- 50% of current window width

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.api.nvim_buf_get_option(bufnr, "buflisted") then
      local name = vim.api.nvim_buf_get_name(bufnr)
      local tail = vim.fn.fnamemodify(name, ":t")
      local relname = vim.fn.fnamemodify(name, ":.")
      if relname == "" then
        relname = "[No Name]"
      end

      local display_name = relname
      local max_chars = math.floor(max_width) - 6
      if #relname > max_chars then
        display_name = "…" .. string.sub(relname, -max_chars + 1)
      end
      display_name = display_name .. "  ■  " .. tail

      table.insert(buffers, string.format("%3d %s", bufnr, display_name))
    end
  end

  vim.fn['fzf#run'](vim.fn['fzf#wrap']({
    source = buffers,
    sinklist = function(selected)
      if #selected == 0 then return end

      -- Single selection: switch to buffer
      if #selected == 1 then
        local bufnr = tonumber(selected[1]:match("^%s*(%d+)"))
        if bufnr then
          vim.api.nvim_command("buffer " .. bufnr)
        end
        return
      end

      -- Multi-selection: prompt for deletion
      local to_delete = {}
      for _, line in ipairs(selected) do
        local bufnr = tonumber(line:match("^%s*(%d+)"))
        if bufnr then
          table.insert(to_delete, bufnr)
        end
      end

      for _, bufnr in ipairs(to_delete) do
        -- Use bdelete to close the buffer safely
        vim.api.nvim_command("bd " .. bufnr)
      end
    end,
    options = { '--layout=reverse', '--preview-window=up:40%', '--multi', '--exact' },
    window = { width = 0.9, height = 0.4, yoffset = 0.2 }
  }))
end, {})

vim.cmd([[
  " For Files command
  command! -bang -nargs=? -complete=dir Files
      \ call fzf#vim#files(<q-args>, fzf#vim#with_preview({
      \   'options': ['--preview-window=up:40%', '--layout=reverse'],
      \   'window': { 'width': 0.9, 'height': 0.4, 'yoffset': 0.2 }
      \ }), <bang>0)

  " For Buffers command
  command! -bang Buffers
      \ call fzf#vim#buffers('', fzf#vim#with_preview({
      \   'options': ['--preview-window=up:40%', '--layout=reverse'],
      \   'window': { 'width': 0.9, 'height': 0.4, 'yoffset': 0.2 }
      \ }), <bang>0)

  command! -bang -nargs=* RgSubstring call fzf#vim#grep("rg --fixed-strings --mmap --column --line-number --no-heading --color=always --smart-case -- " . fzf#shellescape(<q-args>), fzf#vim#with_preview(), <bang>0)
]])

local function grep_open_buffers()
  local lines = {}
  local path_to_bufnr = {}
  local rel_to_full_path = {}

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.api.nvim_buf_get_option(bufnr, "buflisted") then
      local abs_path = vim.api.nvim_buf_get_name(bufnr)
      if abs_path ~= "" then
        local rel_path = vim.fn.fnamemodify(abs_path, ":.")
        rel_to_full_path[rel_path] = abs_path;
        path_to_bufnr[abs_path] = bufnr
        local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        for i, line in ipairs(buf_lines) do
          -- Use absolute path here
          table.insert(lines, string.format("%s:%d: %s", rel_path, i, line))
        end
      end
    end
  end

  local opts = vim.fn["fzf#vim#with_preview"]({
    source = lines,
    sink = function(entry)
      if not entry then return end
      local parts = vim.split(entry, ":", { plain = true, trimempty = true })
      if #parts < 2 then return end

      local rel_path = parts[1]
      local full_path = rel_to_full_path[rel_path]
      local lnum = tonumber(parts[2]) or 1

      local bufnr = path_to_bufnr[full_path]
      if bufnr and vim.api.nvim_buf_is_loaded(bufnr) then
        -- Switch to the correct buffer directly
        vim.api.nvim_set_current_buf(bufnr)
      else
        -- Fallback to editing the file
        vim.cmd("edit " .. vim.fn.fnameescape(file))
      end

      vim.api.nvim_win_set_cursor(0, { lnum, 0 })
    end,
    options = {
      "--ansi",
      "--prompt=   ",
      "--no-sort",
      "--exact",
      "--nth=2..",
      "--reverse",
    },
    window = { width = 0.8, height = 0.7, yoffset = 0.2 }
  }, "down:30%")

  vim.fn["fzf#run"](opts)
end

vim.keymap.set("n", "<C-f>", grep_open_buffers, { desc = "FZF grep open buffers" })

-- Grep on files
vim.keymap.set("n", "<C-S-f>", function()
  local query = vim.fn.input("Rg -F -S: ")
  if query == nil or query == "" then
    return -- exit if no input
  end

  -- vim.cmd("tabnew")
  vim.cmd("enew")
  vim.cmd("RgSubstring " .. query) -- opens Rg
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
