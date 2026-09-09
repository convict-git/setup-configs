local util = require("spr-supercharged.util")

local M = {}

---@class SequenceItem
---@field label string
---@field description string
---@field path string
---@field child SequenceItem?

---@class InputConfig
---@field destination_path string
---@field max_depth_to_explore number
---@field max_nodes_to_explore number
---@field max_sequences_to_explore number

---@param opts table
---@return number
local function get_sequences(opts)
  local starting_hash = opts.starting_hash
  local ending_hash = opts.ending_hash
  local dependency_graph = opts.dependency_graph
  local result = opts.result
  local input_config = opts.input_config

  local node_count = 0
  local queue = { { starting_hash, { starting_hash } } }
  local visited = {}

  local max_depth = input_config.max_depth_to_explore
  local max_nodes = input_config.max_nodes_to_explore
  local max_sequences = input_config.max_sequences_to_explore

  while #queue > 0 and #result < max_sequences and node_count < max_nodes do
    node_count = node_count + 1

    local current = table.remove(queue, 1)
    local current_hash = current[1]
    local current_path = current[2]

    if current_hash == ending_hash then
      result[#result + 1] = current_path
    else
      if #current_path >= max_depth then
        goto continue
      end

      local node = dependency_graph[current_hash]
      local references = node and node[2]

      if references and #references > 0 then
        for _, ref in ipairs(references) do
          local in_path = false
          for _, h in ipairs(current_path) do
            if h == ref then
              in_path = true
              break
            end
          end
          if in_path then
            goto next_ref
          end

          local path_key = ref .. "-" .. current_path[#current_path]
          if visited[path_key] then
            goto next_ref
          end
          visited[path_key] = true

          local new_path = vim.deepcopy(current_path)
          new_path[#new_path + 1] = ref
          queue[#queue + 1] = { ref, new_path }

          ::next_ref::
        end
      end
    end

    ::continue::
  end

  return node_count
end

---@param label string
---@param description string
---@param path string
---@param child SequenceItem?
---@return SequenceItem
local function create_sequence_item(label, description, path, child)
  return {
    label = label,
    description = description,
    path = path,
    child = child,
  }
end

---@param opts table
---@return SequenceItem[]
function M.get_import_sequences(opts)
  local dependency_graph = opts.dependency_graph
  local starting_file_path = opts.starting_file_path
  local ending_file_path = opts.ending_file_path
  local file_vs_hash = opts.file_vs_hash
  local hash_vs_file = opts.hash_vs_file
  local input_config = opts.input_config

  local starting_hash = file_vs_hash[starting_file_path]
  local ending_hash = file_vs_hash[ending_file_path]

  if not starting_hash or not ending_hash then
    return {
      create_sequence_item(
        "File Not Found",
        "This file is not part of the dependency graph.",
        starting_hash and ending_file_path or starting_file_path
      ),
    }
  end

  local start_node = dependency_graph[starting_hash]
  local references = start_node and start_node[2]

  if not references or #references == 0 then
    return {
      create_sequence_item(
        "No References Found",
        "This file has no references.",
        starting_file_path
      ),
    }
  end

  local result = {}
  get_sequences({
    starting_hash = starting_hash,
    ending_hash = ending_hash,
    dependency_graph = dependency_graph,
    result = result,
    input_config = input_config,
  })

  if #result == 0 then
    return {
      create_sequence_item(
        "No Sequence Found",
        "This file has no sequence of imports.",
        starting_file_path
      ),
    }
  end

  local items = {}

  for _, path in ipairs(result) do
    local first_path = hash_vs_file[path[1]]
    local item = create_sequence_item(
      util.basename(first_path),
      util.parent_dir_name(first_path),
      first_path
    )
    items[#items + 1] = item

    local current = item
    for i = 2, #path do
      local file_path = hash_vs_file[path[i]]
      local child = create_sequence_item(
        util.basename(file_path),
        util.parent_dir_name(file_path),
        file_path
      )
      current.child = child
      current = child
    end
  end

  return items
end

return M
