-- ~/.config/nvim/lua/painter.lua
-- Main file for the Painter plugin. Contains all logic.

local Painter = {}

-- Default configuration
Painter.config = {
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
Painter.state = {
  current_brush_obj = nil,
  ns_id = nil, -- Initialized in setup
}

--------------------------------------------------------------------------------
-- Highlighter Functions (Internal)
--------------------------------------------------------------------------------

-- Generates a unique highlight group name for a brush.
local function _get_hl_group_name(brush)
  local fg_str = brush.fg and string.gsub(brush.fg, "#", "_") or "NONE"
  local bg_str = brush.bg and string.gsub(brush.bg, "#", "_") or "NONE"
  return string.format("Painter_fg_%s_bg_%s", fg_str, bg_str)
end

-- Ensures the highlight group for a brush exists.
local function _ensure_hl_group(brush)
  local group_name = _get_hl_group_name(brush)
  local id = vim.api.nvim_get_hl_id_by_name(group_name)

  if id == 0 then -- ID 0 means not found
    local hl_def = {}
    if brush.fg then hl_def.fg = brush.fg end
    if brush.bg then hl_def.bg = brush.bg end
    -- Future: if brush.bold then hl_def.bold = true end
    vim.api.nvim_set_hl(0, group_name, hl_def)
  end
  return group_name
end

-- Clears paint from a single cell.
local function _clear_cell_paint(bufnr, line, col)
  local marks = vim.api.nvim_buf_get_extmarks(
    bufnr, Painter.state.ns_id, {line, col}, {line, col + 1}, {details = false}
  )
  for _, mark_id in ipairs(marks) do
    vim.api.nvim_buf_del_extmark(bufnr, Painter.state.ns_id, mark_id)
  end
end

-- Applies a brush to a single cell (character).
local function _paint_cell(bufnr, line, col, brush)
  if not brush then
    vim.notify("Painter: No brush provided for painting.", vim.log.levels.ERROR)
    return
  end
  local hl_group_name = _ensure_hl_group(brush)
  _clear_cell_paint(bufnr, line, col) -- Clear previous paint from this plugin first
  
  -- Log the arguments before calling nvim_buf_set_extmark
  vim.notify(string.format(
    "Painter: Setting extmark - bufnr: %s, ns_id: %s, line: %s, col: %s, options: {end_col: %s, hl_group: %s, hl_mode: %s}",
    bufnr, Painter.state.ns_id, line, col, col + 1, hl_group_name, Painter.config.highlight_mode
  ), vim.log.levels.DEBUG)
  
  vim.api.nvim_buf_set_extmark(bufnr, Painter.state.ns_id, line, col, {
    end_col = col + 1,
    hl_group = hl_group_name,
    hl_mode = Painter.config.highlight_mode,
  })
end

-- Gets the highlight group of the paint mark at a cell, if any.
local function _get_cell_paint_hl_group(bufnr, line, col)
  local marks = vim.api.nvim_buf_get_extmarks(
    bufnr, Painter.state.ns_id, {line, col}, {line, col + 1}, {details = true}
  )
  if #marks > 0 then
    return marks[1].hl_group
  end
  return nil
end


--------------------------------------------------------------------------------
-- Core Action Functions (Internal Helpers)
--------------------------------------------------------------------------------

-- Apply the current brush to the character under the cursor.
local function _apply_to_char()
  if not Painter.state.current_brush_obj then
    vim.notify("Painter: No brush selected.", vim.log.levels.WARN)
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0) -- {row, col} 1-indexed row, 0-indexed col
  _paint_cell(bufnr, pos[1] - 1, pos[2], Painter.state.current_brush_obj)
end

-- Clear paint from the character under the cursor.
local function _clear_at_char()
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  _clear_cell_paint(bufnr, pos[1] - 1, pos[2])
end

-- Internal helper to toggle paint for a single cell
local function _toggle_cell(bufnr, line, col, brush_to_toggle_with)
    if not brush_to_toggle_with then
        vim.notify("Painter: No brush selected for toggle.", vim.log.levels.WARN)
        return
    end

    local current_cell_hl_group = _get_cell_paint_hl_group(bufnr, line, col)
    local new_brush_hl_group = _get_hl_group_name(brush_to_toggle_with)

    if current_cell_hl_group == new_brush_hl_group then
        _clear_cell_paint(bufnr, line, col)
    else
        _paint_cell(bufnr, line, col, brush_to_toggle_with)
    end
end

-- Toggle paint on the character under the cursor.
local function _toggle_at_char()
    local bufnr = vim.api.nvim_get_current_buf()
    local pos = vim.api.nvim_win_get_cursor(0)
    _toggle_cell(bufnr, pos[1] - 1, pos[2], Painter.state.current_brush_obj)
end

-- Common logic for iterating over a visual selection
local function _iterate_visual_selection(mode, bufnr, action_on_cell)
    local start_pos = vim.api.nvim_buf_get_mark(bufnr, "<") -- {line, col} 1-idx line, 0-idx col
    local end_pos = vim.api.nvim_buf_get_mark(bufnr, ">")

    local start_line = start_pos[1] - 1 -- 0-indexed line
    local end_line = end_pos[1] - 1   -- 0-indexed line

    local mark_start_col = start_pos[2] -- 0-indexed col
    local mark_end_col = end_pos[2]     -- 0-indexed col

    for l = start_line, end_line do
        local line_content = vim.api.nvim_buf_get_lines(bufnr, l, l + 1, false)[1]
        if line_content then
            local iter_start_col, iter_end_col

            if mode == "V" then -- Linewise
                iter_start_col = 0
                iter_end_col = #line_content - 1
            elseif mode == "\22" or mode == "\x16" then -- Blockwise (Ctrl-V)
                iter_start_col = math.min(mark_start_col, mark_end_col)
                iter_end_col = math.max(mark_start_col, mark_end_col)
            else -- Characterwise 'v'
                if l == start_line then
                    iter_start_col = mark_start_col
                else
                    iter_start_col = 0
                end
                if l == end_line then
                    iter_end_col = mark_end_col
                else
                    iter_end_col = #line_content - 1
                end
                if l == start_line and l == end_line and iter_start_col > iter_end_col then
                    iter_start_col, iter_end_col = iter_end_col, iter_start_col
                end
            end

            for c = iter_start_col, iter_end_col do
                if c >= 0 and c < #line_content then
                    action_on_cell(bufnr, l, c)
                end
            end
        end
    end
    vim.cmd("normal! gv") -- Re-select the visual area
end

-- Apply the current brush to the visual selection.
local function _apply_to_visual_selection(mode)
  if not Painter.state.current_brush_obj then
    vim.notify("Painter: No brush selected.", vim.log.levels.WARN)
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  _iterate_visual_selection(mode, bufnr, function(b, l, c)
    _paint_cell(b, l, c, Painter.state.current_brush_obj)
  end)
end

-- Clear paint from the visual selection.
local function _clear_in_visual_selection(mode)
  local bufnr = vim.api.nvim_get_current_buf()
  _iterate_visual_selection(mode, bufnr, function(b, l, c)
    _clear_cell_paint(b, l, c)
  end)
end

-- Toggle paint in the visual selection.
local function _toggle_in_visual_selection(mode)
    if not Painter.state.current_brush_obj then
        vim.notify("Painter: No brush selected for toggle.", vim.log.levels.WARN)
        return
    end
    local bufnr = vim.api.nvim_get_current_buf()
    _iterate_visual_selection(mode, bufnr, function(b, l, c)
        _toggle_cell(b, l, c, Painter.state.current_brush_obj)
    end)
end

-- Helper to dispatch paint actions based on mode
local function _execute_paint_action(char_action_func, visual_action_func)
    local current_mode = vim.fn.mode(false) -- false to get full mode string e.g. "v", "V", "\x16"
    
    if current_mode == "n" then -- Normal mode
        char_action_func()
    elseif current_mode == "v" or current_mode == "V" or current_mode == "\22" or current_mode == "\x16" then -- Visual modes
        visual_action_func(current_mode)
    else
        -- If command is run from command-line after visual selection (mode becomes 'c')
        local last_visual_type = vim.fn.visualmode() 
        if last_visual_type ~= "" then
             -- visualmode() returns 'v', 'V', or '\x16' (for blockwise)
            visual_action_func(last_visual_type)
        else
            vim.notify("Painter: Action intended for Normal or Visual mode, or after making a visual selection.", vim.log.levels.WARN)
        end
    end
end


--------------------------------------------------------------------------------
-- Public API / Command Functions
--------------------------------------------------------------------------------

-- Unified function to apply paint
function Painter.apply()
    _execute_paint_action(_apply_to_char, _apply_to_visual_selection)
end

-- Unified function to clear paint
function Painter.clear()
    _execute_paint_action(_clear_at_char, _clear_in_visual_selection)
end

-- Unified function to toggle paint
function Painter.toggle()
    _execute_paint_action(_toggle_at_char, _toggle_in_visual_selection)
end

-- Clear all paint from the current buffer.
function Painter.clear_all_in_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, Painter.state.ns_id, 0, -1)
  vim.notify("Painter: All paint cleared from current buffer.")
end

-- UI for selecting a brush
function Painter.select_brush_ui()
  local brush_names = {}
  for _, brush in ipairs(Painter.config.brushes) do
    table.insert(brush_names, brush.name)
  end

  if #brush_names == 0 then
    vim.notify("Painter: No brushes defined to select from.", vim.log.levels.WARN)
    return
  end

  vim.ui.select(brush_names, {
    prompt = "Select a Painter brush:",
    format_item = function(item) return "🖌️ " .. item end,
  }, function(choice)
    if choice then
      Painter.set_current_brush_by_name(choice)
      vim.notify("Painter: Brush set to '" .. choice .. "'")
    else
      vim.notify("Painter: No brush selected.")
    end
  end)
end

--------------------------------------------------------------------------------
-- Brush Management
--------------------------------------------------------------------------------

-- Finds a brush by its name
function Painter.get_brush_by_name(name)
  for _, brush in ipairs(Painter.config.brushes) do
    if brush.name == name then
      return brush
    end
  end
  return nil
end

-- Sets the current brush by its name
function Painter.set_current_brush_by_name(name)
  local brush = Painter.get_brush_by_name(name)
  if brush then
    Painter.state.current_brush_obj = brush
    return true
  else
    vim.notify("Painter: Brush '" .. name .. "' not found.", vim.log.levels.WARN)
    return false
  end
end

--------------------------------------------------------------------------------
-- Setup Function
--------------------------------------------------------------------------------

function Painter.setup(user_config)
  user_config = user_config or {}
  -- Deep extend user config into Painter.config
  Painter.config = vim.tbl_deep_extend("force", Painter.config, user_config)

  -- Validate brushes
  local valid_brushes = {}
  for _, brush in ipairs(Painter.config.brushes) do
    if brush.name and (brush.fg or brush.bg) then
      table.insert(valid_brushes, brush)
    else
      vim.notify("Painter: Invalid brush definition skipped: " .. vim.inspect(brush), vim.log.levels.WARN)
    end
  end
  Painter.config.brushes = valid_brushes

  -- Initialize namespace ID
  Painter.state.ns_id = vim.api.nvim_create_namespace("painter_nvim")

  -- Set the initial brush
  if not Painter.set_current_brush_by_name(Painter.config.default_brush_name) then
    if #Painter.config.brushes > 0 then
      Painter.set_current_brush_by_name(Painter.config.brushes[1].name)
    else
      vim.notify("Painter: No valid brushes configured.", vim.log.levels.ERROR)
    end
  end

  -- Create User Commands
  vim.api.nvim_create_user_command("PainterApply", Painter.apply, {
    desc = "Painter: Apply current brush (Normal: char, Visual: selection)"
  })
  vim.api.nvim_create_user_command("PainterClear", Painter.clear, {
    desc = "Painter: Clear paint (Normal: char, Visual: selection)"
  })
  vim.api.nvim_create_user_command("PainterToggle", Painter.toggle, {
    desc = "Painter: Toggle current brush (Normal: char, Visual: selection)"
  })
  vim.api.nvim_create_user_command("PainterSelectBrush", Painter.select_brush_ui, {
    desc = "Painter: Select active brush"
  })
  vim.api.nvim_create_user_command("PainterClearAll", Painter.clear_all_in_buffer, {
    desc = "Painter: Clear all paint from current buffer"
  })
  
  local current_brush_name = "None"
  if Painter.state.current_brush_obj and Painter.state.current_brush_obj.name then
      current_brush_name = Painter.state.current_brush_obj.name
  end
  vim.notify("Painter plugin loaded. Current brush: " .. current_brush_name, vim.log.levels.INFO, {title = "Painter Plugin"})

  -- Suggested Mappings (users should define these in their own config)
  -- vim.keymap.set("n", "<leader>ps", "<cmd>PainterSelectBrush<cr>", { desc = "Painter: Select Brush" })
  -- vim.keymap.set("n", "<leader>pa", "<cmd>PainterApply<cr>", { desc = "Painter: Apply Brush (Char)" })
  -- vim.keymap.set("v", "<leader>pa", "<cmd>PainterApply<cr>", { desc = "Painter: Apply Brush (Visual)" })
  -- vim.keymap.set("n", "<leader>pc", "<cmd>PainterClear<cr>", { desc = "Painter: Clear Paint (Char)" })
  -- vim.keymap.set("v", "<leader>pc", "<cmd>PainterClear<cr>", { desc = "Painter: Clear Paint (Visual)" })
  -- vim.keymap.set("n", "<leader>pt", "<cmd>PainterToggle<cr>", { desc = "Painter: Toggle Brush (Char)" })
  -- vim.keymap.set("v", "<leader>pt", "<cmd>PainterToggle<cr>", { desc = "Painter: Toggle Brush (Visual)" })
  -- vim.keymap.set("n", "<leader>pA", "<cmd>PainterClearAll<cr>", { desc = "Painter: Clear All Paint" })
end

return Painter
