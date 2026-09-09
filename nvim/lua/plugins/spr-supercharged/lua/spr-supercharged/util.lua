local M = {}

---@return string?
function M.get_project_path()
  local cwd = vim.fn.getcwd()
  if cwd and cwd ~= "" then
    return vim.fs.normalize(cwd)
  end
  return nil
end

---@param path string
---@return string
function M.normalize(path)
  return vim.fs.normalize(path)
end

---@param ... string|string[]
---@return string
function M.join(...)
  local parts = { ... }
  if #parts == 1 and type(parts[1]) == "table" then
    parts = parts[1]
  end
  return M.normalize(table.concat(parts, "/"))
end

---@param file_path string
---@return string
function M.dirname(file_path)
  return vim.fs.dirname(file_path)
end

---@param base string
---@param relative string
---@return string
function M.resolve(base, relative)
  if relative:sub(1, 1) == "/" then
    return M.normalize(relative)
  end
  return M.normalize(M.join(M.dirname(base), relative))
end

---@param path string
---@return string
function M.basename(path)
  local parts = vim.split(path, "/")
  return parts[#parts] or path
end

---@param path string
---@return string
function M.relative_to_root(path)
  if path == "" then
    return path
  end

  path = M.normalize(path)
  local project = M.get_project_path()
  if project then
    project = M.normalize(project)
    local prefix = project
    if not prefix:match("/$") then
      prefix = prefix .. "/"
    end
    if path == project then
      return "."
    end
    if path:sub(1, #prefix) == prefix then
      return path:sub(#prefix + 1)
    end
  end

  local rel = vim.fn.fnamemodify(path, ":.")
  if rel and rel ~= "" and rel ~= path then
    return rel
  end

  return path
end

---@param path string
---@return string
function M.parent_dir_name(path)
  local parts = vim.split(path, "/")
  return parts[#parts - 1] or "Unknown Directory"
end

---@param msg string
---@param level integer?
function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Sprinklr Supercharged" })
end

---@param msg string
function M.notify_error(msg)
  M.notify(msg, vim.log.levels.ERROR)
end

---@param msg string
function M.notify_success(msg)
  M.notify(msg, vim.log.levels.INFO)
end

---@param list string[]
---@return string[]
function M.unique(list)
  local seen = {}
  local result = {}
  for _, item in ipairs(list) do
    if not seen[item] then
      seen[item] = true
      result[#result + 1] = item
    end
  end
  return result
end

return M
