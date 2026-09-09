local M = {}

local NOTIFICATION_ID = "spr-supercharged-scan-progress"
local BAR_WIDTH = 24

local active_title = "Sprinklr Scan"

---@param percent number
---@return string
function M.bar(percent)
  local clamped = math.max(0, math.min(100, math.floor(percent)))
  local filled = math.floor(BAR_WIDTH * clamped / 100)
  return "[" .. string.rep("=", filled) .. string.rep("-", BAR_WIDTH - filled) .. "]"
end

---@param title string
function M.start(title)
  active_title = title
  M.update(0, "Starting...")
end

---@param percent number
---@param message string?
---@param title string?
function M.update(percent, message, title)
  title = title or active_title
  active_title = title

  local clamped = math.max(0, math.min(100, math.floor(percent)))
  local body = string.format("%s %3d%%", M.bar(clamped), clamped)
  if message and message ~= "" then
    body = body .. "  " .. message
  end

  vim.notify(body, vim.log.levels.INFO, {
    title = title,
    id = NOTIFICATION_ID,
    replace = true,
  })
  pcall(vim.cmd, "redraw")
end

---@param message string?
function M.finish(message)
  M.update(100, message or "Done")
  active_title = "Sprinklr Scan"
end

return M
