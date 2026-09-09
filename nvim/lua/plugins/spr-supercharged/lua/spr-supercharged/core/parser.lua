local aliases = require("spr-supercharged.core.aliases")
local config = require("spr-supercharged.config")
local util = require("spr-supercharged.util")

local M = {}

local STATIC_IMPORT_PATTERN = "from%s+['\"]([^'\"]+)['\"];"
local DYNAMIC_IMPORT_PATTERN = "import%s*%([^)]*['\"]([^'\"]+)['\"][^)]*%)"

---@param code string
---@return string[]
local function extract_import_paths(code)
  local imports = {}

  for path in code:gmatch(STATIC_IMPORT_PATTERN) do
    imports[#imports + 1] = path
  end

  for path in code:gmatch(DYNAMIC_IMPORT_PATTERN) do
    imports[#imports + 1] = path
  end

  return util.unique(imports)
end

---@param file_path string
---@param file_vs_hash table<string, string>
---@param project_path string
---@return string[]
function M.get_imports_from_file(file_path, file_vs_hash, project_path)
  local fd = io.open(file_path, "r")
  if not fd then
    return {}
  end

  local code = fd:read("*a")
  fd:close()

  if not code then
    return {}
  end

  local opts = config.get()
  local import_paths = extract_import_paths(code)
  local resolved = {}

  for _, path in ipairs(import_paths) do
    local hash = aliases.resolve_alias_path(
      path,
      file_path,
      file_vs_hash,
      project_path,
      opts.extensions
    )
    if hash ~= "" then
      resolved[#resolved + 1] = hash
    end
  end

  return resolved
end

---@param files string[]
---@param file_vs_hash table<string, string>
---@param project_path string
---@param on_progress fun(done: integer, total: integer, label: string)?
---@return table<string, string[]>
function M.parse_imports_in_files(files, file_vs_hash, project_path, on_progress)
  local imports_map = {}
  local total = #files
  local update_every = math.max(1, math.floor(total / 100))

  for i, file in ipairs(files) do
    local ok, imports = pcall(M.get_imports_from_file, file, file_vs_hash, project_path)
    if ok and imports and #imports > 0 then
      local file_hash = file_vs_hash[file]
      if file_hash then
        imports_map[file_hash] = imports
      end
    end

    if on_progress and (i % update_every == 0 or i == total) then
      on_progress(i, total, string.format("%d / %d files", i, total))
    end
  end

  return imports_map
end

return M
