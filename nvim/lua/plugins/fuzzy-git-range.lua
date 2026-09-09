-- ============================================================================
-- fuzzy-git-range.lua
-- ----------------------------------------------------------------------------
-- Fuzzy *content* search (not filename search) restricted to a specific set of
-- files derived from git. Content search always runs over the *current state*
-- of the files on disk; the commit ranges only identify *which* files.
--
-- Commands (all accept, in any order among the args):
--   --exclude <pat> / --exclude=<pat>  filter out any file whose relative path
--       CONTAINS <pat> (plain substring, case-sensitive), e.g. --exclude .spec.ts.
--       Repeatable.
--   -m / --merge  include files touched by MERGE commits. By default git
--       diff-tree reports NOTHING for a merge commit, so a merge commit given as
--       a single-commit spec contributes no files; -m makes it diff against each
--       parent and list those files (de-duplicated). Ranges (A..B) already
--       include merges regardless.
--
--   :FuzzyGitRange <spec> [<spec> ...] [--exclude <pat> ...] [-m]
--       Files changed in the given commits/ranges ONLY (git diff-tree / diff
--       output) -- no working-tree/staged files.
--       Each <spec> is either a single commit (e.g. d2abd3b) or a range
--       (e.g. 11d1623~..ab3cbdb  or  A...B). Multiple specs are allowed.
--       Calling with NO arguments re-uses the arguments from the previous
--       invocation (specs, excludes AND -m; persisted across sessions, per repo,
--       per command).
--
--   :FuzzyGitRangeLive <spec> [<spec> ...] [--exclude <pat> ...] [-m]
--       Same as :FuzzyGitRange, PLUS the current working-tree files:
--         * tracked-but-not-yet-staged (eligible, i.e. not gitignored),
--         * untracked-but-eligible (respecting .gitignore), and
--         * staged.
--       The union is de-duplicated.
--
--   :FuzzyGitSince <commit> [--exclude <pat> ...] [-m]
--       Equivalent to  :FuzzyGitRange <commit>..HEAD  (all commits including and
--       after <commit>, up to HEAD).
--
-- UI: fzf.vim, two-pane split -> left pane = matching lines + search bar (paths
--     shown RELATIVE to the git root, left-truncated), right pane = file content
--     preview (via fzf#vim#with_preview).
-- ============================================================================

local M = {}

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

-- Run a system command (list form, no shell) and return { ok, stdout_lines }.
-- Uses vim.system when available (nvim >= 0.10), falls back to systemlist.
local function run(cmd, cwd)
  if vim.system then
    local res = vim.system(cmd, { text = true, cwd = cwd }):wait()
    local out = {}
    for line in (res.stdout or ""):gmatch("[^\r\n]+") do
      table.insert(out, line)
    end
    return res.code == 0, out, (res.stderr or "")
  else
    -- Fallback: build a shell-escaped string.
    local parts = {}
    for _, a in ipairs(cmd) do
      table.insert(parts, vim.fn.shellescape(a))
    end
    local out = vim.fn.systemlist(table.concat(parts, " "))
    return vim.v.shell_error == 0, out, ""
  end
end

-- Absolute path of the git repo root, or nil if not in a repo.
local function git_root()
  local ok, out = run({ "git", "rev-parse", "--show-toplevel" })
  if ok and out[1] and out[1] ~= "" then
    return out[1]
  end
  return nil
end

-- Is a spec a range (contains .. or ...)? Otherwise it's a single commit.
local function is_range(spec)
  return spec:find("%.%.") ~= nil
end

-- Return the list of files affected by a single spec (range or commit),
-- as repo-relative paths. Returns {} on any git error (bad ref, etc.).
--
-- merge: when true, single-commit specs pass `-m` to git diff-tree so MERGE
-- commits report the files they touched (diff against each parent). By default
-- git diff-tree shows NOTHING for a merge commit, so merge commits contribute
-- no files unless this is set. `-m` may list a file once per parent, but the
-- caller (collect_files) de-duplicates.
local function files_for_spec(spec, root, merge)
  if is_range(spec) then
    -- git diff --name-only handles both A..B and A...B correctly (incl. merges).
    local ok, out = run({ "git", "diff", "--name-only", spec }, root)
    return ok and out or {}
  else
    -- Single commit: files changed in that commit vs its parent(s).
    local cmd = { "git", "diff-tree", "--no-commit-id", "--name-only", "-r" }
    if merge then
      table.insert(cmd, "-m")
    end
    table.insert(cmd, spec)
    local ok, out = run(cmd, root)
    return ok and out or {}
  end
end

-- Files with unstaged changes to tracked files (excludes gitignored by nature,
-- since gitignored files are untracked).
local function unstaged_tracked_files(root)
  local ok, out = run({ "git", "diff", "--name-only" }, root)
  return ok and out or {}
end

-- Files staged in the index.
local function staged_files(root)
  local ok, out = run({ "git", "diff", "--cached", "--name-only" }, root)
  return ok and out or {}
end

-- Untracked-but-eligible files (respecting .gitignore via --exclude-standard).
-- These are "not yet staged, but eligible" additions.
local function untracked_eligible_files(root)
  local ok, out = run(
    { "git", "ls-files", "--others", "--exclude-standard" },
    root
  )
  return ok and out or {}
end

-- ---------------------------------------------------------------------------
-- Persistence of last-used arguments (per repo, survives restarts).
-- Stored as a small JSON map { [repo_root] = { "spec1", "spec2", ... } }.
-- ---------------------------------------------------------------------------

local state_file = vim.fn.stdpath("state") .. "/fuzzy_git_range.json"

local function load_state()
  local f = io.open(state_file, "r")
  if not f then
    return {}
  end
  local content = f:read("*a")
  f:close()
  if not content or content == "" then
    return {}
  end
  local ok, decoded = pcall(vim.json.decode, content)
  if ok and type(decoded) == "table" then
    return decoded
  end
  return {}
end

local function save_last_args(root, args)
  local st = load_state()
  st[root] = args
  local ok, encoded = pcall(vim.json.encode, st)
  if not ok then
    return
  end
  local f = io.open(state_file, "w")
  if not f then
    return
  end
  f:write(encoded)
  f:close()
end

local function get_last_args(root)
  local st = load_state()
  local a = st[root]
  if type(a) == "table" and #a > 0 then
    return a
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Core: collect the unique set of existing files to search.
-- ---------------------------------------------------------------------------

-- Returns rel_files: de-duplicated, repo-relative paths of files that currently
-- exist on disk. Paths are relative to `root` so the fzf list shows relative
-- paths (rg + preview run with cwd = root, see launch_fzf).
--
-- opts.include_working (default false): also include tracked-but-unstaged
--   (eligible) + untracked-eligible + staged files, on top of the spec files.
-- opts.excludes (default {}): list of plain substrings; any file whose relative
--   path CONTAINS one of these is filtered out (e.g. ".spec.ts").
-- opts.merge (default false): pass `-m` to git diff-tree so merge commits in
--   `specs` report their touched files (see files_for_spec).
local function collect_files(specs, root, opts)
  opts = opts or {}
  local excludes = opts.excludes or {}
  local seen = {}
  local rel_files = {}

  local function add_all(list)
    for _, rel in ipairs(list) do
      if rel ~= "" and not seen[rel] then
        seen[rel] = true
        table.insert(rel_files, rel)
      end
    end
  end

  -- 1. Files from each commit / range spec (diff-tree / diff output).
  for _, spec in ipairs(specs) do
    add_all(files_for_spec(spec, root, opts.merge))
  end

  -- 2. (Live variant only) Tracked-but-unstaged (eligible) + untracked-eligible
  --    + staged files.
  if opts.include_working then
    add_all(unstaged_tracked_files(root))
    add_all(untracked_eligible_files(root))
    add_all(staged_files(root))
  end

  -- True if `rel` matches any exclude substring (plain, case-sensitive).
  local function is_excluded(rel)
    for _, pat in ipairs(excludes) do
      if pat ~= "" and rel:find(pat, 1, true) then
        return true
      end
    end
    return false
  end

  -- Keep only files that currently exist (we search their current state) and
  -- that aren't excluded.
  local existing_rel = {}
  for _, rel in ipairs(rel_files) do
    if not is_excluded(rel) and vim.fn.filereadable(root .. "/" .. rel) == 1 then
      table.insert(existing_rel, rel)
    end
  end

  return existing_rel
end

-- Parse a raw fargs list into { specs = {...}, excludes = {...}, merge = bool }.
-- Recognizes:
--   --exclude <pat>  /  --exclude=<pat>   (repeatable) -> exclude substrings
--   -m  /  --merge                        (flag)       -> include merge-commit
--                                                          files (git diff-tree -m)
-- Everything else is treated as a commit / range spec.
local function parse_args(args)
  local specs, excludes = {}, {}
  local merge = false
  local i = 1
  while i <= #args do
    local a = args[i]
    local eq = a:match("^%-%-exclude=(.*)$")
    if eq ~= nil then
      if eq ~= "" then
        table.insert(excludes, eq)
      end
      i = i + 1
    elseif a == "--exclude" then
      -- next token is the pattern
      if args[i + 1] then
        table.insert(excludes, args[i + 1])
      end
      i = i + 2
    elseif a == "-m" or a == "--merge" then
      merge = true
      i = i + 1
    else
      table.insert(specs, a)
      i = i + 1
    end
  end
  return { specs = specs, excludes = excludes, merge = merge }
end

-- ---------------------------------------------------------------------------
-- Launch the fzf two-pane content finder over the given files.
-- ---------------------------------------------------------------------------

local function launch_fzf(rel_files, root)
  if #rel_files == 0 then
    vim.notify("[FuzzyGitRange] No matching files found.", vim.log.levels.WARN)
    return
  end

  -- Persist the file list (NUL-separated, so paths with spaces/newlines are
  -- safe) to a temp file. A commit range can contain thousands of files, which
  -- would overflow the shell command line if passed as args, so we stream the
  -- paths into rg via `cat list | xargs -0 rg ...` in the wrapper below. rg must
  -- receive the paths as *arguments* (so it opens & searches each file) -- NOT
  -- piped as text, which would make rg search the path strings themselves.
  --
  -- Paths are stored RELATIVE to the git root; the wrapper (and fzf, via
  -- spec.dir = root) run with cwd = root.
  local list_file = vim.fn.tempname()
  do
    local f = io.open(list_file, "w")
    for _, p in ipairs(rel_files) do
      f:write(p, "\0")
    end
    f:close()
  end

  -- ripgrep flags. --color=never so the output is cleanly parseable by awk
  -- (ANSI codes would corrupt field splitting + char counting for truncation).
  -- --fixed-strings => literal substring (content) search rather than regex.
  local rg_opts = table.concat({
    "--column",
    "--line-number",
    "--no-heading",
    "--color=never",
    "--smart-case",
    "--fixed-strings",
  }, " ")

  -- LEFT-TRUNCATION of the displayed path.
  -- ---------------------------------------------------------------------------
  -- fzf only ever right-truncates long lines, so a long "dir/dir/dir/file:..."
  -- loses the *filename* (the important part) off the right edge. We fix this
  -- the same way the C-p buffer picker does: pre-truncate the path in code,
  -- keeping the TAIL and prefixing with an ellipsis ("…"). Since results are
  -- generated live by rg, we do the truncation in awk inside the wrapper.
  --
  -- rg emits:  path:line:col:text
  -- awk turns each line into a TAB-delimited pair:
  --   <path>:<line>:<col>  \t  <…truncated_path>:<line>:  <text>
  -- fzf shows only field 2 (--with-nth 2..) -> left-truncated, readable.
  -- The custom sink + preview parse field 1 (the full, untruncated path:line:col)
  -- so opening/preview always use the real path regardless of display.
  --
  -- PATHW = how many chars of the path tail to keep before the ":line:" suffix.
  local pathw = 60
  local awk = table.concat({
    "awk -F: -v OFS=: -v W=" .. pathw .. " '",
    "{",
    -- path = everything before the last two numeric fields (line, col).
    -- rg guarantees exactly path:line:col:text, but the path itself may contain
    -- ':' -> rebuild path from $1..$(NF-3+? ) is fragile; instead: line=$2? No.
    -- Reliable: match the fixed pattern from the FRONT is hard with ':' in path.
    -- Paths from git rarely contain ':' on unix, so treat $1 as the path,
    -- $2=line, $3=col, and the rest (4..NF joined by :) as text.
    "  path=$1; line=$2; col=$3;",
    '  text=$4; for(i=5;i<=NF;i++) text=text":"$i;',
    "  disp=path;",
    "  if (length(disp) > W) disp=\"…\" substr(disp, length(disp)-W+2);",
    -- field1 (data, hidden) \t field2 (display)
    '  printf "%s:%s:%s\\t%s:%s: %s\\n", path, line, col, disp, line, text;',
    "}'",
  }, " ")

  -- The wrapper cd's to the git root so the relative paths in the list resolve
  -- (both for rg opening the files and for the relative paths it prints).
  -- An empty query lists every line (rg with an empty --fixed-strings pattern
  -- would error), so the whole file set stays visible before the user types.
  local wrapper = vim.fn.tempname()
  do
    local f = io.open(wrapper, "w")
    f:write("#!/usr/bin/env bash\n")
    f:write('q="$1"\n')
    f:write(string.format("cd %s || exit 0\n", vim.fn.shellescape(root)))
    f:write(string.format("list=%s\n", vim.fn.shellescape(list_file)))
    f:write('if [ -z "$q" ]; then\n')
    f:write('  cat "$list" | xargs -0 rg --column --line-number --no-heading --color=never -e "^" 2> /dev/null | ' .. awk .. ' || true\n')
    f:write("else\n")
    f:write(string.format('  cat "$list" | xargs -0 rg %s -- "$q" 2> /dev/null | %s || true\n', rg_opts, awk))
    f:write("fi\n")
    f:close()
  end
  vim.fn.setfperm(wrapper, "rwx------")

  -- Preview command: bat over field 1's path, highlighting its line. field 1 is
  -- `path:line:col`; we split on ':' to get path + line for bat.
  local has_bat = vim.fn.executable("bat") == 1
  local preview_cmd
  if has_bat then
    preview_cmd = table.concat({
      'f={1}; p=${f%%:*}; rest=${f#*:}; ln=${rest%%:*};',
      'bat --style=numbers --color=always --highlight-line "$ln"',
      '--line-range $(( ln>15 ? ln-15 : 1 )): -- "$p"',
    }, " ")
  else
    preview_cmd = 'f={1}; p=${f%%:*}; cat -- "$p"'
  end

  local wrapper_esc = vim.fn.shellescape(wrapper)
  local initial_cmd = wrapper_esc .. " ''"
  local reload_cmd = wrapper_esc .. " {q}"

  local spec = {
    dir = root,
    -- Custom sink: field 1 (before TAB) is `path:line:col`; jump there.
    sinklist = function(selected)
      if not selected or #selected == 0 then
        return
      end
      local entry = selected[#selected]
      if type(entry) ~= "string" or entry == "" then
        return
      end
      local data = vim.split(entry, "\t", { plain = true })[1] or entry
      local path, lnum, col = data:match("^(.-):(%d+):(%d+)$")
      if not path then
        path = data:match("^(.-):(%d+)") or data
        lnum = tonumber(data:match(":(%d+)")) or 1
        col = 1
      end
      lnum = tonumber(lnum) or 1
      col = tonumber(col) or 1
      -- Open relative to git root (sink runs with nvim's cwd, so make absolute).
      local abs = path
      if not path:match("^/") then
        abs = root .. "/" .. path
      end
      vim.cmd("edit " .. vim.fn.fnameescape(abs))
      -- Defer the cursor jump: opening the file fires BufReadPost, whose
      -- "restore cursor to last position" autocmd schedules a set_cursor. We
      -- schedule ours afterwards (FIFO) so we win and land on the match's
      -- line/col instead of the file's previously-remembered position.
      vim.schedule(function()
        pcall(vim.api.nvim_win_set_cursor, 0, { lnum, math.max(col - 1, 0) })
        vim.cmd("normal! zz")
      end)
    end,
    options = {
      "--prompt", "GitRange> ",
      "--layout=reverse",
      "--ansi",
      "--disabled", -- rg drives filtering via reload; fzf doesn't filter locally
      "--delimiter", "\t",
      "--with-nth", "2..", -- DISPLAY only field 2 (the left-truncated pretty line)
      "--ellipsis", "…",
      "--preview", preview_cmd,
      "--preview-window", "right:55%",
      "--bind", "start:reload:" .. initial_cmd,
      "--bind", "change:reload:" .. reload_cmd,
    },
    window = { width = 0.95, height = 0.9 },
  }

  vim.fn["fzf#run"](vim.fn["fzf#wrap"]("fuzzy-git-range", spec, 0))
end

-- ---------------------------------------------------------------------------
-- Public entry points
-- ---------------------------------------------------------------------------

-- Shared implementation.
--   args            : raw fargs (commit/range specs interleaved with
--                     `--exclude <pat>` flags); if empty, reuse persisted args.
--   include_working : also include tracked-but-unstaged/untracked-eligible/staged.
--   label           : "FuzzyGitRange" / "FuzzyGitRangeLive" (for messages).
-- The RAW args (incl. --exclude flags) are persisted per repo AND per variant,
-- so no-arg reuse restores both the commit specs and the exclude patterns.
local function run_range(args, include_working, label)
  local root = git_root()
  if not root then
    vim.notify("[" .. label .. "] Not inside a git repository.", vim.log.levels.ERROR)
    return
  end

  -- Namespace persisted args per variant so Live and non-Live don't clobber.
  local store_key = root .. "\0" .. label

  if not args or #args == 0 then
    args = get_last_args(store_key)
    if not args then
      vim.notify(
        "[" .. label .. "] No arguments given and no previous invocation saved.",
        vim.log.levels.ERROR
      )
      return
    end
    vim.notify(
      "[" .. label .. "] Reusing last args: " .. table.concat(args, " "),
      vim.log.levels.INFO
    )
  else
    -- Persist only real (explicit) invocations.
    save_last_args(store_key, args)
  end

  local parsed = parse_args(args)
  if #parsed.specs == 0 then
    vim.notify(
      "[" .. label .. "] No commit/range specs given.",
      vim.log.levels.ERROR
    )
    return
  end

  local rel_files = collect_files(parsed.specs, root, {
    include_working = include_working,
    excludes = parsed.excludes,
    merge = parsed.merge,
  })

  local extra = {}
  if parsed.merge then
    table.insert(extra, "merge commits")
  end
  if #parsed.excludes > 0 then
    table.insert(extra, "excluding: " .. table.concat(parsed.excludes, ", "))
  end
  local extra_msg = (#extra > 0) and (" (" .. table.concat(extra, "; ") .. ")") or ""
  vim.notify(
    string.format("[%s] Searching %d file(s)%s.", label, #rel_files, extra_msg),
    vim.log.levels.INFO
  )
  launch_fzf(rel_files, root)
end

-- FuzzyGitRange: files changed in the given commits/ranges ONLY (diff-tree /
-- diff output) -- no tracked/staged/untracked working-tree files.
-- args: commit/range specs, optionally with `--exclude <pat>` flags.
-- If args is empty, reuse the last FuzzyGitRange invocation.
function M.fuzzy_git_range(args)
  run_range(args, false, "FuzzyGitRange")
end

-- FuzzyGitRangeLive: same as FuzzyGitRange, plus tracked-but-unstaged
-- (eligible), untracked-eligible, and staged working-tree files.
function M.fuzzy_git_range_live(args)
  run_range(args, true, "FuzzyGitRangeLive")
end

-- FuzzyGitSince: <commit> [--exclude <pat> ...]; behaves like
-- FuzzyGitRange <commit>..HEAD (with the same --exclude support).
function M.fuzzy_git_since(args)
  args = args or {}
  local parsed = parse_args(args)
  local commit = parsed.specs[1]
  if not commit or commit == "" then
    vim.notify("[FuzzyGitSince] A commit argument is required.", vim.log.levels.ERROR)
    return
  end
  -- Rebuild args as: <commit>..HEAD  plus the original --exclude / -m flags.
  local forwarded = { commit .. "..HEAD" }
  for _, pat in ipairs(parsed.excludes) do
    table.insert(forwarded, "--exclude")
    table.insert(forwarded, pat)
  end
  if parsed.merge then
    table.insert(forwarded, "-m")
  end
  M.fuzzy_git_range(forwarded)
end

-- ---------------------------------------------------------------------------
-- Command registration
-- ---------------------------------------------------------------------------

vim.api.nvim_create_user_command("FuzzyGitRange", function(opts)
  M.fuzzy_git_range(opts.fargs)
end, {
  nargs = "*",
  desc = "Content search over files changed in commit ranges [--exclude <pat>] [-m]",
})

vim.api.nvim_create_user_command("FuzzyGitRangeLive", function(opts)
  M.fuzzy_git_range_live(opts.fargs)
end, {
  nargs = "*",
  desc = "Like FuzzyGitRange + tracked/untracked-eligible/staged [--exclude][-m]",
})

vim.api.nvim_create_user_command("FuzzyGitSince", function(opts)
  M.fuzzy_git_since(opts.fargs)
end, {
  nargs = "+",
  desc = "Content search over files changed since <commit> [--exclude <pat>] [-m]",
})

return M
