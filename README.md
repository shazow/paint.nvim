# paint.nvim

Paint the background of any visual selection or under your cursor.

<img width="321" alt="image" src="https://github.com/user-attachments/assets/af8fabe5-e2d1-4ffb-8161-c1ac8212b465" />

## Usage

Setup

```lua
require("paint").setup({
  -- Optional: Set your own brushes...
  brushes = {
    { name = "Mint",     bg = "#00f5a0" },
    { name = "Lavender", bg = "#d8bfd8" },
  }
})
```

Commands

- `:Paint`
- `:PaintSelect`
- `:PaintClear`

Mappings

```lua
vim.keymap.set("v", "<leader>p", ":Paint<CR>", { desc = "Paint selection" })
vim.keymap.set("n", "<leader>ps", ":PaintSelect<CR>", { desc = "Select paint brush" })
vim.keymap.set("n", "<leader>pc", ":PaintClear<CR>", { desc = "Clear paint" })
```
