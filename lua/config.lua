-- ~/.config/nvim/lua/paint/config.lua
-- Handles plugin configuration and stores brush definitions.

local M = {}

-- Default configuration
M.config = {
  brushes = {
    { name = "Red BG", bg = "#FF8080" },
    { name = "Green BG", bg = "#80FF80" },
    { name = "Blue BG", bg = "#8080FF" },
    { name = "Yellow BG", bg = "#FFFF80" },
    { name = "Cyan BG", bg = "#80FFFF" },
    { name = "Magenta BG", bg = "#FF80FF" },
    { name = "Black FG", fg = "#000000" },
    { name = "White FG", fg = "#FFFFFF" },
  },
  default_brush_name = "Red BG", -- Name of the brush to be active by default
  highlight_mode = "replace", -- "replace", "combine", "blend"
}

-- Runtime state
M.state = {
  current_brush_obj = nil,
  ns_id = nil,
}

function M.setup(user_config)
  user_config = user_config or {}
  M.config = vim.tbl_deep_extend("force", M.config, user_config)

  local valid_brushes = {}
  for _, brush in ipairs(M.config.brushes) do
    if brush.name and (brush.fg or brush.bg) then
      table.insert(valid_brushes, brush)
    else
      vim.notify("Paint: Invalid brush definition skipped: " .. vim.inspect(brush), vim.log.levels.WARN)
    end
  end
  M.config.brushes = valid_brushes

  M.state.ns_id = vim.api.nvim_create_namespace("paint_nvim")

  if not M.set_current_brush_by_name(M.config.default_brush_name) then
    if #M.config.brushes > 0 then
      M.set_current_brush_by_name(M.config.brushes[1].name)
    else
      vim.notify("Paint: No valid brushes configured.", vim.log.levels.ERROR)
    end
  end

  vim.notify("Paint plugin loaded. Current brush: " .. (M.state.current_brush_obj and M.state.current_brush_obj.name or "None"))
end

function M.get_brush_by_name(name)
  for _, brush in ipairs(M.config.brushes) do
    if brush.name == name then
      return brush
    end
  end
  return nil
end

function M.set_current_brush_by_name(name)
  local brush = M.get_brush_by_name(name)
  if brush then
    M.state.current_brush_obj = brush
    return true
  else
    vim.notify("Paint: Brush '" .. name .. "' not found.", vim.log.levels.WARN)
    return false
  end
end

return M
