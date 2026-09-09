local util = require("spr-supercharged.util")

local M = {}

---@class TreeNode
---@field id string
---@field label string
---@field description string
---@field path string
---@field depth integer
---@field expanded boolean
---@field collapsible boolean
---@field children TreeNode[]
---@field data any

local ns = vim.api.nvim_create_namespace("sprinklr_supercharged_tree")

---@class TreeState
---@field bufnr integer
---@field winid integer
---@field prev_winid integer?
---@field roots TreeNode[]
---@field flat TreeNode[]
---@field get_children fun(node: TreeNode): TreeNode[]
---@field title string
---@field title_text string
---@field win_config table
---@field visible boolean
---@field augroup integer?
---@field saved_cursor integer[]?
---@field saved_view table?

local active_state = nil
local TREE_HEIGHT = math.floor(30 * 1.3)

---@return integer width
---@return integer height
local function base_dimensions()
  local width = math.max(20, math.floor(vim.o.columns / 2))
  local height = math.min(TREE_HEIGHT, vim.o.lines - 4)
  return width, height
end

---@param state TreeState
---@return table
local function layout_config(state)
  local width, height = base_dimensions()

  return {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.max(0, vim.o.columns - width - 1),
    style = "minimal",
    border = "rounded",
    title = state.title_text,
    title_pos = "center",
  }
end

---@param state TreeState
local function apply_layout(state)
  if not M.is_visible(state) then
    return
  end

  state.win_config = layout_config(state)
  vim.api.nvim_win_set_config(state.winid, state.win_config)
end

---@param state TreeState
local function setup_autocmds(state)
  state.augroup = vim.api.nvim_create_augroup("SprSuperchargedTree_" .. state.bufnr, { clear = true })

  vim.api.nvim_create_autocmd("VimResized", {
    group = state.augroup,
    callback = function()
      if active_state ~= state or not M.is_visible(state) then
        return
      end
      apply_layout(state)
    end,
  })
end

---@param state TreeState
local function clear_autocmds(state)
  if state.augroup then
    vim.api.nvim_clear_autocmds({ group = state.augroup })
    state.augroup = nil
  end
end

---@param node TreeNode
---@param depth integer
---@param get_children fun(node: TreeNode): TreeNode[]
---@param flat TreeNode[]
---@param id_counter integer
---@return integer
local function flatten_node(node, depth, get_children, flat, id_counter)
  id_counter = id_counter + 1
  node.id = tostring(id_counter)
  node.depth = depth
  flat[#flat + 1] = node

  if node.expanded and node.collapsible then
    local children = get_children(node)
    node.children = children
    for _, child in ipairs(children) do
      id_counter = flatten_node(child, depth + 1, get_children, flat, id_counter)
    end
  end

  return id_counter
end

---@param state TreeState
local function refresh_flat(state)
  state.flat = {}
  local id_counter = 0
  for _, root in ipairs(state.roots) do
    id_counter = flatten_node(root, 0, state.get_children, state.flat, id_counter)
  end
end

---@param state TreeState
local function render(state)
  refresh_flat(state)

  local lines = {}
  for _, node in ipairs(state.flat) do
    local indent = string.rep("  ", node.depth)
    local marker = "  "
    if node.collapsible then
      marker = node.expanded and "▼ " or "▶ "
    end
    local desc = node.description ~= "" and ("  [" .. node.description .. "]") or ""
    lines[#lines + 1] = indent .. marker .. node.label .. desc
  end

  if #lines == 0 then
    lines = { "No results." }
  end

  vim.api.nvim_buf_set_option(state.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.bufnr, "modifiable", false)

  vim.api.nvim_buf_clear_namespace(state.bufnr, ns, 0, -1)

  for i, node in ipairs(state.flat) do
    local line_idx = i - 1
    if node.path and node.path ~= "" then
      local display_path = util.relative_to_root(node.path)
      vim.api.nvim_buf_set_extmark(state.bufnr, ns, line_idx, 0, {
        id = tonumber(node.id) or line_idx,
        virt_text = { { "  " .. display_path, "Comment" } },
        virt_text_pos = "eol",
      })
    end
  end
end

---@param state TreeState
---@param line_nr integer
---@return TreeNode?
local function node_at_line(state, line_nr)
  local idx = line_nr + 1
  return state.flat[idx]
end

---@param state TreeState
---@return integer?
local function main_editor_win(state)
  if state.prev_winid and vim.api.nvim_win_is_valid(state.prev_winid) then
    return state.prev_winid
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= state.winid and vim.api.nvim_win_get_config(win).relative == "" then
      return win
    end
  end

  return nil
end

---@param state TreeState
local function save_view(state)
  if not vim.api.nvim_win_is_valid(state.winid) then
    return
  end

  vim.api.nvim_win_call(state.winid, function()
    state.saved_cursor = vim.api.nvim_win_get_cursor(0)
    state.saved_view = vim.fn.winsaveview()
  end)
end

---@param state TreeState
local function restore_view(state)
  if not vim.api.nvim_win_is_valid(state.winid) then
    return
  end

  vim.api.nvim_win_call(state.winid, function()
    if state.saved_view then
      vim.fn.winrestview(state.saved_view)
    end
    if state.saved_cursor then
      pcall(vim.api.nvim_win_set_cursor, 0, state.saved_cursor)
    end
  end)
end

---@param state TreeState
local function focus_editor(state)
  local target_win = main_editor_win(state)
  if target_win then
    vim.api.nvim_set_current_win(target_win)
  end
end

---@param state TreeState?
---@return boolean
function M.is_visible(state)
  state = state or active_state
  if not state or not state.visible then
    return false
  end
  if not vim.api.nvim_win_is_valid(state.winid) then
    return false
  end
  local cfg = vim.api.nvim_win_get_config(state.winid)
  return cfg.hide ~= true
end

---@return boolean
function M.is_hidden()
  return active_state ~= nil and not M.is_visible(active_state)
end

---@param state TreeState?
---@return boolean
function M.is_focused(state)
  state = state or active_state
  return state ~= nil and M.is_visible(state) and vim.api.nvim_get_current_win() == state.winid
end

---@param state TreeState
local function focus_tree(state)
  if not M.is_visible(state) then
    return
  end

  vim.api.nvim_set_current_win(state.winid)
  restore_view(state)
end

---@param state TreeState
function M.hide(state)
  if not M.is_visible(state) then
    return
  end

  save_view(state)

  if vim.api.nvim_win_hide then
    vim.api.nvim_win_hide(state.winid)
  else
    vim.api.nvim_win_close(state.winid, false)
    state.winid = -1
  end

  state.visible = false
  focus_editor(state)
end

---@param state TreeState
function M.reveal(state)
  if M.is_visible(state) then
    focus_tree(state)
    return
  end

  if not vim.api.nvim_buf_is_valid(state.bufnr) then
    active_state = nil
    return
  end

  if vim.api.nvim_win_hide and vim.api.nvim_win_is_valid(state.winid) then
    vim.api.nvim_win_show(state.winid, true)
  else
    state.win_config = layout_config(state)
    state.winid = vim.api.nvim_open_win(state.bufnr, true, state.win_config)
    setup_keymaps(state)
    setup_autocmds(state)
  end

  state.visible = true
  focus_tree(state)
end

---@param state TreeState?
function M.close(state)
  state = state or active_state
  if not state then
    return
  end

  clear_autocmds(state)

  if vim.api.nvim_win_is_valid(state.winid) then
    vim.api.nvim_win_close(state.winid, true)
  end

  if vim.api.nvim_buf_is_valid(state.bufnr) then
    vim.api.nvim_buf_delete(state.bufnr, { force = true })
  end

  if active_state == state then
    active_state = nil
  end
end

---@return boolean
function M.toggle()
  if not active_state then
    util.notify("No active Sprinklr tree. Run :SprinklrReferences or :SprinklrTraceImports first.")
    return false
  end

  if M.is_hidden() then
    M.reveal(active_state)
    return true
  end

  if M.is_focused(active_state) then
    M.hide(active_state)
  else
    focus_tree(active_state)
  end

  return true
end

---@param state TreeState
local function open_file(state, node)
  if not node or node.path == "" then
    return
  end

  focus_editor(state)
  vim.cmd("edit " .. vim.fn.fnameescape(node.path))
end

---@param state TreeState
function setup_keymaps(state)
  local opts = { buffer = state.bufnr, silent = true }

  vim.keymap.set("n", "<CR>", function()
    local node = node_at_line(state, vim.api.nvim_win_get_cursor(state.winid)[1] - 1)
    if not node then
      return
    end
    if node.collapsible then
      node.expanded = not node.expanded
      render(state)
      save_view(state)
    else
      open_file(state, node)
    end
  end, opts)

  vim.keymap.set("n", "o", function()
    local node = node_at_line(state, vim.api.nvim_win_get_cursor(state.winid)[1] - 1)
    open_file(state, node)
  end, opts)

  vim.keymap.set("n", "l", function()
    local node = node_at_line(state, vim.api.nvim_win_get_cursor(state.winid)[1] - 1)
    if node and node.collapsible then
      node.expanded = true
      render(state)
      save_view(state)
    end
  end, opts)

  vim.keymap.set("n", "h", function()
    local node = node_at_line(state, vim.api.nvim_win_get_cursor(state.winid)[1] - 1)
    if node and node.collapsible and node.expanded then
      node.expanded = false
      render(state)
      save_view(state)
    end
  end, opts)

  vim.keymap.set("n", "q", function()
    M.hide(state)
  end, opts)

  vim.keymap.set("n", "<Esc>", function()
    M.hide(state)
  end, opts)

  vim.keymap.set("n", "Q", function()
    M.close(state)
  end, opts)
end

---@param title string
---@param roots TreeNode[]
---@param get_children fun(node: TreeNode): TreeNode[]
function M.show(title, roots, get_children)
  if active_state then
    M.close(active_state)
  end

  local title_text = " " .. title .. " "
  local prev_winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_create_buf(false, true)

  ---@type TreeState
  local state = {
    bufnr = bufnr,
    winid = -1,
    prev_winid = prev_winid,
    roots = roots,
    flat = {},
    get_children = get_children,
    title = title,
    title_text = title_text,
    win_config = {},
    visible = true,
  }

  state.win_config = layout_config(state)
  local winid = vim.api.nvim_open_win(bufnr, true, state.win_config)

  vim.api.nvim_buf_set_name(bufnr, "spr-supercharged://" .. title:gsub("%s+", "-"):lower())
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(bufnr, "filetype", "spr-supercharged-tree")
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  state.winid = winid

  for _, root in ipairs(roots) do
    root.expanded = root.expanded == nil and root.collapsible or root.expanded
    root.children = {}
  end

  active_state = state
  setup_keymaps(state)
  setup_autocmds(state)
  render(state)
end

---@param items table[]
---@return TreeNode[]
function M.reference_items_to_nodes(items)
  local nodes = {}
  for _, item in ipairs(items) do
    nodes[#nodes + 1] = {
      id = "",
      label = item.label,
      description = item.description or "",
      path = item.path or "",
      depth = 0,
      expanded = false,
      collapsible = item.collapsible or false,
      children = {},
      data = item,
    }
  end
  return nodes
end

---@param items table[]
---@return TreeNode[]
function M.sequence_items_to_nodes(items)
  local nodes = {}

  local function walk(item)
    local node = {
      id = "",
      label = item.label,
      description = item.description or "",
      path = item.path or "",
      depth = 0,
      expanded = item.child ~= nil,
      collapsible = item.child ~= nil,
      children = {},
      data = item,
    }

    if item.child then
      node.children = { walk(item.child) }
    end

    return node
  end

  for _, item in ipairs(items) do
    nodes[#nodes + 1] = walk(item)
  end

  return nodes
end

---@param node TreeNode
---@param cache_data table
---@param get_refs fun(opts: table): table[]
---@return TreeNode[]
function M.get_reference_children(node, cache_data, get_refs)
  if node.children and #node.children > 0 and node.expanded then
    return node.children
  end

  if not node.path or node.path == "" then
    return {}
  end

  local refs = get_refs({
    file_path = node.path,
    dependency_graph = cache_data.dependency_graph,
    file_vs_hash = cache_data.file_vs_hash,
    hash_vs_file = cache_data.hash_vs_file,
  })

  return M.reference_items_to_nodes(refs)
end

---@param node TreeNode
---@return TreeNode[]
function M.get_sequence_children(node)
  if node.children and #node.children > 0 then
    return node.children
  end
  return {}
end

return M
