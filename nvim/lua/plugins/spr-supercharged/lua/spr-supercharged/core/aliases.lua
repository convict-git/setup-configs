local util = require("spr-supercharged.util")

local M = {}

-- Order matters: more specific prefixes must come before shorter ones.
M.workspace_starts_with = {
  "@sprinklrjs/legacy-base/lib",
  "@sprinklrjs/legacy-space/lib",
  "@sprinklrjs/modules",
  "@sprinklrjs/hyperspace",
  "@sprinklrjs/core-lib",
  "@spr-main-web/i18n",
  "@spr-main-web",
  "mf-social-internal",
  "mf-social",
  "mf-cxm-internal",
  "mf-cxm",
  "mf-insights-internal",
  "mf-insights",
  "mf-care-internal",
  "mf-care",
  "mf-ads-internal",
  "mf-ads",
  "mf-entity-studio-internal",
  "mf-entity-studio",
  "mf-cfm-internal",
  "mf-cfm",
  "mf-advocacy-internal",
  "mf-advocacy",
  "mf-marketing-internal",
  "mf-marketing",
  "mf-wfm-internal",
  "mf-wfm",
  "mf-ai-internal",
  "mf-ai",
  "mf-integrations-internal",
  "mf-integrations",
  "mf-screenrecorder-internal",
  "mf-screenrecorder",
  "packages-modules-exception",
  "spr-main-web-exception",
}

M.workspace_replace = {
  ["@sprinklrjs/legacy-base/lib"] = { "packages", "spr-base", "src" },
  ["@sprinklrjs/legacy-space/lib"] = { "packages", "spr-space", "src" },
  ["@sprinklrjs/modules"] = { "packages", "modules", "src" },
  ["@sprinklrjs/hyperspace"] = { "packages", "hyperspace", "src" },
  ["@sprinklrjs/core-lib"] = { "packages", "core-lib", "src" },
  ["@spr-main-web/i18n"] = { "apps", "spr-main-web", "i18n" },
  ["@spr-main-web"] = { "apps", "spr-main-web", "src" },
  ["mf-social-internal"] = { "microfrontends", "social", "src" },
  ["mf-social"] = { "microfrontends", "social", "mf-exports" },
  ["mf-cxm-internal"] = { "microfrontends", "cxm", "src" },
  ["mf-cxm"] = { "microfrontends", "cxm", "mf-exports" },
  ["mf-insights-internal"] = { "microfrontends", "insights", "src" },
  ["mf-insights"] = { "microfrontends", "insights", "mf-exports" },
  ["mf-care-internal"] = { "microfrontends", "care", "src" },
  ["mf-care"] = { "microfrontends", "care", "mf-exports" },
  ["mf-ads-internal"] = { "microfrontends", "ads", "src" },
  ["mf-ads"] = { "microfrontends", "ads", "mf-exports" },
  ["mf-entity-studio-internal"] = { "microfrontends", "entity-studio", "src" },
  ["mf-entity-studio"] = { "microfrontends", "entity-studio", "mf-exports" },
  ["mf-cfm-internal"] = { "microfrontends", "cfm", "src" },
  ["mf-cfm"] = { "microfrontends", "cfm", "mf-exports" },
  ["mf-advocacy-internal"] = { "microfrontends", "advocacy", "src" },
  ["mf-advocacy"] = { "microfrontends", "advocacy", "mf-exports" },
  ["mf-marketing-internal"] = { "microfrontends", "marketing", "src" },
  ["mf-marketing"] = { "microfrontends", "marketing", "mf-exports" },
  ["mf-wfm-internal"] = { "microfrontends", "wfm", "src" },
  ["mf-wfm"] = { "microfrontends", "wfm", "mf-exports" },
  ["mf-ai-internal"] = { "microfrontends", "ai", "src" },
  ["mf-ai"] = { "microfrontends", "ai", "mf-exports" },
  ["mf-integrations-internal"] = { "microfrontends", "integrations", "src" },
  ["mf-integrations"] = { "microfrontends", "integrations", "mf-exports" },
  ["mf-screenrecorder-internal"] = { "microfrontends", "screenrecorder", "src" },
  ["mf-screenrecorder"] = { "microfrontends", "screenrecorder", "mf-exports" },
  ["packages-modules-exception"] = { "packages", "modules", "src" },
  ["spr-main-web-exception"] = { "apps", "spr-main-web" },
}

---@param path string
---@param file_vs_hash table<string, string>
---@param extensions string[]
---@return string
local function get_path_with_extension(path, file_vs_hash, extensions)
  for _, ext in ipairs(extensions) do
    local with_ext = path .. ext
    if file_vs_hash[with_ext] then
      return file_vs_hash[with_ext]
    end
    local index_path = path .. "/index" .. ext
    if file_vs_hash[index_path] then
      return file_vs_hash[index_path]
    end
  end
  return ""
end

---@param path_to_resolve string
---@param file_path string
---@param file_vs_hash table<string, string>
---@param project_path string
---@param extensions string[]
---@return string
function M.resolve_alias_path(path_to_resolve, file_path, file_vs_hash, project_path, extensions)
  if path_to_resolve:sub(1, 1) == "." then
    local joined_path = util.resolve(file_path, path_to_resolve)
    return get_path_with_extension(joined_path, file_vs_hash, extensions)
  end

  for _, workspace in ipairs(M.workspace_starts_with) do
    if path_to_resolve:sub(1, #workspace) == workspace then
      local replace = M.workspace_replace[workspace]
      if replace then
        local suffix = path_to_resolve:sub(#workspace + 1)
        local tokens = { project_path }
        for _, token in ipairs(replace) do
          tokens[#tokens + 1] = token
        end
        local joined_path = util.join(tokens) .. suffix
        return get_path_with_extension(joined_path, file_vs_hash, extensions)
      end
    end
  end

  if path_to_resolve:sub(1, 2) == "@/" then
    local tokens = vim.split(file_path, "/")
    local apps_token = nil
    for i, tok in ipairs(tokens) do
      if tok == "apps" then
        apps_token = i
        break
      end
    end
    if not apps_token then
      return ""
    end

    local joined_path = util.join(
      project_path,
      tokens[apps_token],
      tokens[apps_token + 1],
      path_to_resolve:gsub("^@/", "./")
    )
    return get_path_with_extension(joined_path, file_vs_hash, extensions)
  end

  return ""
end

return M
