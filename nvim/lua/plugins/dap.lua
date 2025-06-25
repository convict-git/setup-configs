local dap = require("dap")
dap.set_log_level("TRACE")

dap.adapters.codelldb = {
  type = 'executable',
  command = 'codelldb',
}

local module = {}

module.get_configuration_template = function(exe, _args)
  local test_name = (_args[1] or ""):gsub("^['\"]", ""):gsub("['\"]$", "")
  return {
    name = "Debug with codelldb",
    type = "codelldb",
    request = "launch",
    program = exe,
    args = { test_name },
    cwd = vim.fn.getcwd(),
  }
end

return module

-- In case if this breaks, keep this directly in coc-setings.json
-- "rust-analyzer.debug.nvimdap.configuration.template": "{ name = 'Debug with codelldb', type = 'codelldb', request = 'launch', program = $exe, stopOnEntry = true, args = $args, runInTerminal = false, }",
