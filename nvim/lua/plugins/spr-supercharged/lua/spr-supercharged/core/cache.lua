local config = require("spr-supercharged.config")
local util = require("spr-supercharged.util")

local M = {}

---@class CacheData
---@field hash_vs_file table<string, string>
---@field file_vs_hash table<string, string>
---@field dependency_graph table<string, [string[], string[]]>
---@field initialized boolean
---@field modified_time number?

local shared_vars = {
  hash_vs_file = {},
  file_vs_hash = {},
  dependency_graph = {},
  initialized = false,
  modified_time = nil,
}

---@param project_path string
---@return string
local function cache_dir(project_path)
  local opts = config.get()
  return util.join(project_path, opts.cache_dir)
end

---@param project_path string
---@return string
local function dependency_file(project_path)
  return util.join(cache_dir(project_path), "dependency.json")
end

---@param project_path string
---@param hash_vs_file table<string, string>
---@param imports table<string, string[]>
---@param dependency_graph table<string, [string[], string[]]>
---@param opts table?
function M.save(project_path, hash_vs_file, imports, dependency_graph, opts)
  opts = opts or {}
  local destination = cache_dir(project_path)

  if vim.fn.isdirectory(destination) == 0 then
    vim.fn.mkdir(destination, "p")
  end

  local hash_file = util.join(destination, "hashVsFile.json")
  local imports_file = util.join(destination, "imports.json")
  local dependency_path = util.join(destination, "dependency.json")

  local fd

  fd = io.open(hash_file, "w")
  if fd then
    fd:write(vim.json.encode(hash_vs_file))
    fd:close()
  end

  fd = io.open(imports_file, "w")
  if fd then
    fd:write(vim.json.encode(imports))
    fd:close()
  end

  fd = io.open(dependency_path, "w")
  if fd then
    fd:write(vim.json.encode(dependency_graph))
    fd:close()
  end

  M.invalidate()
  if not opts.quiet then
    util.notify_success("Results saved to " .. destination)
  end
end

function M.invalidate()
  shared_vars.initialized = false
  shared_vars.modified_time = nil
end

---@param project_path string
---@return CacheData
function M.load(project_path)
  local destination = cache_dir(project_path)
  local dep_file = dependency_file(project_path)

  if vim.fn.isdirectory(destination) == 0 then
    util.notify_error("No results found in " .. destination .. ". Please run :SprinklrScan first.")
    return {
      hash_vs_file = {},
      file_vs_hash = {},
      dependency_graph = {},
      initialized = false,
    }
  end

  local stat = vim.uv.fs_stat(dep_file)
  if not stat then
    util.notify_error("Incomplete results in " .. destination .. ". Please run :SprinklrScan first.")
    return {
      hash_vs_file = {},
      file_vs_hash = {},
      dependency_graph = {},
      initialized = false,
    }
  end

  local mtime_ms = stat.mtime.sec * 1000 + math.floor(stat.mtime.nsec / 1000000)

  if
    shared_vars.initialized
    and shared_vars.modified_time == mtime_ms
    and shared_vars.dependency_graph
    and shared_vars.file_vs_hash
    and shared_vars.hash_vs_file
  then
    return shared_vars
  end

  local hash_file = util.join(destination, "hashVsFile.json")
  if vim.fn.filereadable(hash_file) == 0 or vim.fn.filereadable(dep_file) == 0 then
    util.notify_error("Incomplete results in " .. destination .. ". Please run :SprinklrScan first.")
    return {
      hash_vs_file = {},
      file_vs_hash = {},
      dependency_graph = {},
      initialized = false,
    }
  end

  local hash_vs_file = vim.json.decode(table.concat(vim.fn.readfile(hash_file), "\n"))
  local dependency_graph = vim.json.decode(table.concat(vim.fn.readfile(dep_file), "\n"))

  local file_vs_hash = {}
  for hash, file in pairs(hash_vs_file) do
    file_vs_hash[file] = hash
  end

  shared_vars.hash_vs_file = hash_vs_file
  shared_vars.dependency_graph = dependency_graph
  shared_vars.file_vs_hash = file_vs_hash
  shared_vars.initialized = true
  shared_vars.modified_time = mtime_ms

  return shared_vars
end

return M
