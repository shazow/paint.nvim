-- painter.nvim - A simple plugin to paint visual selections with background colors
local M = {}

-- Default brushes (colors)
local default_brushes = {
  { name = "Red", bg = "#ff6b6b" },
  { name = "Blue", bg = "#4ecdc4" },
  { name = "Green", bg = "#95e1d3" },
  { name = "Yellow", bg = "#fce38a" },
  { name = "Purple", bg = "#c44569" },
  { name = "Orange", bg = "#f8b500" },
  { name = "Pink", bg = "#ff9ff3" },
  { name = "Gray", bg = "#95a5a6" },
  { name = "Clear", bg = nil }, -- Special brush to clear highlighting
}

-- Plugin configuration
local config = {
  brushes = default_brushes,
  namespace = vim.api.nvim_create_namespace("painter"),
}

-- Setup function for plugin configuration
function M.setup(opts)
  opts = opts or {}
  
  -- Merge user brushes with defaults
  if opts.brushes then
    config.brushes = opts.brushes
  end
  
  -- Create the Paint command
  vim.api.nvim_create_user_command("Paint", function(args)
    M.paint_selection(args.line1, args.line2)
  end, {
    range = true,
    desc = "Paint visual selection with chosen color"
  })
  
  -- Create PaintClear command to clear all highlighting
  vim.api.nvim_create_user_command("PaintClear", function()
    M.clear_all()
  end, {
    desc = "Clear all painter highlighting"
  })
end

-- Function to paint a selection
function M.paint_selection(line1, line2)
  -- Get current buffer
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Create brush selection options
  local brush_names = {}
  for i, brush in ipairs(config.brushes) do
    table.insert(brush_names, brush.name)
  end
  
  -- Use vim.ui.select to choose a brush
  vim.ui.select(brush_names, {
    prompt = "Choose a brush:",
  }, function(choice)
    if not choice then
      return -- User cancelled
    end
    
    -- Find the selected brush
    local selected_brush = nil
    for _, brush in ipairs(config.brushes) do
      if brush.name == choice then
        selected_brush = brush
        break
      end
    end
    
    if not selected_brush then
      vim.notify("Brush not found: " .. choice, vim.log.levels.ERROR)
      return
    end
    
    -- Get visual selection details
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local mode = vim.fn.visualmode()
    
    -- Convert to 0-based indexing
    local start_row = start_pos[2] - 1
    local start_col = start_pos[3] - 1
    local end_row = end_pos[2] - 1
    local end_col = end_pos[3] - 1
    
    -- Handle different visual modes
    if mode == 'v' then
      -- Character-wise visual mode
      M.paint_range(bufnr, start_row, start_col, end_row, end_col + 1, selected_brush)
    elseif mode == 'V' then
      -- Line-wise visual mode
      for row = start_row, end_row do
        local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
        M.paint_range(bufnr, row, 0, row, #line, selected_brush)
      end
    elseif mode == '\22' then -- Ctrl-V (block visual mode)
      -- Block-wise visual mode
      local min_col = math.min(start_col, end_col)
      local max_col = math.max(start_col, end_col) + 1
      
      for row = start_row, end_row do
        M.paint_range(bufnr, row, min_col, row, max_col, selected_brush)
      end
    else
      -- Fallback: use the line range from the command
      for row = line1 - 1, line2 - 1 do
        local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
        M.paint_range(bufnr, row, 0, row, #line, selected_brush)
      end
    end
  end)
end

-- Function to paint a specific range
function M.paint_range(bufnr, start_row, start_col, end_row, end_col, brush)
  if brush.name == "Clear" then
    -- Clear highlighting in the range
    vim.api.nvim_buf_clear_namespace(bufnr, config.namespace, start_row, end_row + 1)
  else
    -- Create highlight group for this brush if it doesn't exist
    local hl_group = "Painter" .. brush.name
    vim.api.nvim_set_hl(0, hl_group, { bg = brush.bg })
    
    -- Apply highlighting using vim.hl.range
    vim.hl.range(bufnr, config.namespace, hl_group, 
                 { start_row, start_col }, 
                 { end_row, end_col }, 
                 { inclusive = false })
  end
end

-- Function to clear all painter highlighting
function M.clear_all()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, config.namespace, 0, -1)
  vim.notify("Cleared all painter highlighting", vim.log.levels.INFO)
end

-- Function to add custom brushes
function M.add_brush(name, bg_color)
  table.insert(config.brushes, { name = name, bg = bg_color })
end

-- Function to get current brushes
function M.get_brushes()
  return config.brushes
end

return M
