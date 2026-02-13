# Quill.nvim Usage Guide

## Requirements

- Neovim >= 0.10
- TreeSitter (optional, enhances detection for embedded languages and JSX)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "username/quill.nvim",
  event = "VeryLazy",
  config = function()
    require("quill").setup()
  end,
}
```

## Basic Setup

```lua
-- Setup with defaults
require("quill").setup()

-- Setup with custom options
require("quill").setup({
  operators = {
    toggle = "cm",  -- Use custom operator key
  },
  align = {
    column = 100,
    min_gap = 4,
  },
})
```

## Configuration Reference

```lua
require("quill").setup({
  -- Alignment settings for trailing comments
  align = {
    column = 80,      -- Max column for trailing comment alignment
    min_gap = 2,      -- Minimum spaces before comment
  },

  -- Debug region markers
  debug = {
    start_marker = "#region debug",
    end_marker = "#endregion",
  },

  -- Enable/disable keymap groups
  keymaps = {
    operators = true,     -- gc (operator), gcc (line), visual gc
    textobjects = true,   -- ic, ac, iC, aC
    leader = true,        -- <leader>cd, <leader>cD, <leader>cn, <leader>ca
  },

  -- Customize leader mappings
  mappings = {
    debug_buffer = "<leader>cd",
    debug_project = "<leader>cD",
    normalize = "<leader>cn",
    align = "<leader>ca",
  },

  -- Customize operator mapping
  operators = {
    toggle = "gc",          -- Operator: gc{motion}, e.g. gcap, gcac
    toggle_line = nil,      -- Auto-derived: gcc. Set explicitly to override.
  },

  -- Customize text object mappings
  textobjects = {
    inner_block = "ic",
    around_block = "ac",
    inner_line = "iC",
    around_line = "aC",
  },

  -- Warn when overriding existing keymaps
  warn_on_override = true,

  -- Custom language definitions (extends built-in)
  languages = {},

  -- JSX detection settings
  jsx = {
    auto_detect = true,
  },

  -- Semantic analysis options
  semantic = {
    include_decorators = true,
    include_doc_comments = true,
  },
})
```

## Default Keybindings

### Operators

| Mode | Mapping | Description |
|------|---------|-------------|
| Normal | `gc{motion}` | Toggle comment over a motion (e.g., `gcap`, `gcac`, `gc5j`) |
| Normal | `gcc` | Toggle comment on current line |
| Normal | `[count]gcc` | Toggle comment on N lines (e.g., `3gcc`) |
| Visual | `gc` | Toggle comment on selection |
| Visual-line (multi-line) | `gc` | Toggle with block comments (when language supports) |
| Block Visual | `gc` | Toggle with block comments (when language supports) |

### Text Objects

| Mode | Mapping | Description |
|------|---------|-------------|
| Operator-pending, Visual | `ic` | Inner comment block (content only) |
| Operator-pending, Visual | `ac` | Around comment block (with markers) |
| Operator-pending, Visual | `iC` | Inner comment line (content only) |
| Operator-pending, Visual | `aC` | Around comment line (entire line) |

### Leader Mappings

| Mode | Mapping | Description |
|------|---------|-------------|
| Normal | `<leader>cd` | Toggle debug comments in buffer |
| Normal | `<leader>cD` | Toggle debug comments in project |
| Normal | `<leader>cn` | Normalize comment spacing |
| Normal | `<leader>ca` | Align trailing comments |

## User Commands

### `:Quill` Command

| Command | Description |
|---------|-------------|
| `:Quill debug` | Toggle debug regions in buffer |
| `:Quill debug --project` | Preview debug regions across project in quickfix |
| `:Quill debug --list` | List debug regions |
| `:Quill normalize` | Normalize comment spacing |
| `:'<,'>Quill align` | Align trailing comments in selection |
| `:'<,'>Quill convert line` | Convert to line comments |
| `:'<,'>Quill convert block` | Convert to block comments |

## Public API Reference

### Main Module (`quill`)

```lua
local quill = require("quill")
```

#### `setup(opts?)`

Initialize the plugin with optional configuration.

```lua
quill.setup({
  operators = { toggle = "gc" },
})
```

#### `toggle_line()`

Toggle comment on current line. Returns `boolean` indicating success.

```lua
quill.toggle_line()
```

#### `toggle_range(start_line, end_line)`

Toggle comments on a range of lines (1-indexed).

```lua
quill.toggle_range(10, 20)
```

#### `comment(start_line, end_line, style?)`

Force comment on range with optional style (`"line"` or `"block"`).

```lua
quill.comment(5, 15)           -- Use default style
quill.comment(5, 15, "block")  -- Force block comments
```

#### `uncomment(start_line, end_line)`

Force uncomment on range.

```lua
quill.uncomment(5, 15)
```

#### `get_style(bufnr, line, col)`

Get comment style at position. Returns `CommentStyle` or `nil`.

```lua
local style = quill.get_style(0, vim.fn.line("."), vim.fn.col("."))
if style then
  print("Line comment marker:", style.line)
  if style.block then
    print("Block comment:", style.block[1], style.block[2])
  end
end
```

#### `is_commented(bufnr, line)`

Check if line is commented. Returns `boolean`.

```lua
if quill.is_commented(0, vim.fn.line(".")) then
  print("Current line is commented")
end
```

#### `normalize(bufnr?)`

Normalize comment spacing in buffer. Returns count of modified lines.

```lua
local count = quill.normalize()
print("Normalized", count, "lines")
```

#### `align(start_line, end_line, opts?)`

Align trailing comments. Returns count of modified lines.

```lua
local aligned = quill.align(vim.fn.line("'<"), vim.fn.line("'>"), {
  column = 80,
  min_gap = 2,
})
print("Aligned", aligned, "comments")
```

#### `toggle_debug(scope?)`

Toggle debug regions. Scope is `"buffer"` (default) or `"project"`.

```lua
quill.toggle_debug("buffer")   -- Current buffer only
quill.toggle_debug("project")  -- Entire project
```

### Internal Modules

The following modules are used internally by quill.nvim. They are accessible via `require()` but are not part of the stable public API. Their signatures may change between versions.

#### Detection (`quill.core.detect`)

```lua
local detect = require("quill.core.detect")

detect.get_comment_style(bufnr, line, col)      -- CommentStyle with TreeSitter + fallback
detect.is_treesitter_available(bufnr)            -- Check TreeSitter availability
detect.get_language_at_position(bufnr, line, col) -- Embedded language via TreeSitter
detect.is_in_jsx_context(bufnr, line, col)       -- Check JSX markup context
```

#### Toggle (`quill.core.toggle`)

```lua
local toggle = require("quill.core.toggle")

toggle.analyze_lines(bufnr, start_line, end_line)        -- Returns "all_commented" | "none_commented" | "mixed"
toggle.toggle_lines(bufnr, start_line, end_line, opts)   -- Toggle with ToggleOpts
```

#### Undo (`quill.core.undo`)

```lua
local undo = require("quill.core.undo")

undo.with_undo_group(fn)    -- Execute fn within single undo group
undo.start_undo_group()     -- Manual start (supports nesting)
undo.end_undo_group()       -- Manual end
```

#### Utilities (`quill.utils`)

```lua
local utils = require("quill.utils")

utils.escape_pattern(str)              -- Escape Lua pattern characters
utils.is_blank_line(line)              -- Check blank/whitespace line
utils.is_inside_string(line, pos)      -- Quote-aware position check
utils.get_buffer_context(bufnr)        -- Returns BufferContext or nil
utils.validate_numbers(name, ...)      -- Returns ok, err tuple
utils.assert_numbers(name, ...)        -- Raises error on invalid
```

## Type Definitions

All shared types are defined in `lua/quill/types.lua`.

### CommentStyle

```lua
---@class CommentStyle
---@field line string|nil              -- Line comment marker ("//", "#", "--")
---@field block string[]|nil           -- Block comment markers [start, end]
---@field supports_nesting boolean|nil -- Can block comments nest?
---@field jsx boolean|nil              -- Is this a JSX context?
```

### ToggleOpts

```lua
---@class ToggleOpts
---@field style_type "line"|"block"|nil    -- Force specific comment style
---@field force_comment boolean|nil        -- Force comment operation
---@field force_uncomment boolean|nil      -- Force uncomment operation
```

### DebugRegion

```lua
---@class DebugRegion
---@field start_line number    -- Line of start marker (1-indexed)
---@field end_line number      -- Line of end marker (1-indexed)
---@field is_commented boolean -- Whether content is currently commented
```

### FeatureResult

```lua
---@class FeatureResult
---@field success boolean      -- Whether the operation succeeded
---@field count number         -- Number of items affected
---@field error_msg string|nil -- Error message if failed
```

### BufferContext

```lua
---@class BufferContext
---@field bufnr number         -- Buffer number
---@field filetype string      -- Buffer filetype
---@field line_count number    -- Total lines in buffer
---@field is_valid boolean     -- Whether buffer is valid
```

## Extension Points

### Custom Language Definitions

```lua
require("quill").setup({
  languages = {
    -- Add new filetype
    myfiletype = {
      line = "//",
      block = { "/*", "*/" },
      supports_nesting = false,
      jsx = false,
    },
    -- Override existing
    lua = {
      line = "##",  -- Use ## instead of --
    },
  },
})
```

### Custom Keybindings

```lua
require("quill").setup({
  operators = {
    toggle = "cm",  -- Use custom operator key
  },
  textobjects = {
    inner_block = "ib",
    around_block = "ab",
  },
  mappings = {
    debug_buffer = "<leader>dB",
  },
})
```

### Disable Keymap Groups

```lua
require("quill").setup({
  keymaps = {
    operators = false,
    textobjects = false,
    leader = false,
  },
})
```

### Custom Debug Markers

```lua
require("quill").setup({
  debug = {
    start_marker = "// DEBUG_START",
    end_marker = "// DEBUG_END",
  },
})
```

### Semantic Options

```lua
require("quill").setup({
  semantic = {
    include_decorators = false,
    include_doc_comments = false,
  },
})
```

## Examples

### Toggle Comments Programmatically

```lua
local quill = require("quill")

-- Toggle current line
quill.toggle_line()

-- Toggle multiple lines
quill.toggle_range(10, 15)

-- Toggle visual selection (custom mapping example)
vim.keymap.set("x", "<leader>tc", function()
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  quill.toggle_range(start_line, end_line)
end)
```

### Check Comment State Before Acting

```lua
local quill = require("quill")
local line = vim.fn.line(".")

if quill.is_commented(0, line) then
  print("Line is commented, uncommenting...")
  quill.uncomment(line, line)
else
  print("Line is not commented, commenting...")
  quill.comment(line, line)
end
```

### Align Comments in Function

```lua
-- Create a command to align comments in current function
vim.api.nvim_create_user_command("AlignFunctionComments", function()
  local quill = require("quill")
  -- Get function boundaries (requires TreeSitter)
  local start_line = vim.fn.line(".")
  local end_line = vim.fn.line(".")
  -- ... logic to find function bounds ...
  quill.align(start_line, end_line, { column = 80 })
end, {})
```

### Normalize on Save

```lua
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.lua",
  callback = function()
    require("quill").normalize()
  end,
})
```
