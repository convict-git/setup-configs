local config = require("spr-supercharged.config")

local M = {}

---@param opts table?
function M.setup(opts)
  config.setup(opts)
end

function M.scan()
  require("spr-supercharged.commands.scan").run()
end

function M.references()
  require("spr-supercharged.commands.references").run()
end

function M.trace_imports()
  require("spr-supercharged.commands.trace_imports").run()
end

function M.toggle_tree()
  return require("spr-supercharged.ui.tree").toggle()
end

return M
