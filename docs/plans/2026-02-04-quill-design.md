# nvim-quill Design Document

## Overview

**Plugin Name:** nvim-quill

**Purpose:** A standalone Neovim plugin for clean, accurate commenting across all programming languages with semantic awareness and novel features not found in existing solutions.

### Core Philosophy

- **Zero-config experience** — Works out of the box with sensible defaults
- **Progressive enhancement** — Full features with TreeSitter, graceful fallback without
- **Vim-native feel** — Operator-based grammar (`<leader>c`) feels like built-in functionality
- **Silent intelligence** — Plugin makes smart decisions without prompting user
- **Never break code** — Commenting operations always produce valid syntax

### Key Differentiators

| Feature | Comment.nvim | vim-commentary | nvim-quill |
|---------|--------------|----------------|-----------------|
| Semantic text objects (`ic`, `ac`) | ✗ | ✗ | ✓ |
| Debug region toggling | ✗ | ✗ | ✓ |
| Comment normalization | ✗ | ✗ | ✓ |
| Trailing comment alignment | ✗ | ✗ | ✓ |
| Decorator-aware function commenting | ✗ | ✗ | ✓ |
| Smart nested block handling | Partial | ✗ | ✓ |
| JSX context auto-detection | Plugin required | ✗ | Built-in |

---

## Architecture

### Directory Structure

```
nvim-quill/
├── lua/
│   └── quill/
│       ├── init.lua              # Entry point, setup(), public API
│       ├── config.lua            # Configuration management
│       ├── operators.lua         # <leader>c operator implementation
│       ├── textobjects.lua       # ic, ac, iC, aC definitions
│       ├── commands.lua          # :Quill command dispatcher
│       │
│       ├── core/
│       │   ├── comment.lua       # Core comment/uncomment logic
│       │   ├── detect.lua        # Comment style detection (TS + fallback)
│       │   ├── toggle.lua        # Toggle logic with smart uncomment
│       │   └── undo.lua          # Undo grouping management
│       │
│       ├── features/
│       │   ├── debug.lua         # Debug region (#region) handling
│       │   ├── normalize.lua     # Comment normalization
│       │   ├── align.lua         # Trailing comment alignment
│       │   ├── convert.lua       # Style conversion (line ↔ block)
│       │   └── semantic.lua      # Function/decorator commenting
│       │
│       ├── detection/
│       │   ├── treesitter.lua    # TreeSitter-based detection
│       │   ├── regex.lua         # Regex fallback detection
│       │   └── languages.lua     # Language-specific rules & overrides
│       │
│       ├── keymaps.lua           # Keymap registration & conflict handling
│       └── utils.lua             # Shared utilities
│
├── plugin/
│   └── quill.lua            # Auto-load, lazy setup
│
└── tests/
    ├── unit/                     # Unit tests per module
    ├── integration/              # Full workflow tests
    └── languages/                # Per-language comment tests
```

### Module Responsibilities

| Module | Responsibility |
|--------|----------------|
| `init.lua` | Public API, `setup()`, lazy loading orchestration |
| `config.lua` | Merge user config with defaults, validation |
| `core/detect.lua` | Determine correct comment syntax for cursor position |
| `core/comment.lua` | Apply/remove comment markers to lines |
| `core/toggle.lua` | Smart toggle: detect state, apply inverse |
| `features/*` | Isolated feature implementations |
| `detection/*` | TreeSitter and fallback detection strategies |

### Dependency Graph

```
init.lua
    ├── config.lua
    ├── keymaps.lua
    ├── operators.lua ──────┐
    ├── textobjects.lua ────┼── core/*
    ├── commands.lua ───────┤
    └── features/* ─────────┘
                            │
                    detection/*
```

---

## Detection System

### Overview

The detection system determines the correct comment syntax for any cursor position. It uses TreeSitter when available, with intelligent regex fallback.

### Detection Flow

```
get_comment_style(bufnr, line, col)
    │
    ├─ TreeSitter parser available?
    │   │
    │   YES ──► Get node at cursor
    │   │       │
    │   │       ├─ Identify language of node (handles embedded languages)
    │   │       ├─ Check for special contexts (JSX, template strings)
    │   │       └─ Return language-specific comment style
    │   │
    │   NO ───► Fallback path
    │           │
    │           ├─ Get buffer filetype
    │           ├─ Check vim.bo.commentstring
    │           ├─ Apply language overrides from config
    │           └─ Return filetype-based comment style
    │
    └─► { line = "//", block = { "/*", "*/" }, ... }
```

### Comment Style Data Structure

```lua
---@class CommentStyle
---@field line string|nil           Line comment marker (e.g., "//", "#")
---@field block { string, string }|nil  Block comment pair (e.g., {"/*", "*/"})
---@field supports_nesting boolean  Can block comments nest?
---@field jsx boolean               Is this a JSX context?
```

### Embedded Language Support

TreeSitter enables accurate detection in:
- JavaScript inside HTML `<script>` tags
- CSS inside HTML `<style>` tags
- SQL inside Python/Ruby strings
- JSX expressions in TSX files

### Fallback Detection

When TreeSitter unavailable, uses `vim.bo.commentstring` with language-specific overrides from configuration.

---

## Core Operations

### Toggle Logic

```
toggle_comment(lines, style)
    │
    ├─ Analyze lines: are they commented?
    │   │
    │   ├─ All lines commented ──► Uncomment all
    │   ├─ No lines commented ───► Comment all
    │   └─ Mixed ────────────────► Comment all (treat as uncommenting partial)
    │
    └─► Apply operation with single undo group
```

### Comment Detection

- **TreeSitter path:** Check if cursor node or ancestors are `comment` type
- **Regex fallback:** Pattern match against comment markers, skipping quoted strings

### Block Comment Nesting (Priority Chain)

When block commenting a selection that contains existing block comments:

1. **Language supports nesting?** (Rust, D, Scala) → Nest naturally
2. **Language has line comments?** (JS, Python, most languages) → Fall back to line comments
3. **Block-only language?** (CSS, HTML) → Comment each line separately as individual blocks

### Undo Behavior

All multi-line operations wrapped in single undo group. One `u` restores all changes.

---

## Operators & Text Objects

### Operator (`<leader>c`)

| Mapping | Action |
|---------|--------|
| `<leader>c{motion}` | Toggle comment with motion |
| `<leader>cc` | Toggle current line |
| `<leader>c` (visual) | Toggle selection |

Composable with all Vim motions: `<leader>cip`, `<leader>c3j`, `<leader>c%`, `<leader>caf`, etc.

### Text Objects

| Mapping | Selects |
|---------|---------|
| `ic` | Inner comment block (contiguous lines) |
| `ac` | Around comment block (includes markers) |
| `iC` | Inner single comment line |
| `aC` | Around single comment line |

Works with all operators: `dic`, `cic`, `yic`, `vic`, etc.

---

## Features

### Debug Region Handling

Toggle `#region debug` / `#endregion` blocks:

```javascript
// #region debug
console.log('debugging value:', x);
debugger;
// #endregion
```

- `<leader>cd` — Toggle all debug regions in buffer (immediate)
- `<leader>cD` — Toggle all debug regions in project (with confirmation, quickfix preview)
- `:Quill debug --list` — Show all debug regions without toggling

### Comment Normalization

Fixes spacing inconsistencies:

- `//foo` → `// foo`
- `/*foo*/` → `/* foo */`
- `//  foo` → `// foo`

Command: `<leader>cn` or `:Quill normalize`

### Trailing Comment Alignment

Aligns trailing comments to consistent column:

```lua
-- Before:
local x = 1      -- short
local foo = "bar" -- longer
local y = 2  -- another

-- After (aligned to longest + min_gap, capped at column 80):
local x = 1       -- short
local foo = "bar" -- longer
local y = 2       -- another
```

Command: `<leader>ca` (visual selection) or `:Quill align`

### Style Conversion

Convert between line and block comment styles:

- `:Quill convert line` — Convert selection to `//` style
- `:Quill convert block` — Convert selection to `/* */` style

Preserves original style during normalization (conversion is explicit).

### Semantic Function Commenting

`<leader>caf` (comment around function) includes attached decorators:

```python
@dataclass
@frozen
def my_function():  # <leader>caf comments all 4 lines
    pass
```

Smart detection: includes decorators with no blank line separation, excludes if separated.

### JSX Context Detection

Automatically uses `{/* */}` inside JSX, `//` outside:

```tsx
const x = 1;           // <leader>cc here → // const x = 1;
return (
  <div>
    <span>Hello</span> {/* <leader>cc here → {/* <span>Hello</span> */} */}
  </div>
);
```

---

## Configuration

### Default Configuration

```lua
require('quill').setup({
  -- Alignment settings
  align = {
    column = 80,        -- Max column for trailing comment alignment
    min_gap = 2,        -- Minimum spaces before trailing comment
  },

  -- Debug region markers
  debug = {
    start_marker = "#region debug",
    end_marker = "#endregion",
  },

  -- Keymap settings
  keymaps = {
    operators = true,    -- <leader>c, <leader>cc
    textobjects = true,  -- ic, ac, iC, aC
    leader = true,       -- <leader>c* mappings
  },

  -- Leader mappings
  mappings = {
    debug_buffer = "<leader>cd",
    debug_project = "<leader>cD",
    normalize = "<leader>cn",
    align = "<leader>ca",
  },

  -- Operator mappings
  operators = {
    toggle = "<leader>c",
    toggle_line = "<leader>cc",
  },

  -- Text object mappings
  textobjects = {
    inner_block = "ic",
    around_block = "ac",
    inner_line = "iC",
    around_line = "aC",
  },

  -- Conflict handling
  warn_on_override = true,

  -- Per-language overrides
  languages = {
    -- python = { line = "#", block = { '"""', '"""' } },
  },

  -- JSX handling
  jsx = {
    auto_detect = true,
  },

  -- Semantic features
  semantic = {
    include_decorators = true,
    include_doc_comments = true,
  },
})
```

### Keymap Behavior

- **Auto-enable:** All keymaps active by default (zero-config)
- **Conflict handling:** Warns and overrides existing mappings, with option to silence
- **Granular control:** Disable by category (`keymaps.operators = false`)

---

## Command Reference

### Keymaps

| Mapping | Mode | Action |
|---------|------|--------|
| `<leader>c{motion}` | Normal | Toggle comment with motion |
| `<leader>cc` | Normal | Toggle current line |
| `<leader>c` | Visual | Toggle selection |
| `ic` | Operator-pending, Visual | Inner comment block |
| `ac` | Operator-pending, Visual | Around comment block |
| `iC` | Operator-pending, Visual | Inner comment line |
| `aC` | Operator-pending, Visual | Around comment line |
| `<leader>cd` | Normal | Toggle debug regions (buffer) |
| `<leader>cD` | Normal | Toggle debug regions (project) |
| `<leader>cn` | Normal | Normalize comments |
| `<leader>ca` | Visual | Align trailing comments |

### Commands

| Command | Action |
|---------|--------|
| `:Quill debug` | Toggle debug regions (buffer) |
| `:Quill debug --project` | Toggle debug regions (project) |
| `:Quill debug --list` | List debug regions (quickfix) |
| `:Quill normalize` | Normalize comments in buffer |
| `:'<,'>Quill align` | Align trailing comments in selection |
| `:'<,'>Quill convert line` | Convert selection to line comments |
| `:'<,'>Quill convert block` | Convert selection to block comments |

---

## Public API

```lua
local quill = require('quill')

-- Toggle operations
quill.toggle_line()
quill.toggle_range(start_line, end_line)

-- Explicit comment/uncomment
quill.comment(start_line, end_line, style)  -- style: "line"|"block"
quill.uncomment(start_line, end_line)

-- Query functions
quill.get_style(bufnr, line, col)  -- Returns CommentStyle
quill.is_commented(bufnr, line)    -- Returns boolean

-- Feature functions
quill.normalize(bufnr)
quill.align(start_line, end_line, opts)
quill.toggle_debug(scope)  -- scope: "buffer"|"project"
```

---

## Testing Strategy

### Test Structure

```
tests/
├── unit/
│   ├── detect_spec.lua       # Comment style detection
│   ├── toggle_spec.lua       # Toggle logic
│   ├── comment_spec.lua      # Commenting implementation
│   ├── textobjects_spec.lua  # Text object selection
│   ├── normalize_spec.lua    # Normalization logic
│   └── align_spec.lua        # Alignment logic
│
├── integration/
│   ├── operator_spec.lua     # Full <leader>c operator workflow
│   ├── debug_spec.lua        # Debug region toggling
│   └── jsx_spec.lua          # JSX context detection
│
└── languages/
    ├── lua_spec.lua
    ├── python_spec.lua
    ├── javascript_spec.lua
    ├── typescript_spec.lua
    ├── css_spec.lua
    ├── html_spec.lua
    ├── rust_spec.lua
    └── go_spec.lua
```

### Key Test Cases

- Toggle correctly detects commented vs uncommented lines
- Nested block comments handled via priority chain
- JSX context switches between `{/* */}` and `//`
- Text objects select correct ranges
- Debug regions toggle correctly buffer and project-wide
- Normalization fixes spacing without changing style
- Alignment respects column cap and minimum gap
- Decorators included when attached, excluded when separated

---

## Implementation Phases

### Phase 1: Core Foundation
- Detection system (TreeSitter + fallback)
- Basic toggle logic
- `<leader>c` operator and `<leader>cc`
- Single undo grouping

### Phase 2: Text Objects
- `ic`/`ac` block text objects
- `iC`/`aC` line text objects
- Contiguous comment detection

### Phase 3: Advanced Features
- Debug region handling
- Comment normalization
- Trailing comment alignment
- Style conversion

### Phase 4: Semantic Features
- Function commenting with decorators
- Doc comment inclusion
- JSX context detection

### Phase 5: Polish
- Comprehensive configuration
- Conflict handling with warnings
- Full test coverage
- Documentation
