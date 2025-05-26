---@class Brush
---@field name string
---@field bg string?
---@field fg string?

---@class Config
---@field brushes Brush[]
---@field selected_brush Brush

local M = {}

local namespace = vim.api.nvim_create_namespace("paint")

---@type Brush[]
local default_brushes = {
  { name = "Red",    bg = "#ff6b6b" },
  { name = "Blue",   bg = "#4ecdc4" },
  { name = "Green",  bg = "#95e1d3" },
  { name = "Yellow", bg = "#fce38a" },
  { name = "Purple", bg = "#c44569" },
  { name = "Orange", bg = "#f8b500" },
}

---@type Config
local config = {
  brushes = default_brushes,
  selected_brush = default_brushes[1],
}

---@param opts { brushes?: Brush[], extra_brushes?: Brush[] }?
function M.setup(opts)
  opts = opts or {}

  if opts.brushes then
    config.brushes = opts.brushes
  end

  if opts.extra_brushes then
    for _, brush in ipairs(opts.extra_brushes) do
      M.add_brush(brush)
    end
  end

  vim.api.nvim_create_user_command("Paint", function()
    M.paint()
  end, {
    range = true,
    desc = "Paint visual selection with current brush"
  })

  vim.api.nvim_create_user_command("PaintSelect", function()
    M.select_brush()
  end, {
    desc = "Select brush for painting"
  })

  vim.api.nvim_create_user_command("PaintClear", function()
    M.clear()
  end, {
    desc = "Clear painting"
  })
end

--- Select a specific brush, or show selection UI.
---@param brush Brush?
function M.select_brush(brush)
  if brush then
    config.selected_brush = brush
    vim.notify("Selected brush: " .. brush.name, vim.log.levels.INFO)
    return
  end

  ---@type string[]
  local brush_names = {}
  for _, b in ipairs(config.brushes) do
    table.insert(brush_names, b.name)
  end

  vim.ui.select(brush_names, {
    prompt = "Select brush:",
  }, function(choice)
    if not choice then
      return
    end

    for _, b in ipairs(config.brushes) do
      if b.name == choice then
        config.selected_brush = b
        vim.notify("Selected brush: " .. b.name, vim.log.levels.INFO)
        break
      end
    end
  end)
end

---@private
function M.paint()
  local bufnr = vim.api.nvim_get_current_buf()
  local selected_brush = config.selected_brush

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local visual_mode = vim.fn.visualmode()

  local start_row = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_row = end_pos[2] - 1
  local end_col = end_pos[3] - 1

  if visual_mode == 'V' then
    for row = start_row, end_row do
      local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
      M.paint_range(bufnr, row, 0, row, #line, selected_brush)
    end
  elseif visual_mode == '\22' then -- Ctrl-V
    local min_col = math.min(start_col, end_col)
    local max_col = math.max(start_col, end_col) + 1

    for row = start_row, end_row do
      M.paint_range(bufnr, row, min_col, row, max_col, selected_brush)
    end
  else -- visual_mode == 'v' or no visual mode
    if start_row == -1 then
      ---@type integer[]
      local cursor = vim.api.nvim_win_get_cursor(0)
      start_row = cursor[1] - 1
      start_col = cursor[2]
      end_row = start_row
      end_col = start_col
    end
    M.paint_range(bufnr, start_row, start_col, end_row, end_col + 1, selected_brush)
  end
end

---@param bufnr integer
---@param start_row integer
---@param start_col integer
---@param end_row integer
---@param end_col integer
---@param brush Brush
function M.paint_range(bufnr, start_row, start_col, end_row, end_col, brush)
  if brush.name == "Clear" then
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, start_row, end_row + 1)
  else
    local hl_group = "Paint" .. brush.name
    vim.api.nvim_set_hl(0, hl_group, { bg = brush.bg, fg = brush.fg })

    vim.hl.range(bufnr, namespace, hl_group,
      { start_row, start_col },
      { end_row, end_col },
      { inclusive = false })
  end
end

function M.clear()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  vim.notify("Cleared paint", vim.log.levels.INFO)
end

---@param brush Brush
function M.add_brush(brush)
  table.insert(config.brushes, brush)
end

---@return Brush
function M.selected_brush()
  return config.selected_brush
end

---@return Brush[]
function M.brushes()
  return config.brushes
end

return M
