# quill.nvim

Intelligent comment toggling for Neovim. TreeSitter-aware, 47 languages built-in, zero configuration required.

## Quick Start

### Installation

**lazy.nvim**

```lua
{
  "your-username/quill.nvim",
  event = "VeryLazy",
  opts = {},
}
```

**packer.nvim**

```lua
use {
  "your-username/quill.nvim",
  config = function()
    require("quill").setup()
  end
}
```

### Basic Usage

Toggle comments with `<leader>cc` in normal or visual mode:

```lua
-- Before: cursor on this line, press <leader>cc
local x = 42

-- After:
-- local x = 42
```

Prefix with a count to toggle multiple lines -- `5<leader>cc` toggles 5 lines from the cursor. In visual block mode, Quill uses block comments when the language supports them.

## Features

### Text Objects

Select and operate on comments using standard Vim motions:

| Object | Scope |
|--------|-------|
| `ic` | Inner comment block (content only) |
| `ac` | Around comment block (includes markers) |
| `iC` | Inner comment line (content only) |
| `aC` | Around comment line (entire line) |

Combine with any operator: `dic` (delete), `cac` (change), `yiC` (yank), `vaC` (select).

### JSX-Aware Commenting

In React files (`.jsx`, `.tsx`), Quill detects context and applies the correct comment style automatically:

```jsx
function App() {
  // JavaScript context uses // comments
  return (
    <div>
      {/* JSX context uses {/* */} comments */}
      <span>{value /* Expression context uses /* */ */}</span>
    </div>
  );
}
```

### Debug Regions

Mark code sections with `#region debug` / `#endregion` and toggle them in bulk:

```javascript
// #region debug
console.log("Debug info:", data);
debugger;
// #endregion
```

`<leader>cd` comments out the contents. Run again to uncomment. `<leader>cD` toggles every debug region across all project files at once.

### Normalization

Fix inconsistent comment spacing across a buffer or selection with `<leader>cn`:

```javascript
// Before                    // After
//foo                        // foo
//  bar                      // bar
/*baz*/                      /* baz */
/*   qux   */                /* qux */
```

### Trailing Comment Alignment

Align inline comments to a consistent column. Use `<leader>ca` on a single line, or `:'<,'>Quill align` over a visual selection:

```javascript
// Before                              // After
const x = 1; // short                  const x = 1;               // short
const longVariableName = 2; // value   const longVariableName = 2; // value
```

### Style Conversion

Convert between line and block comment styles with the `:Quill convert` command:

```javascript
// Before :Quill convert block       // After
// first line                         /* first line
// second line                           second line */
```

### Semantic Selection

When commenting functions, Quill can automatically expand the selection to include attached decorators and doc comments. This is controlled by the `semantic` config options:

```python
# With include_decorators = true and include_doc_comments = true,
# commenting the function also includes the decorator and docstring:

@app.route("/api")          # <-- included
def handle_request():
    """Handle the request."""  # <-- included
    return response
```

Supports Python decorators/docstrings and JSDoc comments in JavaScript/TypeScript. See [Configuration](#configuration) for options.

## Keybindings

| Mapping | Mode | Description |
|---------|------|-------------|
| `<leader>cc` | Normal | Toggle comment on current line (count-aware) |
| `<leader>cc` | Visual | Toggle comment on selection |
| `<leader>cd` | Normal | Toggle debug regions in buffer |
| `<leader>cD` | Normal | Toggle debug regions across project |
| `<leader>cn` | Normal | Normalize comment spacing |
| `<leader>ca` | Normal | Align trailing comments on current line |

All keybinding groups can be disabled individually -- see [Configuration](#configuration).

## Commands

| Command | Description |
|---------|-------------|
| `:Quill debug` | Toggle debug regions in buffer |
| `:Quill debug --project` | Preview debug regions across project in quickfix |
| `:Quill debug --list` | List debug regions in quickfix window |
| `:Quill normalize` | Normalize comment spacing in buffer |
| `:'<,'>Quill normalize` | Normalize spacing in selection |
| `:'<,'>Quill align` | Align trailing comments in selection |
| `:'<,'>Quill convert line` | Convert to line comments |
| `:'<,'>Quill convert block` | Convert to block comments |

## Supported Languages

| Category | Languages |
|----------|-----------|
| **Web** | JavaScript, TypeScript, JSX, TSX, HTML, CSS, SCSS, Less |
| **Systems** | C, C++, Rust, Go, Zig, Objective-C |
| **JVM** | Java, Kotlin, Scala |
| **Scripting** | Python, Ruby, Perl, Lua, Bash, Sh, Zsh |
| **Functional** | Haskell, OCaml, Elixir, Erlang, Clojure, Scheme, Racket, Lisp |
| **Mobile** | Swift, Dart |
| **Data/Config** | SQL, JSON, JSONC, YAML, TOML, XML, Markdown |
| **Other** | PHP, C#, R, LaTeX, Vim, Nim |

Languages not listed here fall back to Neovim's `commentstring` automatically.

## Configuration

All options are optional. Shown here with defaults:

```lua
require("quill").setup({
  align = {
    column = 80,
    min_gap = 2,
  },

  debug = {
    start_marker = "#region debug",
    end_marker = "#endregion",
  },

  keymaps = {
    operators = true,
    textobjects = true,
    leader = true,
  },

  operators = {
    toggle = "<leader>cc",
  },

  textobjects = {
    inner_block = "ic",
    around_block = "ac",
    inner_line = "iC",
    around_line = "aC",
  },

  mappings = {
    debug_buffer = "<leader>cd",
    debug_project = "<leader>cD",
    normalize = "<leader>cn",
    align = "<leader>ca",
  },

  warn_on_override = true,

  languages = {},

  jsx = {
    auto_detect = true,
  },

  semantic = {
    include_decorators = true,
    include_doc_comments = true,
  },
})
```

### Custom Languages

Extend or override built-in language definitions:

```lua
require("quill").setup({
  languages = {
    myfiletype = {
      line = "//",
      block = { "/*", "*/" },
      supports_nesting = false,
      jsx = false,
    },
  },
})
```

### Disabling Keymap Groups

```lua
require("quill").setup({
  keymaps = {
    operators = false,
    textobjects = false,
    leader = false,
  },
})
```

## API

```lua
local quill = require("quill")

quill.toggle_line()                            -- Toggle current line
quill.toggle_range(10, 20)                     -- Toggle lines 10-20
quill.comment(5, 15)                           -- Force comment lines 5-15
quill.comment(5, 15, "block")                  -- Force block comment style
quill.uncomment(5, 15)                         -- Force uncomment lines 5-15
quill.get_style(bufnr, line, col)              -- Get CommentStyle at position
quill.is_commented(bufnr, line)                -- Check if line is commented
quill.normalize(bufnr)                         -- Normalize spacing in buffer
quill.align(start_line, end_line, opts)        -- Align trailing comments
quill.toggle_debug("buffer")                   -- Toggle debug regions in buffer
quill.toggle_debug("project")                  -- Toggle debug regions in project
```

All line numbers are 1-indexed. See [docs/usage.md](docs/usage.md) for full API reference with examples.

## Requirements

- Neovim >= 0.10
- TreeSitter (optional -- enhances detection for embedded languages and JSX)

## Documentation

| Document | Description |
|----------|-------------|
| [Usage Guide](docs/usage.md) | Configuration, keybindings, commands, full API, and extension examples |
| [Architecture](docs/architecture.md) | Module structure, dependency graph, design patterns, and data flow |
| [Conventions](docs/conventions.md) | Naming conventions, code style, and contribution guidelines |

## Contributing

Contributions are welcome. Please review [docs/conventions.md](docs/conventions.md) before submitting pull requests.

## License

MIT
