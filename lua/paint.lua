-- ~/.config/nvim/plugin/paint.lua
-- Sets up commands and mappings for the plugin.

local Config = require("paint.config")
local Core = require("paint.core")

if not Config.state.ns_id then
  Config.setup()
end

-- Unified User Commands
vim.api.nvim_create_user_command("PaintApply", Core.apply, {
  desc = "Paint: Apply current brush (Normal: char, Visual: selection)"
})
vim.api.nvim_create_user_command("PaintClear", Core.clear, {
  desc = "Paint: Clear paint (Normal: char, Visual: selection)"
})
vim.api.nvim_create_user_command("PaintToggle", Core.toggle, {
  desc = "Paint: Toggle current brush (Normal: char, Visual: selection)"
})

-- Other Commands
vim.api.nvim_create_user_command("PaintSelectBrush", Core.select_brush_ui, {
  desc = "Paint: Select active brush"
})
vim.api.nvim_create_user_command("PaintClearAll", Core.clear_all_in_buffer, {
  desc = "Paint: Clear all paint from current buffer"
})

-- Suggested Mappings (users should define these in their own config)
-- vim.keymap.set("n", "<leader>ps", "<cmd>PaintSelectBrush<cr>", { desc = "Paint: Select Brush" })
-- vim.keymap.set("n", "<leader>pa", "<cmd>PaintApply<cr>", { desc = "Paint: Apply Brush (Char)" })
-- vim.keymap.set("v", "<leader>pa", "<cmd>PaintApply<cr>", { desc = "Paint: Apply Brush (Visual)" })
-- vim.keymap.set("n", "<leader>pc", "<cmd>PaintClear<cr>", { desc = "Paint: Clear Paint (Char)" })
-- vim.keymap.set("v", "<leader>pc", "<cmd>PaintClear<cr>", { desc = "Paint: Clear Paint (Visual)" })
-- vim.keymap.set("n", "<leader>pt", "<cmd>PaintToggle<cr>", { desc = "Paint: Toggle Brush (Char)" })
-- vim.keymap.set("v", "<leader>pt", "<cmd>PaintToggle<cr>", { desc = "Paint: Toggle Brush (Visual)" })
-- vim.keymap.set("n", "<leader>pA", "<cmd>PaintClearAll<cr>", { desc = "Paint: Clear All Paint" })

vim.notify("Paint plugin commands (Apply, Clear, Toggle, SelectBrush, ClearAll) loaded.", vim.log.levels.INFO, {title="Paint Plugin"})
