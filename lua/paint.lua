local M = {}

-- Default brushes (colors)
local default_brushes = {
  { name = "Red",    bg = "#ff6b6b" },
  { name = "Blue",   bg = "#4ecdc4" },
  { name = "Green",  bg = "#95e1d3" },
  { name = "Yellow", bg = "#fce38a" },
  { name = "Purple", bg = "#c44569" },
  { name = "Orange", bg = "#f8b500" },
  { name = "Pink",   bg = "#ff9ff3" },
  { name = "Gray",   bg = "#95a5a6" },
  { name = "Clear",  bg = nil }, -- Special brush to clear highlighting
}

-- Plugin configuration
local config = {
  brushes = default_brushes,
  namespace = vim.api.nvim_create_namespace("paint"),
  current_brush = default_brushes[1], -- Default to first brush (Red)
}

-- Setup function for plugin configuration
function M.setup(opts)
  opts = opts or {}

  -- Merge user brushes with defaults
  if opts.brushes then
    config.brushes = opts.brushes
  end

  vim.api.nvim_create_user_command("Paint", function(args)
    M.paint_selection()
  end, {
    range = true,
    desc = "Paint visual selection with current brush"
  })

  vim.api.nvim_create_user_command("PaintSelect", function()
    M.select_brush()
  end, {
    desc = "Select current brush for painting"
  })

  vim.api.nvim_create_user_command("PaintClear", function()
    M.clear()
  end, {
    desc = "Clear painting"
  })
end

function M.select_brush()
  -- Create brush selection options
  local brush_names = {}
  for i, brush in ipairs(config.brushes) do
    table.insert(brush_names, brush.name)
  end

  -- Use vim.ui.select to choose a brush
  vim.ui.select(brush_names, {
    prompt = "Select brush:",
  }, function(choice)
    if not choice then
      return -- User cancelled
    end

    -- Find the selected brush
    for _, brush in ipairs(config.brushes) do
      if brush.name == choice then
        config.current_brush = brush
        vim.notify("Selected brush: " .. brush.name, vim.log.levels.INFO)
        break
      end
    end
  end)
end

-- Function to paint a selection or cursor position
function M.paint_selection()
  -- Get current buffer
  local bufnr = vim.api.nvim_get_current_buf()

  -- Use the current brush directly
  local selected_brush = config.current_brush

  -- We have a visual selection, handle different modes
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local visual_mode = vim.fn.visualmode()

  -- Convert to 0-based indexing
  local start_row = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_row = end_pos[2] - 1
  local end_col = end_pos[3] - 1

  -- Handle different visual modes
  if visual_mode == 'V' then
    -- Line-wise visual mode
    for row = start_row, end_row do
      local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
      M.paint_range(bufnr, row, 0, row, #line, selected_brush)
    end
  elseif visual_mode == '\22' then -- Ctrl-V (block visual mode)
    -- Block-wise visual mode
    local min_col = math.min(start_col, end_col)
    local max_col = math.max(start_col, end_col) + 1

    for row = start_row, end_row do
      M.paint_range(bufnr, row, min_col, row, max_col, selected_brush)
    end
  else -- visual_mode == 'v'
    -- Character-wise visual mode
    if start_row == -1 then
      -- Nothing selected, just use the cursor position
      local cursor = vim.api.nvim_win_get_cursor(0)
      start_row = cursor[1] - 1
      start_col = cursor[2]
      end_row = start_row
      end_col = start_col
    end
    M.paint_range(bufnr, start_row, start_col, end_row, end_col + 1, selected_brush)
  end
end

-- Function to paint a specific range
function M.paint_range(bufnr, start_row, start_col, end_row, end_col, brush)
  if brush.name == "Clear" then
    -- Clear highlighting in the range
    vim.api.nvim_buf_clear_namespace(bufnr, config.namespace, start_row, end_row + 1)
  else
    -- Create highlight group for this brush if it doesn't exist
    local hl_group = "Paint" .. brush.name
    vim.api.nvim_set_hl(0, hl_group, { bg = brush.bg })

    -- Apply highlighting using vim.hl.range
    vim.hl.range(bufnr, config.namespace, hl_group,
      { start_row, start_col },
      { end_row, end_col },
      { inclusive = false })
  end
end

function M.clear()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, config.namespace, 0, -1)
  vim.notify("Cleared paint", vim.log.levels.INFO)
end

function M.add_brush(name, bg_color)
  table.insert(config.brushes, { name = name, bg = bg_color })
end

function M.get_current_brush()
  return config.current_brush
end

function M.get_brushes()
  return config.brushes
end

return M
