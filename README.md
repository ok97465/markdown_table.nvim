# markdown_table.nvim
Neovim 0.11+ plugin for creating and aligning Markdown tables with ease.

## Getting Started
```lua
require("markdown_table").setup({
  highlight = true,        -- toggle table highlighting
  highlight_group = "CursorLine", -- highlight group used for extmarks
  auto_align = true,       -- enable InsertLeave/TextChanged auto-alignment
  debounce_ms = 120,       -- delay (ms) before auto alignment runs
})
```
All keys are optional; the snippet shows the default configuration.

### Commands
- `:MarkdownTableToggle` – Enable or disable table mode for the current buffer.
- `:MarkdownTableAlign` – Align the table under the cursor.

Sample inputs used for testing live in `tests/fixtures.lua`, making it easy to add more scenarios.

## Testing
Run `make test` to execute the headless Neovim regression check.
