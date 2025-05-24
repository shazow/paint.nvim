-- painter.nvim
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
--
-- Get current highlight group name
local function get_current_hl_group()
  return 'Painter' .. current_brush:gsub("^%l", string.upper)
end

-- Create highlight groups for all brushes
local function setup_highlights()
  for brush_name, colors in pairs(brushes) do
    local hl_name = 'Painter' .. brush_name:gsub("^%l", string.upper)
    vim.api.nvim_set_hl(0, hl_name, colors)
  end
end

-- Convert virtual column to actual column for a given line
local function vcol_to_col(bufnr, line_num, vcol)
  local line = vim.api.nvim_buf_get_lines(bufnr, line_num, line_num + 1, false)[1] or ""
  local col = 0
  local current_vcol = 0

  for i = 1, #line do
    local char = line:sub(i, i)
    if char == '\t' then
      -- Tab expands to next multiple of tabstop
      local tabstop = vim.bo[bufnr].tabstop or 8
      current_vcol = math.floor(current_vcol / tabstop) * tabstop + tabstop
    else
      current_vcol = current_vcol + 1
    end

    if current_vcol >= vcol then
      return i - 1 -- Convert to 0-indexed
    end
  end

  -- If we've gone past the end of the line, return the line length
  return #line
end

-- Get visual selection range
local function get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local mode = vim.fn.mode()

  local selection = {
    start_line = start_pos[2] - 1, -- Convert to 0-indexed
    start_col = start_pos[3] - 1,
    end_line = end_pos[2] - 1,
    end_col = end_pos[3],
    is_visual_block = mode == '\22' -- Ctrl-V visual block mode
  }

  -- For visual block mode, we need to handle virtual columns
  if selection.is_visual_block then
    selection.start_vcol = vim.fn.virtcol("'<") - 1
    selection.end_vcol = vim.fn.virtcol("'>")
  end

  return selection
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

  local hl_group = get_current_hl_group()
  local extmark_ids = {}

  -- Handle visual block mode differently
  if selection.is_visual_block then
    -- Visual block mode - paint a rectangular block
    for line_num = selection.start_line, selection.end_line do
      local line = vim.api.nvim_buf_get_lines(bufnr, line_num, line_num + 1, false)[1] or ""

      -- Convert virtual columns to actual columns for this line
      local start_col = vcol_to_col(bufnr, line_num, selection.start_vcol)
      local end_col = vcol_to_col(bufnr, line_num, selection.end_vcol)

      -- Ensure we don't go beyond the line length
      start_col = math.min(start_col, #line)
      end_col = math.min(end_col, #line)

      -- Only highlight if there's content to highlight
      if start_col < end_col then
        local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_num, start_col, {
          end_row = line_num,
          end_col = end_col,
          hl_group = hl_group,
        })
        table.insert(extmark_ids, extmark_id)
      end
    end
  elseif selection.start_line == selection.end_line then
    -- Single line selection
    local line = vim.api.nvim_buf_get_lines(bufnr, selection.start_line, selection.start_line + 1, false)[1] or ""
    local end_col = math.min(selection.end_col, #line)

    if selection.start_col < end_col then
      local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, selection.start_line, selection.start_col, {
        end_row = selection.end_line,
        end_col = end_col,
        hl_group = hl_group,
      })
      table.insert(extmark_ids, extmark_id)
    end
  else
    -- Multi-line selection - handle partial lines properly
    local lines = vim.api.nvim_buf_get_lines(bufnr, selection.start_line, selection.end_line + 1, false)

    for i, line in ipairs(lines) do
      local line_num = selection.start_line + i - 1
      local start_col, end_col

      if i == 1 then
        -- First line: start from selection start column
        start_col = selection.start_col
        end_col = #line
      elseif i == #lines then
        -- Last line: end at selection end column
        start_col = 0
        end_col = math.min(selection.end_col, #line)
      else
        -- Middle lines: full line
        start_col = 0
        end_col = #line
      end

      -- Only highlight if there's content to highlight
      if start_col < end_col then
        local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_num, start_col, {
          end_row = line_num,
          end_col = end_col,
          hl_group = hl_group,
        })
        table.insert(extmark_ids, extmark_id)
      end
    end
  end

  -- Store the painted region with extmark IDs
  table.insert(painted_regions, {
    bufnr = bufnr,
    start_line = selection.start_line,
    start_col = selection.start_col,
    end_line = selection.end_line,
    end_col = selection.end_col,
    brush = current_brush,
    extmark_ids = extmark_ids,
    is_visual_block = selection.is_visual_block or false
  })
end

-- Paint the current visual selection or character under cursor
function M.paint(line1, line2)
  local selection

  if line1 and line2 then
    -- Called with range (e.g., :'<,'>Paint)
    selection = get_visual_selection()
    print("Painted range with " .. current_brush .. " brush!")
  else
    -- Called without range - check current mode
    local mode = vim.fn.mode()

    if mode == 'v' or mode == 'V' or mode == '\22' then -- \22 is Ctrl-V
      -- Visual mode - paint selection
      selection = get_visual_selection()
      print("Painted selection with " .. current_brush .. " brush!")
    else
      -- Normal mode - paint character under cursor
      selection = get_cursor_position()
      print("Painted character with " .. current_brush .. " brush!")
    end
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

  -- Clear extmarks for this buffer
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  -- Remove from storage
  painted_regions = vim.tbl_filter(function(region)
    return region.bufnr ~= bufnr
  end, painted_regions)

  print("Cleared all paint!")
end

-- Clear all painted regions in all buffers
function M.clear_all_paint()
  -- Clear extmarks in all buffers
  for _, region in ipairs(painted_regions) do
    if vim.api.nvim_buf_is_valid(region.bufnr) then
      vim.api.nvim_buf_clear_namespace(region.bufnr, ns_id, 0, -1)
    end
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
  vim.api.nvim_create_user_command('Paint', function(opts)
    M.paint(opts.line1, opts.line2)
  end, {
    range = true,
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
