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
- `:MarkdownTableFromSelection` – Convert CSV or whitespace-delimited lines into a table appended after the selection.

#### Converting selections
Use the command on any visual or linewise range containing CSV or whitespace-delimited values:

```vim
:'<,'>MarkdownTableFromSelection
```

The plugin inserts a blank line (when needed), appends a Markdown table built from the selected fields, and aligns it using the standard formatter.

### Navigation
`markdown_table.move_cell_left()` and `markdown_table.move_cell_right()` jump the cursor to the previous or next cell on the current table row. They return `true` on success so you can gracefully fall back to the original key behavior when no table cell is available.

```lua
local table_mode = require("markdown_table")

-- Normal mode navigation between cells
vim.keymap.set("n", "[t", table_mode.move_cell_left, { desc = "Markdown table: previous cell" })
vim.keymap.set("n", "]t", table_mode.move_cell_right, { desc = "Markdown table: next cell" })

-- Insert mode example that keeps Tab available outside of tables
local function feedkeys(keys)
  return vim.api.nvim_replace_termcodes(keys, true, true, true)
end

vim.keymap.set("i", "<Tab>", function()
  if table_mode.move_cell_right() then
    return ""
  end
  return feedkeys("<Tab>")
end, { expr = true, desc = "Markdown table: next cell (Insert)" })

vim.keymap.set("i", "<S-Tab>", function()
  if table_mode.move_cell_left() then
    return ""
  end
  return feedkeys("<S-Tab>")
end, { expr = true, desc = "Markdown table: previous cell (Insert)" })
```

Sample inputs used for testing live in `tests/fixtures.lua`, making it easy to add more scenarios.

## Testing
Run `make test` to execute the headless Neovim regression check.
If Neovim lives under a custom name, export `NVIM=/path/to/nvim` before running the target.
