# Architecture Tightening Refactoring Plan

**Date**: 2026-02-05
**Status**: Draft
**Estimated Phases**: 5

## Executive Summary

This plan addresses architectural improvements identified through deep analysis of the quill.nvim codebase. The refactoring focuses on:

1. **Eliminating code duplication** (5 copies of `escape_pattern()`, 15+ buffer validation blocks)
2. **Establishing type contracts** (centralized types, consistent LuaDoc annotations)
3. **Fixing dead code** (placeholder keymaps that should wire to real implementations)
4. **Standardizing naming** (constants to `UPPER_SNAKE_CASE`)
5. **Creating abstractions** (buffer context, keymap registration)

---

## Dependency Graph

```
Phase 1: Foundation
    └── types.lua (new)
    └── utils.lua (populated)
           │
           ▼
Phase 2: Quick Wins
    ├── keymaps.lua (wire to features)
    ├── constants renamed (UPPER_SNAKE_CASE)
    └── deprecated function removed
           │
           ▼
Phase 3: Boilerplate Elimination
    ├── Replace escape_pattern() calls (5 files)
    ├── Replace buffer validation (7+ files)
    └── init.lua validation helpers
           │
           ▼
Phase 4: Keymap Abstraction
    └── Unified register_keymap() function
           │
           ▼
Phase 5: Config Validation Refactor
    └── Schema-based validation
```

---

## Phase 1: Foundation

**Goal**: Create centralized types and utilities that other phases depend on.

### Task 1.1: Create `types.lua`

**File**: `lua/quill/types.lua` (new)

```lua
---Centralized type definitions for quill.nvim
---@module quill.types

---@class CommentStyle
---@field line string|nil Line comment marker (e.g., "//", "#", "--")
---@field block string[]|nil Block comment markers [start, end] (e.g., {"/*", "*/"})
---@field supports_nesting boolean|nil Whether block comments can nest
---@field jsx boolean|nil Whether this is JSX context

---@class CommentMarkers
---@field start_pos number Start position of comment marker (1-indexed)
---@field end_pos number End position of comment marker (1-indexed)
---@field marker_type "line"|"block" Type of comment marker

---@class DebugRegion
---@field start_line number Line of start marker (1-indexed)
---@field end_line number Line of end marker (1-indexed)
---@field is_commented boolean Whether content is currently commented

---@class FeatureResult
---@field success boolean Whether the operation succeeded
---@field count number Number of items affected
---@field error_msg string|nil Error message if failed

---@class BufferContext
---@field bufnr number Buffer number
---@field filetype string Buffer filetype
---@field line_count number Total lines in buffer
---@field is_valid boolean Whether buffer is valid

return {}
```

**Rationale**: Centralizes type definitions currently scattered across:
- `detection/regex.lua` (CommentMarkers)
- `detection/languages.lua` (CommentStyle)
- `features/debug.lua` (DebugRegion)

### Task 1.2: Populate `utils.lua`

**File**: `lua/quill/utils.lua`

```lua
---Shared utility functions for quill.nvim
---@module quill.utils

local M = {}

---Escape special Lua pattern characters for literal matching
---@param str string String to escape
---@return string Escaped pattern string
function M.escape_pattern(str)
  return str:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1")
end

---Check if a line is blank (empty or whitespace only)
---@param line string Line to check
---@return boolean
function M.is_blank_line(line)
  return not line or line:match("^%s*$") ~= nil
end

---Check if a position is inside a quoted string
---Uses simple state machine to track quote context
---Handles escaped quotes (\", \')
---@param line string Line content
---@param pos number Position to check (1-indexed)
---@return boolean
function M.is_inside_string(line, pos)
  local in_single = false
  local in_double = false
  local escaped = false

  for i = 1, pos - 1 do
    local char = line:sub(i, i)

    if escaped then
      escaped = false
    elseif char == "\\" then
      escaped = true
    elseif char == '"' and not in_single then
      in_double = not in_double
    elseif char == "'" and not in_double then
      in_single = not in_single
    end
  end

  return in_single or in_double
end

---Validate buffer and return context
---@param bufnr number|nil Buffer number (0 or nil for current)
---@return BufferContext|nil context Returns nil if buffer invalid
function M.get_buffer_context(bufnr)
  bufnr = bufnr or 0

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  return {
    bufnr = bufnr,
    filetype = vim.bo[bufnr].filetype,
    line_count = vim.api.nvim_buf_line_count(bufnr),
    is_valid = true,
  }
end

---Get lines from buffer with bounds checking
---@param bufnr number Buffer number
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed, inclusive)
---@return string[]|nil lines Returns nil if invalid range
function M.get_lines(bufnr, start_line, end_line)
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  if start_line < 1 or end_line > line_count or start_line > end_line then
    return nil
  end

  return vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
end

---Validate that parameters are numbers
---@param name string Parameter name for error message
---@param ... any Values to check
---@return boolean valid
---@return string|nil error_msg
function M.validate_numbers(name, ...)
  local values = {...}
  for i, v in ipairs(values) do
    if type(v) ~= "number" then
      return false, string.format("%s[%d] must be a number, got %s", name, i, type(v))
    end
  end
  return true, nil
end

return M
```

**Files that will import from utils.lua**:
- `detection/regex.lua` - remove local `escape_pattern()` and `is_inside_string()`
- `features/debug.lua` - remove local `escape_pattern()`
- `features/normalize.lua` - remove local `escape_pattern()`
- `features/convert.lua` - remove local `escape_pattern()`
- `features/semantic.lua` - remove local `is_blank_line()`
- `features/align.lua` - use `is_inside_string()` instead of inline logic

---

## Phase 2: Quick Wins

**Goal**: Fix obvious issues that don't require architectural changes.

### Task 2.1: Wire Keymaps to Feature Implementations

**File**: `lua/quill/keymaps.lua`

**Changes** (lines 157-184):

```lua
-- BEFORE (placeholder):
M.register_leader(cfg.mappings.debug_buffer, function()
  vim.notify("[quill] Debug buffer toggle not yet implemented", vim.log.levels.INFO)
end, { ... })

-- AFTER (wired to implementation):
local debug = require("quill.features.debug")
M.register_leader(cfg.mappings.debug_buffer, function()
  debug.toggle_buffer()
end, {
  desc = "Toggle debug comments in buffer",
})
```

**Full replacement for lines 157-184**:

```lua
-- Register leader keymaps
if cfg.keymaps.leader then
  local debug = require("quill.features.debug")
  local normalize = require("quill.features.normalize")
  local align = require("quill.features.align")

  M.register_leader(cfg.mappings.debug_buffer, function()
    debug.toggle_buffer()
  end, {
    desc = "Toggle debug comments in buffer",
  })

  M.register_leader(cfg.mappings.debug_project, function()
    debug.toggle_project()
  end, {
    desc = "Toggle debug comments in project",
  })

  M.register_leader(cfg.mappings.normalize, function()
    normalize.normalize_buffer()
  end, {
    desc = "Normalize comment spacing",
  })

  M.register_leader(cfg.mappings.align, function()
    local line = vim.fn.line(".")
    align.align_lines(0, line, line)
  end, {
    desc = "Align trailing comments",
  })
end
```

### Task 2.2: Rename Constants to UPPER_SNAKE_CASE

**File**: `lua/quill/detection/languages.lua`

| Line | Current | New |
|------|---------|-----|
| 11 | `local filetype_aliases` | `local FILETYPE_ALIASES` |
| 21 | `local styles` | `local LANGUAGE_STYLES` |
| 426 | `local block_patterns` | `local BLOCK_PATTERNS` |

**File**: `lua/quill/features/semantic.lua`

| Line | Current | New |
|------|---------|-----|
| 12 | `local decorator_patterns` | `local DECORATOR_PATTERNS` |
| 19 | `local function_patterns` | `local FUNCTION_PATTERNS` |

**File**: `lua/quill/config.lua`

| Line | Current | New |
|------|---------|-----|
| 3 | `local defaults` | `local DEFAULTS` |

### Task 2.3: Remove Deprecated Function

**File**: `lua/quill/operators.lua`

**Remove** lines 69-75:

```lua
---@deprecated Use toggle_visual_range instead
function M.toggle_visual()
  vim.notify(
    "[quill] toggle_visual() is deprecated, use toggle_visual_range() instead",
    vim.log.levels.WARN
  )
  M.toggle_visual_range()
end
```

---

## Phase 3: Boilerplate Elimination

**Goal**: Replace duplicated code with calls to `utils.lua`.

### Task 3.1: Update `detection/regex.lua`

**Changes**:
1. Remove local `escape_pattern()` (lines 11-13)
2. Remove local `is_inside_string()` (lines 21-41)
3. Add import: `local utils = require("quill.utils")`
4. Replace all calls:
   - `escape_pattern(...)` → `utils.escape_pattern(...)`
   - `is_inside_string(...)` → `utils.is_inside_string(...)`

**Affected lines**: 63, 70, 79, 80, 113, 114, 141, 176, 177, 210

### Task 3.2: Update `features/debug.lua`

**Changes**:
1. Remove local `escape_pattern()` (lines 32-34)
2. Add import: `local utils = require("quill.utils")`
3. Replace buffer validation pattern (lines 42-44):

```lua
-- BEFORE:
bufnr = bufnr or 0
if not vim.api.nvim_buf_is_valid(bufnr) then
  return {}
end

-- AFTER:
local ctx = utils.get_buffer_context(bufnr)
if not ctx then
  return {}
end
bufnr = ctx.bufnr
```

4. Replace all `escape_pattern(...)` → `utils.escape_pattern(...)`

**Affected lines**: 48, 49, 97-101

### Task 3.3: Update `features/normalize.lua`

**Changes**:
1. Remove local `escape_pattern()` (lines 16-18)
2. Add import: `local utils = require("quill.utils")`
3. Replace buffer validation patterns
4. Replace all `escape_pattern(...)` → `utils.escape_pattern(...)`

**Affected lines**: 35, 36, 44, 63, 64, 206-208, 250-252

### Task 3.4: Update `features/convert.lua`

**Changes**:
1. Remove inline `escape_pattern()` usage (lines 36-38)
2. Add import: `local utils = require("quill.utils")`
3. Replace all `escape_pattern(...)` → `utils.escape_pattern(...)`

### Task 3.5: Update `features/semantic.lua`

**Changes**:
1. Remove local `is_blank_line()` (lines 43-46)
2. Add import: `local utils = require("quill.utils")`
3. Replace all `is_blank_line(...)` → `utils.is_blank_line(...)`

### Task 3.6: Update `init.lua` with Validation Helpers

**Current pattern** (repeated 8 times):
```lua
if type(start_line) ~= "number" or type(end_line) ~= "number" then
  error("start_line and end_line must be numbers")
end
```

**Replacement pattern**:
```lua
local utils = require("quill.utils")

function M.toggle_range(start_line, end_line)
  local ok, err = utils.validate_numbers("lines", start_line, end_line)
  if not ok then
    error(err)
  end
  -- ...
end
```

---

## Phase 4: Keymap Abstraction

**Goal**: Unify the three near-identical keymap registration functions.

### Task 4.1: Refactor `keymaps.lua`

**Current state**: Three functions with 90% identical code:
- `register_operator()` (lines 50-65)
- `register_textobject()` (lines 72-93)
- `register_leader()` (lines 100-115)

**New unified function**:

```lua
---Register a keymap with optional conflict checking
---@param modes string|string[] Mode(s) to register in
---@param lhs string Left-hand side of mapping
---@param rhs string|function Right-hand side of mapping
---@param opts table|nil Keymap options
---@return nil
function M.register(modes, lhs, rhs, opts)
  opts = opts or {}
  local cfg = config.get()

  -- Normalize modes to table
  if type(modes) == "string" then
    modes = { modes }
  end

  -- Check for conflicts if enabled
  if cfg.warn_on_override then
    for _, mode in ipairs(modes) do
      local existing = M.check_conflict(mode, lhs)
      if existing then
        M.warn_override(mode, lhs, existing)
      end
    end
  end

  -- Register in all modes
  for _, mode in ipairs(modes) do
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

-- Convenience wrappers (optional, for backward compatibility)
function M.register_operator(lhs, rhs, opts)
  M.register("n", lhs, rhs, opts)
end

function M.register_textobject(lhs, rhs, opts)
  M.register({ "o", "x" }, lhs, rhs, opts)
end

function M.register_leader(lhs, rhs, opts)
  M.register("n", lhs, rhs, opts)
end
```

---

## Phase 5: Config Validation Refactor

**Goal**: Replace repetitive validation with schema-based approach.

### Task 5.1: Create Validation Schema

**File**: `lua/quill/config.lua`

**New approach**:

```lua
---@class ValidationRule
---@field type string Expected type ("string", "number", "boolean", "table")
---@field required boolean|nil Whether field is required
---@field fields table<string, ValidationRule>|nil Nested field rules (for tables)

local VALIDATION_SCHEMA = {
  align = {
    type = "table",
    fields = {
      column = { type = "number" },
      min_gap = { type = "number" },
    },
  },
  debug = {
    type = "table",
    fields = {
      start_marker = { type = "string" },
      end_marker = { type = "string" },
    },
  },
  keymaps = {
    type = "table",
    fields = {
      operators = { type = "boolean" },
      textobjects = { type = "boolean" },
      leader = { type = "boolean" },
    },
  },
  mappings = {
    type = "table",
    fields = {
      debug_buffer = { type = "string" },
      debug_project = { type = "string" },
      normalize = { type = "string" },
      align = { type = "string" },
    },
  },
  operators = {
    type = "table",
    fields = {
      toggle = { type = "string" },
    },
  },
  textobjects = {
    type = "table",
    fields = {
      inner_block = { type = "string" },
      around_block = { type = "string" },
      inner_line = { type = "string" },
      around_line = { type = "string" },
    },
  },
  warn_on_override = { type = "boolean" },
  languages = { type = "table" },
  jsx = {
    type = "table",
    fields = {
      auto_detect = { type = "boolean" },
    },
  },
  semantic = {
    type = "table",
    fields = {
      include_decorators = { type = "boolean" },
      include_doc_comments = { type = "boolean" },
    },
  },
}

---Validate a value against a schema rule
---@param value any Value to validate
---@param rule ValidationRule Schema rule
---@param path string Current path for error messages
---@return boolean valid
---@return string|nil error_msg
local function validate_rule(value, rule, path)
  if value == nil then
    return true, nil  -- Optional fields can be nil
  end

  if type(value) ~= rule.type then
    return false, string.format("%s: expected %s, got %s", path, rule.type, type(value))
  end

  if rule.type == "table" and rule.fields then
    for key, field_rule in pairs(rule.fields) do
      local ok, err = validate_rule(value[key], field_rule, path .. "." .. key)
      if not ok then
        return false, err
      end
    end
  end

  return true, nil
end

function M.validate(opts)
  if type(opts) ~= "table" then
    return false
  end

  for key, rule in pairs(VALIDATION_SCHEMA) do
    local ok, err = validate_rule(opts[key], rule, key)
    if not ok then
      vim.notify("[quill] Config error: " .. err, vim.log.levels.ERROR)
      return false
    end
  end

  return true
end
```

**Benefits**:
- Reduces ~100 lines of repetitive validation to ~50 lines of schema
- Self-documenting: schema shows all valid config options
- Consistent error messages
- Easy to extend for new options

---

## Implementation Order & Agent Allocation

| Phase | Task | Execution | Agent | Model |
|-------|------|-----------|-------|-------|
| 1 | 1.1 Create types.lua | Sequential | Coder | sonnet |
| 1 | 1.2 Populate utils.lua | Sequential | Coder | sonnet |
| 2 | 2.1 Wire keymaps | Parallel | Coder | haiku |
| 2 | 2.2 Rename constants | Parallel | Coder | haiku |
| 2 | 2.3 Remove deprecated | Parallel | Coder | haiku |
| 3 | 3.1-3.5 Update imports | Parallel (5 agents) | Coder | haiku |
| 3 | 3.6 Update init.lua | Sequential | Coder | sonnet |
| 4 | 4.1 Keymap abstraction | Sequential | ME | - |
| 5 | 5.1 Config schema | Sequential | ME | - |

**Validation Checkpoints**:
- After Phase 1: Run `./scripts/run_tests.sh`
- After Phase 2: Run `./scripts/run_tests.sh`
- After Phase 3: Run `./scripts/run_tests.sh`
- After Phase 4: Run `./scripts/run_tests.sh`
- After Phase 5: Run `./scripts/run_tests.sh`

---

## Risk Assessment

| Phase | Risk | Mitigation |
|-------|------|------------|
| 1 | Low - New files, no changes | N/A |
| 2 | Low - Simple wiring/renames | Git commit after each task |
| 3 | Medium - Many files touched | Parallel agents, non-overlapping files |
| 4 | Low - Single file refactor | Keep backward-compat wrappers |
| 5 | Medium - Validation behavior change | Comprehensive test coverage |

---

## Success Criteria

1. **All tests pass** after each phase
2. **No duplicate `escape_pattern()`** in codebase (grep returns 1 result in utils.lua)
3. **Keymaps functional** - `<leader>cd`, `<leader>cD`, `<leader>cn`, `<leader>ca` work
4. **Constants renamed** - grep for lowercase pattern names returns 0
5. **Type coverage** - All public functions have `@param` and `@return` annotations

---

## Files Modified Summary

| File | Phase | Changes |
|------|-------|---------|
| `lua/quill/types.lua` | 1 | NEW |
| `lua/quill/utils.lua` | 1 | Populated |
| `lua/quill/keymaps.lua` | 2, 4 | Wire features, unify registration |
| `lua/quill/operators.lua` | 2 | Remove deprecated |
| `lua/quill/config.lua` | 2, 5 | Rename constant, schema validation |
| `lua/quill/init.lua` | 3 | Use validation helpers |
| `lua/quill/detection/languages.lua` | 2 | Rename constants |
| `lua/quill/detection/regex.lua` | 3 | Use utils |
| `lua/quill/features/debug.lua` | 3 | Use utils |
| `lua/quill/features/normalize.lua` | 3 | Use utils |
| `lua/quill/features/convert.lua` | 3 | Use utils |
| `lua/quill/features/semantic.lua` | 2, 3 | Rename constants, use utils |
| `lua/quill/features/align.lua` | 3 | Use utils |
