local M = {}

M.defaults = {
  -- Directories to scan (relative to project root). Matches VSCode extension.
  directories = {
    "./apps/spr-main-web",
    "./apps/distributed-app",
    "./apps/forms-app",
    "./apps/integrations-app",
    "./apps/external-app",
    "./apps/self-serve-app",
    "./apps/surveys-app",
    "./microfrontends/ads",
    "./microfrontends/advocacy",
    "./microfrontends/ai",
    "./microfrontends/care",
    "./microfrontends/cfm",
    "./microfrontends/cxm",
    "./microfrontends/entity-studio",
    "./microfrontends/insights",
    "./microfrontends/integrations",
    "./microfrontends/marketing",
    "./microfrontends/screenrecorder",
    "./microfrontends/social",
    "./microfrontends/wfm",
    "./packages/modules",
    "./packages/hyperspace",
    "./packages/core-lib",
    "./packages/spr-dynamic-form/src",
    "./packages/spr-validation-schema/src",
    "./packages/next-infra/src",
    "./packages/keyboard-shortcuts/src",
    "./packages/public-assets",
    "./packages/spr-base/src",
    "./packages/spr-space/src",
    "./packages/channel-template-previews",
  },

  -- Cache directory relative to project root.
  cache_dir = ".nvim",

  -- Directories to skip during file discovery.
  skip_dirs = { "node_modules", ".next", "dist" },

  -- File extensions to index.
  extensions = { ".js", ".ts", ".jsx", ".tsx" },

  -- Trace import search modes (matches VSCode quick pick options).
  trace_modes = {
    quick = {
      max_nodes_to_explore = 300000,
      max_depth_to_explore = 20,
      max_sequences_to_explore = 3,
    },
    moderate = {
      max_nodes_to_explore = 500000,
      max_depth_to_explore = 30,
      max_sequences_to_explore = 5,
    },
    exhaustive = {
      max_nodes_to_explore = 1000000,
      max_depth_to_explore = 40,
      max_sequences_to_explore = 10,
    },
  },

  default_trace_mode = "quick",
}

---@param opts table?
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

---@return table
function M.get()
  if not M.options then
    M.setup()
  end
  return M.options
end

return M
