# quill.nvim

Intelligent comment toggling for Neovim. TreeSitter-aware, 46 languages built-in, zero configuration required.

## Features

| Feature | Description |
|---------|-------------|
| **Smart Toggle** | Analyzes current state to comment or uncomment. Count-aware: `5<leader>cc` toggles 5 lines |
| **TreeSitter Detection** | Context-aware language detection for embedded languages, JSX/TSX, and mixed files |
| **Text Objects** | Select and operate on comment blocks (`ic`, `ac`) and comment lines (`iC`, `aC`) |
| **Debug Regions** | Toggle `#region debug` blocks in a single buffer or across an entire project |
| **Normalization** | Fix spacing inconsistencies: `//foo` becomes `// foo`, `/*baz*/` becomes `/* baz */` |
| **Alignment** | Align trailing comments to a consistent column across a selection |
| **Style Conversion** | Convert between line (`//`) and block (`/* */`) comment styles |
| **46 Languages** | Built-in support with automatic fallback to `commentstring` for others |

## Requirements

- Neovim >= 0.10
- TreeSitter (optional, enhances detection accuracy for embedded languages and JSX)

## Installation

### lazy.nvim

```lua
{
  "your-username/quill.nvim",
  event = "VeryLazy",
  opts = {},
}
```

### packer.nvim

```lua
use {
  "your-username/quill.nvim",
  config = function()
    require("quill").setup()
  end
}
```

No configuration is needed. Quill works out of the box with sensible defaults.

## Keybindings

### Toggle

| Mapping | Mode | Description |
|---------|------|-------------|
| `<leader>cc` | Normal | Toggle comment on current line |
| `[count]<leader>cc` | Normal | Toggle comment on N lines (e.g., `5<leader>cc`) |
| `<leader>cc` | Visual | Toggle comment on selection |
| `<leader>cc` | Block Visual | Toggle with block comments when supported |

### Text Objects

| Mapping | Description |
|---------|-------------|
| `ic` | Inner comment block (content only) |
| `ac` | Around comment block (includes markers) |
| `iC` | Inner comment line (content only) |
| `aC` | Around comment line (entire line) |

Use with any operator: `dic` (delete), `cac` (change), `yiC` (yank), `vaC` (select).

### Leader Mappings

| Mapping | Description |
|---------|-------------|
| `<leader>cd` | Toggle debug comments in buffer |
| `<leader>cD` | Toggle debug comments across project |
| `<leader>cn` | Normalize comment spacing in buffer |
| `<leader>ca` | Align trailing comments |

## Commands

| Command | Description |
|---------|-------------|
| `:Quill debug` | Toggle debug regions in buffer |
| `:Quill debug --project` | Toggle debug regions across project |
| `:Quill debug --list` | List debug regions in quickfix window |
| `:Quill normalize` | Normalize comment spacing in buffer |
| `:'<,'>Quill normalize` | Normalize comment spacing in selection |
| `:'<,'>Quill align` | Align trailing comments in selection |
| `:'<,'>Quill convert line` | Convert selection to line comments |
| `:'<,'>Quill convert block` | Convert selection to block comments |

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

Languages not in this list fall back to Neovim's `commentstring` option automatically.

## JSX Support

Quill detects JSX context in React files (`.jsx`, `.tsx`) and applies the correct comment style per region:

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

## Debug Regions

Mark code sections with `#region debug` / `#endregion` markers and toggle them in bulk:

```javascript
// #region debug
console.log("Debug info:", data);
debugger;
// #endregion
```

`:Quill debug` comments out the contents. Run again to uncomment. Use `:Quill debug --project` to toggle every debug region across all project files at once.

## Normalization

Fix inconsistent comment spacing across a buffer or selection:

```javascript
// Before                    // After :Quill normalize
//foo                        // foo
//  bar                      // bar
/*baz*/                      /* baz */
/*   qux   */                /* qux */
```

## Trailing Comment Alignment

Align inline comments to a consistent column:

```javascript
// Before                              // After :'<,'>Quill align
const x = 1; // short                  const x = 1;               // short
const longVariableName = 2; // value   const longVariableName = 2; // value
```

## Configuration

All options are optional. Shown here with their defaults:

```lua
require("quill").setup({
  align = {
    column = 80,                     -- Target column for trailing comment alignment
    min_gap = 2,                     -- Minimum spaces before aligned comment
  },

  debug = {
    start_marker = "#region debug",  -- Debug region start marker
    end_marker = "#endregion",       -- Debug region end marker
  },

  keymaps = {
    operators = true,                -- Enable <leader>cc toggle mappings
    textobjects = true,              -- Enable ic, ac, iC, aC text objects
    leader = true,                   -- Enable <leader>cd, cD, cn, ca mappings
  },

  operators = {
    toggle = "<leader>cc",           -- Toggle operator mapping
  },

  textobjects = {
    inner_block = "ic",              -- Inner comment block
    around_block = "ac",             -- Around comment block
    inner_line = "iC",               -- Inner comment line
    around_line = "aC",              -- Around comment line
  },

  mappings = {
    debug_buffer = "<leader>cd",     -- Toggle debug in buffer
    debug_project = "<leader>cD",    -- Toggle debug in project
    normalize = "<leader>cn",        -- Normalize spacing
    align = "<leader>ca",            -- Align trailing comments
  },

  warn_on_override = true,           -- Warn when overriding existing keymaps

  languages = {},                    -- Custom language definitions (extends built-in)

  jsx = {
    auto_detect = true,              -- Auto-detect JSX context in React files
  },

  semantic = {
    include_decorators = true,       -- Include decorators when selecting functions
    include_doc_comments = true,     -- Include doc comments when selecting functions
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

### Disable Keymap Groups

```lua
require("quill").setup({
  keymaps = {
    operators = false,    -- Disable toggle mappings
    textobjects = false,  -- Disable text objects
    leader = false,       -- Disable leader mappings
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

## Documentation

| Document | Description |
|----------|-------------|
| [Usage Guide](docs/usage.md) | Configuration reference, keybindings, commands, full API, and extension examples |
| [Architecture](docs/architecture.md) | Module structure, dependency graph, design patterns, and data flow |
| [Conventions](docs/conventions.md) | Naming conventions, code style, and contribution guidelines |

## Contributing

Contributions are welcome. Please review [docs/conventions.md](docs/conventions.md) before submitting pull requests.

## License

MIT
