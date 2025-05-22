-- Sonnet 4 prompt: Write me a simple nvim lua plugin for "painting" the background of selected visual blocks in red

local M = {}

-- Namespace for our highlights
local ns_id = vim.api.nvim_create_namespace('painter')

-- Storage for painted regions
local painted_regions = {}

-- Create the highlight group
local function setup_highlight()
  vim.api.nvim_set_hl(0, 'Painter', {
    bg = '#ff4444',
    fg = '#ffffff'
  })
end

-- Get visual selection range
local function get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  return {
    start_line = start_pos[2] - 1,  -- Convert to 0-indexed
    start_col = start_pos[3] - 1,
    end_line = end_pos[2] - 1,
    end_col = end_pos[3]
  }
end

-- Paint the current visual selection
function M.paint_selection()
  local selection = get_visual_selection()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Store the painted region
  table.insert(painted_regions, {
    bufnr = bufnr,
    start_line = selection.start_line,
    start_col = selection.start_col,
    end_line = selection.end_line,
    end_col = selection.end_col
  })

  -- Apply highlight
  if selection.start_line == selection.end_line then
    -- Single line selection
    vim.api.nvim_buf_add_highlight(
      bufnr,
      ns_id,
      'Painter',
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
      'Painter',
      selection.start_line,
      selection.start_col,
      -1
    )

    -- Middle lines
    for line = selection.start_line + 1, selection.end_line - 1 do
      vim.api.nvim_buf_add_highlight(
        bufnr,
        ns_id,
        'Painter',
        line,
        0,
        -1
      )
    end

    -- Last line
    vim.api.nvim_buf_add_highlight(
      bufnr,
      ns_id,
      'Painter',
      selection.end_line,
      0,
      selection.end_col
    )
  end

  print("Painted selection!")
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

-- Setup function
function M.setup(opts)
  opts = opts or {}

  -- Setup highlight group
  setup_highlight()

  -- Create user commands
  vim.api.nvim_create_user_command('PaintSelection', M.paint_selection, {
    range = true,
    desc = 'Paint the current visual selection'
  })

  vim.api.nvim_create_user_command('ClearPaint', M.clear_paint, {
    desc = 'Clear all painted regions in current buffer'
  })

  vim.api.nvim_create_user_command('ClearAllPaint', M.clear_all_paint, {
    desc = 'Clear all painted regions in all buffers'
  })

  -- Default keymaps (can be overridden by user)
  local keymap_opts = { noremap = true, silent = true }

  vim.keymap.set('v', '<leader>vp', function()
    vim.cmd("'<,'>PaintSelection")
  end, vim.tbl_extend('force', keymap_opts, { desc = 'Paint visual selection' }))

  vim.keymap.set('n', '<leader>vc', M.clear_paint,
    vim.tbl_extend('force', keymap_opts, { desc = 'Clear paint in buffer' }))

  vim.keymap.set('n', '<leader>vC', M.clear_all_paint,
    vim.tbl_extend('force', keymap_opts, { desc = 'Clear all paint' }))

  print("painter plugin loaded!")
end

return M
