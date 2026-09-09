local config = require("spr-supercharged.config")
local util = require("spr-supercharged.util")

local M = {}

---@class InputConfig
---@field destination_path string
---@field max_depth_to_explore number
---@field max_nodes_to_explore number
---@field max_sequences_to_explore number

---@param callback fun(config: InputConfig?)
function M.get_trace_inputs(callback)
  vim.ui.input({
    prompt = "Target file path: ",
    default = "",
  }, function(destination_path)
    if not destination_path or destination_path == "" then
      callback(nil)
      return
    end

    local mode_options = {
      "Quick",
      "Moderate",
      "Exhaustive",
    }

    vim.ui.select(mode_options, {
      prompt = "Select search mode:",
    }, function(choice)
      if not choice then
        callback(nil)
        return
      end

      local mode_key = choice:lower()
      local opts = config.get()
      local mode_values = opts.trace_modes[mode_key] or opts.trace_modes[opts.default_trace_mode]

      local project_path = util.get_project_path()
      local rel = destination_path:gsub("^%./", "")
      local resolved_path = project_path
        and util.normalize(util.join(project_path, rel))
        or destination_path

      callback({
        destination_path = resolved_path,
        max_depth_to_explore = mode_values.max_depth_to_explore,
        max_nodes_to_explore = mode_values.max_nodes_to_explore,
        max_sequences_to_explore = mode_values.max_sequences_to_explore,
      })
    end)
  end)
end

return M
