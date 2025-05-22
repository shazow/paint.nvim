-- Sonnet 4 prompt:
-- > Write me a simple nvim lua plugin for "painting" the background of selected visual blocks in red
-- ...
-- > That's great. Let's make the following changes:
-- > 1. Rename it to "Painter" or painter.nvim
-- > 2. Add support for painting the character under the cursor if not in visual selection mode.
-- > 3. Add a command to select different brushes (colours)

-- Neovim plugin for painting text with different colored brushes

local M = {}

-- Namespace for our highlights
local ns_id = vim.api.nvim_create_namespace('painter')

-- Storage for painted regions
local painted_regions = {}

-- Current brush (color)
local current_brush = 'red'

-- Available brushes with their colors
local brushes = {
  red = { bg = '#ff4444', fg = '#ffffff' },
  blue = { bg = '#4444ff', fg = '#ffffff' },
  green = { bg = '#44ff44', fg = '#000000' },
  yellow = { bg = '#ffff44', fg = '#000000' },
  purple = { bg = '#ff44ff', fg = '#ffffff' },
  cyan = { bg = '#44ffff', fg = '#000000' },
  orange = { bg = '#ff8844', fg = '#ffffff' },
  pink = { bg = '#ff88cc', fg = '#ffffff' },
  gray = { bg = '#888888', fg = '#ffffff' },
  white = { bg = '#ffffff', fg = '#000000' }
}

-- Create highlight groups for all brushes
local function setup_highlights()
  for brush_name, colors in pairs(brushes) do
    local hl_name = 'Painter' .. brush_name:gsub("^%l", string.upper)
    vim.api.nvim_set_hl(0, hl_name, colors)
  end
end

-- Get current highlight group name
local function get_current_hl_group()
  return 'Painter' .. current_brush:gsub("^%l", string.upper)
end

-- Get visual selection range
local function get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  return {
    start_line = start_pos[2] - 1, -- Convert to 0-indexed
    start_col = start_pos[3] - 1,
    end_line = end_pos[2] - 1,
    end_col = end_pos[3]
  }
end

-- Get cursor position for single character painting
local function get_cursor_position()
  local pos = vim.api.nvim_win_get_cursor(0)
  return {
    start_line = pos[1] - 1, -- Convert to 0-indexed
    start_col = pos[2],
    end_line = pos[1] - 1,
    end_col = pos[2] + 1
  }
end

-- Paint a given selection/position
local function paint_region(selection, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Store the painted region
  table.insert(painted_regions, {
    bufnr = bufnr,
    start_line = selection.start_line,
    start_col = selection.start_col,
    end_line = selection.end_line,
    end_col = selection.end_col,
    brush = current_brush
  })

  local hl_group = get_current_hl_group()

  -- Apply highlight
  if selection.start_line == selection.end_line then
    -- Single line selection
    vim.api.nvim_buf_add_highlight(
      bufnr,
      ns_id,
      hl_group,
      selection.start_line,
      selection.start_col,
      selection.end_col
    )
  else
    -- Multi-line selection
    -- First line
    vim.api.nvim_buf_add_highlight(
      bufnr,
      ns_id,
      hl_group,
      selection.start_line,
      selection.start_col,
      -1
    )

    -- Middle lines
    for line = selection.start_line + 1, selection.end_line - 1 do
      vim.api.nvim_buf_add_highlight(
        bufnr,
        ns_id,
        hl_group,
        line,
        0,
        -1
      )
    end

    -- Last line
    vim.api.nvim_buf_add_highlight(
      bufnr,
      ns_id,
      hl_group,
      selection.end_line,
      0,
      selection.end_col
    )
  end
end

-- Paint the current visual selection or character under cursor
function M.paint()
  local mode = vim.fn.mode()
  local selection

  if mode == 'v' or mode == 'V' or mode == '\22' then -- \22 is Ctrl-V
    -- Visual mode - paint selection
    selection = get_visual_selection()
    print("Painted selection with " .. current_brush .. " brush!")
  else
    -- Normal mode - paint character under cursor
    selection = get_cursor_position()
    print("Painted character with " .. current_brush .. " brush!")
  end

  paint_region(selection)
end

-- Set the current brush
function M.set_brush(brush_name)
  if not brush_name or brush_name == '' then
    -- Show available brushes
    local available = vim.tbl_keys(brushes)
    table.sort(available)
    print("Available brushes: " .. table.concat(available, ", "))
    print("Current brush: " .. current_brush)
    return
  end

  brush_name = brush_name:lower()
  if brushes[brush_name] then
    current_brush = brush_name
    print("Switched to " .. brush_name .. " brush!")
  else
    local available = vim.tbl_keys(brushes)
    table.sort(available)
    print("Unknown brush: " .. brush_name)
    print("Available brushes: " .. table.concat(available, ", "))
  end
end

-- Get current brush
function M.get_brush()
  return current_brush
end

-- Add a new custom brush
function M.add_brush(name, bg_color, fg_color)
  if not name or not bg_color then
    print("Usage: add_brush(name, bg_color, [fg_color])")
    return
  end

  name = name:lower()
  fg_color = fg_color or '#ffffff'

  brushes[name] = { bg = bg_color, fg = fg_color }

  -- Create highlight group
  local hl_name = 'Painter' .. name:gsub("^%l", string.upper)
  vim.api.nvim_set_hl(0, hl_name, { bg = bg_color, fg = fg_color })

  print("Added " .. name .. " brush!")
end

-- Clear all painted regions in current buffer
function M.clear_paint()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  -- Remove from storage
  painted_regions = vim.tbl_filter(function(region)
    return region.bufnr ~= bufnr
  end, painted_regions)

  print("Cleared all paint!")
end

-- Clear all painted regions in all buffers
function M.clear_all_paint()
  for _, region in ipairs(painted_regions) do
    vim.api.nvim_buf_clear_namespace(region.bufnr, ns_id, 0, -1)
  end
  painted_regions = {}
  print("Cleared all paint in all buffers!")
end

-- List all painted regions
function M.list_paint()
  if #painted_regions == 0 then
    print("No painted regions found.")
    return
  end

  print("Painted regions:")
  for i, region in ipairs(painted_regions) do
    local buf_name = vim.api.nvim_buf_get_name(region.bufnr)
    if buf_name == '' then
      buf_name = '[No Name]'
    else
      buf_name = vim.fn.fnamemodify(buf_name, ':t')
    end

    print(string.format("  %d. %s:%d:%d-%d:%d (%s)",
      i, buf_name,
      region.start_line + 1, region.start_col + 1,
      region.end_line + 1, region.end_col,
      region.brush))
  end
end

-- Setup function
function M.setup(opts)
  opts = opts or {}

  -- Allow custom brushes in setup
  if opts.brushes then
    for name, colors in pairs(opts.brushes) do
      brushes[name:lower()] = colors
    end
  end

  -- Allow setting default brush
  if opts.default_brush and brushes[opts.default_brush:lower()] then
    current_brush = opts.default_brush:lower()
  end

  -- Setup highlight groups
  setup_highlights()

  -- Create user commands
  vim.api.nvim_create_user_command('Paint', M.paint, {
    desc = 'Paint the current visual selection or character under cursor'
  })

  vim.api.nvim_create_user_command('PaintBrush', function(args)
    M.set_brush(args.args)
  end, {
    nargs = '?',
    complete = function()
      local available = vim.tbl_keys(brushes)
      table.sort(available)
      return available
    end,
    desc = 'Set or show the current brush'
  })

  vim.api.nvim_create_user_command('PaintClear', M.clear_paint, {
    desc = 'Clear all painted regions in current buffer'
  })

  vim.api.nvim_create_user_command('PaintClearAll', M.clear_all_paint, {
    desc = 'Clear all painted regions in all buffers'
  })

  vim.api.nvim_create_user_command('PaintList', M.list_paint, {
    desc = 'List all painted regions'
  })

  vim.api.nvim_create_user_command('PaintAddBrush', function(args)
    local parts = vim.split(args.args, '%s+')
    if #parts >= 2 then
      M.add_brush(parts[1], parts[2], parts[3])
    else
      print("Usage: PaintAddBrush <name> <bg_color> [fg_color]")
    end
  end, {
    nargs = '+',
    desc = 'Add a custom brush'
  })

  -- Default keymaps (can be overridden by user)
  local keymap_opts = { noremap = true, silent = true }

  -- Paint in both visual and normal mode
  vim.keymap.set({ 'n', 'v' }, '<leader>pp', M.paint,
    vim.tbl_extend('force', keymap_opts, { desc = 'Paint selection/character' }))

  -- Brush selection
  vim.keymap.set('n', '<leader>pb', function()
    vim.ui.select(vim.tbl_keys(brushes), {
      prompt = 'Select brush:',
      format_item = function(item)
        return item .. (item == current_brush and ' (current)' or '')
      end,
    }, function(choice)
      if choice then
        M.set_brush(choice)
      end
    end)
  end, vim.tbl_extend('force', keymap_opts, { desc = 'Select brush' }))

  -- Clear commands
  vim.keymap.set('n', '<leader>pc', M.clear_paint,
    vim.tbl_extend('force', keymap_opts, { desc = 'Clear paint in buffer' }))

  vim.keymap.set('n', '<leader>pC', M.clear_all_paint,
    vim.tbl_extend('force', keymap_opts, { desc = 'Clear all paint' }))

  -- List painted regions
  vim.keymap.set('n', '<leader>pl', M.list_paint,
    vim.tbl_extend('force', keymap_opts, { desc = 'List painted regions' }))

  print("Painter.nvim loaded! Current brush: " .. current_brush)
end

return M
