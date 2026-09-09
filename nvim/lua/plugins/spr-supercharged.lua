-- Sprinklr Supercharged: scanProject, showFileReferences, traceImports
-- Port of the VSCode extension for sprinklr-ui-hub monorepos.
return {
  dir = vim.fn.stdpath("config") .. "/lua/plugins/spr-supercharged",
  name = "spr-supercharged",
  cmd = {
    "SprinklrScan",
    "SprinklrReferences",
    "SprinklrTraceImports",
    "SprinklrToggleTree",
  },
  config = function()
    require("spr-supercharged").setup()
  end,
}
