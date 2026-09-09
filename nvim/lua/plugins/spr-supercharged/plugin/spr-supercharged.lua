if vim.g.loaded_spr_supercharged then
  return
end
vim.g.loaded_spr_supercharged = true

vim.api.nvim_create_user_command("SprinklrScan", function()
  require("spr-supercharged").scan()
end, { desc = "Scan project and build import dependency index" })

vim.api.nvim_create_user_command("SprinklrReferences", function()
  require("spr-supercharged").references()
end, { desc = "Show recursive file references for current buffer" })

vim.api.nvim_create_user_command("SprinklrTraceImports", function()
  require("spr-supercharged").trace_imports()
end, { desc = "Find import hierarchy from target file to current buffer" })

vim.api.nvim_create_user_command("SprinklrToggleTree", function()
  require("spr-supercharged").toggle_tree()
end, { desc = "Focus or hide the Sprinklr references/hierarchy tree" })
