local cache = require("spr-supercharged.core.cache")
local sequences = require("spr-supercharged.query.sequences")
local input = require("spr-supercharged.ui.input")
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

  input.get_trace_inputs(function(input_config)
    if not input_config then
      return
    end

    local cache_data = cache.load(project_path)
    if not cache_data.initialized then
      return
    end

    util.notify("Finding import hierarchy...")

    local items = sequences.get_import_sequences({
      dependency_graph = cache_data.dependency_graph,
      file_vs_hash = cache_data.file_vs_hash,
      hash_vs_file = cache_data.hash_vs_file,
      starting_file_path = input_config.destination_path,
      ending_file_path = file_path,
      input_config = input_config,
    })

    local roots = tree.sequence_items_to_nodes(items)

    tree.show("Import Hierarchy", roots, tree.get_sequence_children)
  end)
end

return M
