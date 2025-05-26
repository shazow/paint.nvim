-- Shim for testing in development
-- run with `nvim -u dev.lua` or `:source %`

local plugin_root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(plugin_root)
vim.notify("Added to path: " .. vim.inspect(vim.opt.runtimepath), vim.log.levels.INFO)

local Paint = require('paint')
Paint.setup()

vim.keymap.set("v", "<leader>p", ":Paint<CR>", { desc = "Paint selection" })
vim.keymap.set("n", "<leader>ps", ":PaintSelect<CR>", { desc = "Select paint brush" })
vim.keymap.set("n", "<leader>pc", ":PaintClear<CR>", { desc = "Clear paint" })

Paint.select_brush()
