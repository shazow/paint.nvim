# paint.nvim

Paint the background of any visual selection or under your cursor.

<img width="321" alt="image" src="https://github.com/user-attachments/assets/af8fabe5-e2d1-4ffb-8161-c1ac8212b465" />

## Usage

### Setup

```lua
require("paint").setup({
  -- Optional: Override the default brushes
  brushes = {
    { name = "Red",    bg = "#ff6b6b" },
    { name = "Blue",   bg = "#4ecdc4" },
    { name = "Green",  bg = "#95e1d3" },
    { name = "Yellow", bg = "#fce38a" },
    { name = "Purple", bg = "#c44569" },
    { name = "Orange", bg = "#f8b500" },
  },

  -- Optional: Add extra brushes to the default set
  extra_brushes = {
    { name = "Mint",     bg = "#00f5a0", fg = "#000000" },
    { name = "Lavender", bg = "#d8bfd8" },
  },
})
```

### Commands

- `:Paint`
- `:PaintSelect`
- `:PaintClear`

### Mappings

```lua
vim.keymap.set("v", "<leader>p", ":Paint<CR>", { desc = "Paint selection" })
vim.keymap.set("n", "<leader>ps", ":PaintSelect<CR>", { desc = "Select paint brush" })
vim.keymap.set("n", "<leader>pc", ":PaintClear<CR>", { desc = "Clear paint" })
```

### API

```lua
local Paint = require("paint")

Paint.paint() -- Paint the current cursor or selection
Paint.select_brush() -- Show selection UI
Paint.select_brush({ name = "Custom", fg = "#fffffff" }) -- Set your own brush
Paint.clear()
Paint.add_brush({ name = "Lavender", bg = "#d8bfd8" })
Paint.brushes() -- Return the saved brushes
Paint.selected_brush() -- Return the current brush
```

## License

MIT
