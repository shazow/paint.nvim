-- ~/.config/nvim/lua/paint/highlighter.lua
-- Manages highlight groups and extmarks.

local C = require("paint.config")
local H = {}

function H.get_hl_group_name(brush)
  local fg_str = brush.fg and string.gsub(brush.fg, "#", "_") or "NONE"
  local bg_str = brush.bg and string.gsub(brush.bg, "#", "_") or "NONE"
  return string.format("Paint_fg_%s_bg_%s", fg_str, bg_str)
end

function H.ensure_hl_group(brush)
  local group_name = H.get_hl_group_name(brush)
  local id = vim.api.nvim_get_hl_id_by_name(group_name)

  if id == 0 then
    local hl_def = {}
    if brush.fg then hl_def.fg = brush.fg end
    if brush.bg then hl_def.bg = brush.bg end
    -- Future: if brush.bold then hl_def.bold = true end
    vim.api.nvim_set_hl(0, group_name, hl_def)
  end
  return group_name
end

function H.paint_cell(bufnr, line, col, brush)
  if not brush then
    vim.notify("Paint: No brush provided for painting.", vim.log.levels.ERROR)
    return
  end
  local hl_group_name = H.ensure_hl_group(brush)
  H.clear_cell_paint(bufnr, line, col) -- Clear previous paint from this plugin first
  vim.api.nvim_buf_set_extmark(bufnr, C.state.ns_id, line, col, {
    end_col = col + 1,
    hl_group = hl_group_name,
    hl_mode = C.config.highlight_mode,
  })
end

function H.clear_cell_paint(bufnr, line, col)
  local marks = vim.api.nvim_buf_get_extmarks(
    bufnr, C.state.ns_id, {line, col}, {line, col + 1}, {details = false}
  )
  for _, mark_id in ipairs(marks) do
    vim.api.nvim_buf_del_extmark(bufnr, C.state.ns_id, mark_id)
  end
end

function H.get_cell_paint_hl_group(bufnr, line, col)
  local marks = vim.api.nvim_buf_get_extmarks(
    bufnr, C.state.ns_id, {line, col}, {line, col + 1}, {details = true}
  )
  if #marks > 0 then
    return marks[1].hl_group
  end
  return nil
end

return H

-- ~/.config/nvim/lua/paint/core.lua
-- Core logic for applying and clearing paint.

local C = require("paint.config")
local H = require("paint.highlighter")
local Core = {}

-- Apply the current brush to the character under the cursor.
function Core._apply_to_char() -- Renamed to indicate internal use by dispatcher
  if not C.state.current_brush_obj then
    vim.notify("Paint: No brush selected.", vim.log.levels.WARN)
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  H.paint_cell(bufnr, pos[1] - 1, pos[2], C.state.current_brush_obj)
end

-- Clear paint from the character under the cursor.
function Core._clear_at_char() -- Renamed
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  H.clear_cell_paint(bufnr, pos[1] - 1, pos[2])
end

-- Internal helper to toggle paint for a single cell
function Core._toggle_cell(bufnr, line, col, brush_to_toggle_with)
    if not brush_to_toggle_with then
        vim.notify("Paint: No brush selected for toggle.", vim.log.levels.WARN)
        return
    end

    local current_cell_hl_group = H.get_cell_paint_hl_group(bufnr, line, col)
    local new_brush_hl_group = H.get_hl_group_name(brush_to_toggle_with)

    if current_cell_hl_group == new_brush_hl_group then
        H.clear_cell_paint(bufnr, line, col)
    else
        H.paint_cell(bufnr, line, col, brush_to_toggle_with)
    end
end

-- Toggle paint on the character under the cursor.
function Core._toggle_at_char() -- Renamed
    local bufnr = vim.api.nvim_get_current_buf()
    local pos = vim.api.nvim_win_get_cursor(0)
    Core._toggle_cell(bufnr, pos[1] - 1, pos[2], C.state.current_brush_obj)
end

-- Common logic for iterating over a visual selection
local function _iterate_visual_selection(mode, bufnr, action_on_cell)
    local start_pos = vim.api.nvim_buf_get_mark(bufnr, "<") -- {line, col} 1-idx line, 0-idx col
    local end_pos = vim.api.nvim_buf_get_mark(bufnr, ">")

    local start_line = start_pos[1] - 1 -- 0-indexed line
    local end_line = end_pos[1] - 1   -- 0-indexed line

    -- Columns from marks are 0-indexed
    local mark_start_col = start_pos[2]
    local mark_end_col = end_pos[2]

    for l = start_line, end_line do
        local line_content = vim.api.nvim_buf_get_lines(bufnr, l, l + 1, false)[1]
        if line_content then
            local iter_start_col, iter_end_col

            if mode == "V" then -- Linewise
                iter_start_col = 0
                iter_end_col = #line_content - 1
            elseif mode == "\22" then -- Blockwise (Ctrl-V, represented by char code 22)
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
                -- Ensure start <= end for characterwise if selection is backwards on a single line
                if l == start_line and l == end_line and iter_start_col > iter_end_col then
                    iter_start_col, iter_end_col = iter_end_col, iter_start_col
                end
            end

            for c = iter_start_col, iter_end_col do
                if c >= 0 and c < #line_content then -- Ensure column is within line bounds
                    action_on_cell(bufnr, l, c)
                end
            end
        end
    end
    vim.cmd("normal! gv") -- Re-select the visual area
end


-- Apply the current brush to the visual selection.
function Core._apply_to_visual_selection(mode) -- Renamed
  if not C.state.current_brush_obj then
    vim.notify("Paint: No brush selected.", vim.log.levels.WARN)
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  _iterate_visual_selection(mode, bufnr, function(b, l, c)
    H.paint_cell(b, l, c, C.state.current_brush_obj)
  end)
end

-- Clear paint from the visual selection.
function Core._clear_in_visual_selection(mode) -- Renamed
  local bufnr = vim.api.nvim_get_current_buf()
  _iterate_visual_selection(mode, bufnr, function(b, l, c)
    H.clear_cell_paint(b, l, c)
  end)
end

-- Toggle paint in the visual selection.
function Core._toggle_in_visual_selection(mode) -- New function
    if not C.state.current_brush_obj then
        vim.notify("Paint: No brush selected for toggle.", vim.log.levels.WARN)
        return
    end
    local bufnr = vim.api.nvim_get_current_buf()
    _iterate_visual_selection(mode, bufnr, function(b, l, c)
        Core._toggle_cell(b, l, c, C.state.current_brush_obj)
    end)
end


-- Clear all paint from the current buffer.
function Core.clear_all_in_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, C.state.ns_id, 0, -1)
  vim.notify("Paint: All paint cleared from current buffer.")
end

-- UI for selecting a brush
function Core.select_brush_ui()
  local brush_names = {}
  for _, brush in ipairs(C.config.brushes) do
    table.insert(brush_names, brush.name)
  end

  if #brush_names == 0 then
    vim.notify("Paint: No brushes defined to select from.", vim.log.levels.WARN)
    return
  end

  vim.ui.select(brush_names, {
    prompt = "Select a brush:",
    format_item = function(item) return "🖌️ " .. item end,
  }, function(choice)
    if choice then
      C.set_current_brush_by_name(choice)
      vim.notify("Paint: Brush set to '" .. choice .. "'")
    else
      vim.notify("Paint: No brush selected.")
    end
  end)
end

-- Helper to dispatch paint actions based on mode
local function _execute_paint_action(char_action_func, visual_action_func)
    local current_mode = vim.fn.mode() -- "n", "v", "V", "\22" (Ctrl-V), "i", "c", etc.

    if current_mode == "n" then
        char_action_func()
    elseif current_mode == "v" or current_mode == "V" or current_mode == "\22" then
        visual_action_func(current_mode) -- Pass the specific visual mode ('v', 'V', or '\22')
    else
        -- This case handles when a command like :PaintApply is run from the command line
        -- after a visual selection was made (e.g., `v ... :PaintApply`).
        -- vim.fn.mode() would be 'c' (command line).
        -- We use vim.fn.visualmode() to get the type of the *last* visual selection.
        local last_visual_type = vim.fn.visualmode() -- Returns 'v', 'V', '\x16' (same as \22), or empty string
        if last_visual_type ~= "" then
            visual_action_func(last_visual_type)
        else
            vim.notify("Paint: Action intended for Normal or Visual mode, or after making a visual selection.", vim.log.levels.WARN)
        end
    end
end

-- Unified public API functions
function Core.apply()
    _execute_paint_action(Core._apply_to_char, Core._apply_to_visual_selection)
end

function Core.clear()
    _execute_paint_action(Core._clear_at_char, Core._clear_in_visual_selection)
end

function Core.toggle()
    _execute_paint_action(Core._toggle_at_char, Core._toggle_in_visual_selection)
end

return Core
