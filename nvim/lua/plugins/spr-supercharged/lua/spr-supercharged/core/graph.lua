local M = {}

---@alias DependencyGraph table<string, [string[], string[]]>

---@param files string[]
---@param imports table<string, string[]>
---@param file_vs_hash table<string, string>
---@return DependencyGraph
function M.build_dependency_graph(files, imports, file_vs_hash)
  ---@type DependencyGraph
  local graph = {}

  for _, file in ipairs(files) do
    local file_hash = file_vs_hash[file]
    if not file_hash then
      goto continue
    end

    local import_in_file = imports[file_hash] or {}

    for _, dep in ipairs(import_in_file) do
      if graph[dep] then
        if graph[dep][2] then
          graph[dep][2][#graph[dep][2] + 1] = file_hash
        else
          graph[dep] = { graph[dep][1] or {}, { file_hash } }
        end
      else
        graph[dep] = { {}, { file_hash } }
      end
    end

    graph[file_hash] = { import_in_file, graph[file_hash] and graph[file_hash][2] or {} }

    ::continue::
  end

  return graph
end

return M
