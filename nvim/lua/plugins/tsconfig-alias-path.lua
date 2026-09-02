local function find_tsconfig_dir(start_dir)
  local uv = vim.loop
  local function is_root(path)
    return path == "/" or path:match("^%a:[/\\]$")
  end

  local dir = start_dir
  while not is_root(dir) do
    local tsconfig = dir .. "/tsconfig.json"
    local stat = uv.fs_stat(tsconfig)
    if stat and stat.type == "file" then
      return dir, tsconfig
    end
    dir = vim.fn.fnamemodify(dir, ":h")
  end
end

local function read_tsconfig_paths(tsconfig_path)
  local json = vim.fn.json_decode(vim.fn.readfile(tsconfig_path))
  return json.compilerOptions and json.compilerOptions.paths or {}
end

local function strip_extension(path)
  return path:gsub("%.[^/%.]+$", "") -- removes .ts, .js, .tsx, .jsx, etc.
end

local function normalize_path(path)
  return path:gsub("\\", "/")
end

local function alias_from_tsconfig_path()
  local file_abs_path = vim.fn.expand("%:p")
  local file_dir = vim.fn.fnamemodify(file_abs_path, ":h")
  local tsconfig_dir, tsconfig_path = find_tsconfig_dir(file_dir)
  if not tsconfig_dir then
    print("No tsconfig.json found")
    return
  end

  local relative_to_tsconfig = vim.fn.fnamemodify(file_abs_path, ":." .. tsconfig_dir)
  relative_to_tsconfig = normalize_path(strip_extension(relative_to_tsconfig))

  local paths = read_tsconfig_paths(tsconfig_path)

  for alias, targets in pairs(paths) do
    local target = targets[1] -- We just use the first target
    target = normalize_path(strip_extension(target:gsub("%*", "")))

    if relative_to_tsconfig:find("^" .. vim.pesc(target)) then
      local suffix = relative_to_tsconfig:sub(#target + 1)
      local final_alias = alias:gsub("%*$", "") .. suffix
      vim.fn.setreg("+", final_alias)
      print(final_alias)
      return
    end
  end

  print("No alias match found for: " .. relative_to_tsconfig)
end

vim.keymap.set("n", "<leader>ap", alias_from_tsconfig_path, {
  desc = "Copy aliased import path using tsconfig.json",
})

