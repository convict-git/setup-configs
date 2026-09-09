local cache = require("spr-supercharged.core.cache")
local references = require("spr-supercharged.query.references")
local tree = require("spr-supercharged.ui.tree")
local util = require("spr-supercharged.util")

local M = {}

function M.run()
  local project_path = util.get_project_path()
  if not project_path then
    util.notify_error("No workspace folder found. Please open a project folder.")
    return
  end

  local file_path = vim.api.nvim_buf_get_name(0)
  if file_path == "" then
    util.notify_error("No active file. Open a file first.")
    return
  end
  file_path = util.normalize(file_path)

  local cache_data = cache.load(project_path)
  if not cache_data.initialized then
    return
  end

  local items = references.get_file_references({
    file_path = file_path,
    dependency_graph = cache_data.dependency_graph,
    file_vs_hash = cache_data.file_vs_hash,
    hash_vs_file = cache_data.hash_vs_file,
  })

  local roots = tree.reference_items_to_nodes(items)

  tree.show("Recursive References", roots, function(node)
    return tree.get_reference_children(node, cache_data, references.get_file_references)
  end)
end

return M
