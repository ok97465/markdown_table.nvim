# markdown_table.nvim
Neovim 0.11+ plugin for creating and aligning Markdown tables with ease.

## Getting Started
```lua
require("markdown_table").setup({
  highlight = true,        -- toggle table highlighting
  highlight_group = "CursorLine", -- highlight group used for extmarks
  auto_align = true,       -- enable InsertLeave/TextChanged auto-alignment
  debounce_ms = 120,       -- delay (ms) before auto alignment runs
  indicator = {
    enable = true,         -- show a winbar badge while table mode is active
    text = "[Table Mode]", -- displayed label
    highlight = "Title",   -- highlight group used by the badge
  },
})
```
All keys are optional; the snippet shows the default configuration.

### Commands
- `:MarkdownTableToggle` – Enable or disable table mode for the current buffer.
- `:MarkdownTableAlign` – Align the table under the cursor.
- `:MarkdownTableCreate` – Prompt for rows/columns and insert a table skeleton.

Sample inputs used for testing live in `tests/fixtures.lua`, making it easy to add more scenarios.

## Testing
Run `make test` to execute the headless Neovim regression check.
If Neovim lives under a custom name, export `NVIM=/path/to/nvim` before running the target.
