# Quill.nvim Naming Conventions & Code Style

## Function Naming Patterns

| Pattern | Usage | Examples |
|---------|-------|----------|
| `verb_noun()` | Primary action functions | `toggle_line()`, `toggle_range()`, `comment_lines()`, `uncomment_line()` |
| `get_noun()` | Getter/accessor functions | `get_style()`, `get_comment_style()`, `get_filetype_style()`, `get_level()` |
| `is_adjective()` | Boolean predicates | `is_commented()`, `is_available()`, `is_in_group()`, `is_in_jsx_context()` |
| `find_noun()` | Search/discovery functions | `find_debug_regions()`, `find_comment_block_bounds()`, `find_ancestor()` |
| `setup()` | Initialization functions | Module setup functions |
| `_helper_name()` | Internal helpers (underscore prefix) | `_wrap_block_comment()`, `_unwrap_block_comment()` |
| `cmd_name()` | Command handlers (local) | `cmd_debug()`, `cmd_normalize()`, `cmd_align()`, `cmd_convert()` |

## Variable Naming Patterns

| Pattern | Usage | Examples |
|---------|-------|----------|
| `snake_case` | Local variables | `start_line`, `end_line`, `bufnr`, `line_content`, `user_opts` |
| `UPPER_SNAKE_CASE` | Constants (required for all module-level constant tables) | `DEFAULTS`, `FILETYPE_ALIASES`, `LANGUAGE_STYLES`, `BLOCK_PATTERNS`, `VALIDATION_SCHEMA` |
| `noun` or `noun_noun` | Configuration keys | `column`, `min_gap`, `start_marker`, `inner_block` |
| `M` | Module table | Standard Lua module pattern |
| `config` | Configuration state | Local module configuration reference |
| `defaults` | Default values | Default configuration tables |
| `opts` | Options parameter | Function options tables |
| `cfg` | Configuration parameter | Setup configuration parameter |

## Module Naming Patterns

| Pattern | Directory | Examples |
|---------|-----------|----------|
| `quill/init.lua` | Root | Main entry point |
| `quill/core/*.lua` | Core | Fundamental operations: `toggle`, `detect`, `comment`, `undo` |
| `quill/features/*.lua` | Features | Extended features: `debug`, `align`, `normalize`, `convert`, `semantic` |
| `quill/detection/*.lua` | Detection | Detection strategies: `treesitter`, `regex`, `languages` |
| `quill/*.lua` | Root | Utilities and cross-cutting: `config`, `keymaps`, `commands`, `operators`, `textobjects`, `utils` |

## File Naming Patterns

| Pattern | Usage | Examples |
|---------|-------|----------|
| `noun.lua` | Single-responsibility modules | `config.lua`, `keymaps.lua`, `commands.lua` |
| `verb.lua` or `noun.lua` | Core modules | `toggle.lua`, `detect.lua`, `comment.lua`, `undo.lua` |
| `noun.lua` | Detection modules | `treesitter.lua`, `regex.lua`, `languages.lua` |
| `noun_spec.lua` | Test files | `toggle_spec.lua`, `config_spec.lua` |
| `init.lua` | Module entry points | In each directory that acts as a namespace |

## Module Structure Pattern

Every module follows this structure:

```lua
---Module description
---@module quill.module_name

local dependency = require("quill.other_module")

local M = {}

---@class TypeDefinition
---@field field_name type Description

-- Local state (if needed)
local config = { ... }

-- Local helper functions (private)
local function helper_function(...)
  -- implementation
end

-- Public functions
---Documentation with EmmyLua annotations
---@param param type Description
---@return type Description
function M.public_function(param)
  -- implementation
end

-- Setup function (if module has configuration)
---@param cfg table Configuration
function M.setup(cfg)
  -- apply configuration
end

return M
```

## Error Handling Pattern

Two patterns, used in different contexts:

| Pattern | When to Use | Example |
|---------|-------------|---------|
| `error("message")` | Public API boundary validation (invalid arguments from callers) | `utils.assert_numbers("line", line)` |
| `return nil, "message"` | Recoverable internal errors (invalid buffer, empty range) | `return nil, "Invalid buffer"` |

```lua
-- Public API: raise error for invalid arguments (caller's mistake)
function M.some_function(param)
  if type(param) ~= "expected_type" then
    error("param must be a expected_type")
  end
end

-- Internal: return tuple for recoverable errors (not caller's fault)
function M.operation(...)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil, "Invalid buffer"
  end

  return result, nil
end
```

## Undo Grouping Pattern

```lua
-- Using callback style (preferred)
local result, err = undo.with_undo_group(function()
  -- multiple buffer operations
  return result
end)

-- Using manual style (when callback doesn't fit)
undo.start_undo_group()
-- operations
undo.end_undo_group()
```

## Configuration Extension Pattern

```lua
-- Deep merge user options with defaults
config = vim.tbl_deep_extend("force", defaults, user_opts)
```

## LuaDoc Annotation Patterns

```lua
---Function description
---@param name type Description
---@param opts? {key: type}|nil Optional parameter with shape
---@return type|nil Return description
---@return string|nil Error message if operation failed
function M.func_name(name, opts)
```

## Constants Definition Pattern

```lua
-- Use UPPER_SNAKE_CASE for constant tables
local COMMENT_NODE_TYPES = {
  "comment",
  "line_comment",
  "block_comment",
  "doc_comment",
}

-- Create lookup table for O(1) checks
local COMMENT_NODE_SET = {}
for _, v in ipairs(COMMENT_NODE_TYPES) do
  COMMENT_NODE_SET[v] = true
end
```

## Keymap Registration Pattern

```lua
-- Check for conflicts before registering
local function check_conflict(mode, lhs)
  local existing = vim.fn.maparg(lhs, mode)
  return existing ~= ""
end

-- Register with description
vim.keymap.set(mode, lhs, rhs, {
  desc = "Quill: " .. description,
  buffer = bufnr,  -- if buffer-local
  silent = true,
})
```

## Test File Structure

```lua
-- tests/unit/module_spec.lua
describe("module_name", function()
  local module

  before_each(function()
    -- Reset state
    package.loaded["quill.module_name"] = nil
    module = require("quill.module_name")
  end)

  describe("function_name", function()
    it("should do expected behavior", function()
      local result = module.function_name(input)
      assert.equals(expected, result)
    end)

    it("should handle edge case", function()
      -- test edge case
    end)
  end)
end)
```

## Import Organization

```lua
-- 1. Neovim API shortcuts (if used frequently)
local api = vim.api
local fn = vim.fn

-- 2. External dependencies (none currently)

-- 3. Internal dependencies (alphabetical)
local comment = require("quill.core.comment")
local config = require("quill.config")
local detect = require("quill.core.detect")
local undo = require("quill.core.undo")

-- 4. Module table
local M = {}
```

## Buffer/Window Handling Pattern

```lua
-- Always validate buffers
if not vim.api.nvim_buf_is_valid(bufnr) then
  return nil, "Invalid buffer"
end

-- Use 0 for current buffer
local bufnr = bufnr or vim.api.nvim_get_current_buf()

-- Get lines with 0-indexed API
local lines = vim.api.nvim_buf_get_lines(bufnr, start - 1, end_line, false)

-- Set lines with 0-indexed API
vim.api.nvim_buf_set_lines(bufnr, start - 1, end_line, false, new_lines)
```

## Line Number Conventions

```lua
-- Public API: 1-indexed (matches Vim line numbers)
function M.toggle_range(start_line, end_line)
  -- ...
end

-- Internal API calls: Convert to 0-indexed for nvim_buf_* functions
local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
```

## Option Handling Pattern

```lua
-- Merge options with defaults
local function process_opts(opts)
  opts = opts or {}
  return {
    style_type = opts.style_type or nil,
    force_comment = opts.force_comment or false,
    force_uncomment = opts.force_uncomment or false,
  }
end
```

## Guard Clauses Pattern

```lua
function M.some_function(bufnr, line)
  -- Early returns for invalid state
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil, "Invalid buffer"
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if line < 1 or line > line_count then
    return nil, "Line out of range"
  end

  -- Main logic after guards
  -- ...
end
```

## Visibility Rules

| Scope | Naming | Export |
|-------|--------|--------|
| Public API | `M.function_name` | Returned in module table |
| Module-private | `local function _helper()` | Underscore prefix, not exported |
| File-local | `local function helper()` | No underscore, not exported |
| Constants | `local CONSTANT` | Not exported |

## Documentation Standards

```lua
---Short description of the function.
---
---Longer description if needed, explaining behavior,
---edge cases, and important notes.
---
---@param param1 type Description of first parameter
---@param param2? type Optional parameter (note the ?)
---@param opts? {key1: type, key2: type} Options table with shape
---@return type Description of return value
---@return string|nil Error message if operation failed
---@see other_function For related functionality
---@usage
---```lua
---local result = M.function_name(arg1, arg2, { key1 = value })
---```
function M.function_name(param1, param2, opts)
```

## Comments Policy

- No inline comments in code
- Use LuaDoc annotations (`---@param`, `---@return`, `---@class`) for documentation
- Code should be self-documenting through clear naming
- Module-level `---@module` annotations are required

## Shared Infrastructure

| Resource | Location | Usage |
|----------|----------|-------|
| Type definitions | `lua/quill/types.lua` | All `@class` definitions shared across modules |
| Utility functions | `lua/quill/utils.lua` | `escape_pattern`, `is_blank_line`, `is_inside_string`, `get_buffer_context`, `validate_numbers`, `assert_numbers` |

When adding utility functions used by multiple modules, add them to `utils.lua` rather than duplicating across files.
