local util = require("spr-supercharged.util")

local M = {}

---@class ReferenceItem
---@field label string
---@field description string
---@field path string
---@field collapsible boolean
---@field children_fn function?

---@param opts table
---@return ReferenceItem[]
function M.get_file_references(opts)
  local file_path = opts.file_path
  local dependency_graph = opts.dependency_graph
  local file_vs_hash = opts.file_vs_hash
  local hash_vs_file = opts.hash_vs_file

  local file_hash = file_vs_hash[file_path]

  if not file_hash then
    return {
      {
        label = "File Not Found",
        description = "This file is not part of the dependency graph.",
        path = file_path,
        collapsible = false,
      },
    }
  end

  local node = dependency_graph[file_hash]
  local references = node and node[2]

  if not references or #references == 0 then
    return {
      {
        label = "No References Found",
        description = "This file has no references.",
        path = file_path,
        collapsible = false,
      },
    }
  end

  local items = {}

  for _, ref in ipairs(references) do
    local ref_file_path = hash_vs_file[ref]
    if not ref_file_path then
      items[#items + 1] = {
        label = "Unknown Reference: " .. ref,
        description = "This reference could not be resolved.",
        path = "",
        collapsible = false,
      }
    else
      local ref_node = dependency_graph[ref]
      local has_children = ref_node and ref_node[2] and #ref_node[2] > 0

      items[#items + 1] = {
        label = util.basename(ref_file_path),
        description = util.parent_dir_name(ref_file_path),
        path = ref_file_path,
        collapsible = has_children,
      }
    end
  end

  table.sort(items, function(a, b)
    return a.label < b.label
  end)

  return items
end

return M
