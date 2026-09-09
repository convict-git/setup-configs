local config = require("spr-supercharged.config")
local util = require("spr-supercharged.util")

local M = {}

---@param dir string
---@param file_list string[]
---@param skip_dirs string[]
local function collect_files(dir, file_list, skip_dirs)
  local iter = vim.fs.dir(dir)
  if not iter then
    return
  end

  for name, entry_type in iter do
    if name:sub(1, 1) == "." then
      goto continue
    end

    local full_path = util.join(dir, name)

    if entry_type == "dir" or entry_type == "directory" then
      local skip = false
      for _, skip_dir in ipairs(skip_dirs) do
        if name == skip_dir then
          skip = true
          break
        end
      end
      if not skip then
        collect_files(full_path, file_list, skip_dirs)
      end
    else
      file_list[#file_list + 1] = full_path
    end

    ::continue::
  end
end

---@param directories string[]
---@param on_progress fun(done: integer, total: integer, label: string)?
---@return table
function M.scan(directories, on_progress)
  local opts = config.get()
  local files = {}
  local file_vs_hash = {}
  local hash_vs_file = {}
  local total_dirs = #directories

  for worker_idx, directory in ipairs(directories) do
    local file_list = {}
    collect_files(directory, file_list, opts.skip_dirs)

    if on_progress then
      local label = directory:match("([^/]+)$") or directory
      on_progress(worker_idx, total_dirs, label)
    end

    for idx, file_path in ipairs(file_list) do
      local file_hash = string.format("W%d-%d", worker_idx - 1, idx - 1)
      file_vs_hash[file_path] = file_hash
      hash_vs_file[file_hash] = file_path
      files[#files + 1] = file_path
    end
  end

  return {
    files = files,
    file_vs_hash = file_vs_hash,
    hash_vs_file = hash_vs_file,
  }
end

return M
