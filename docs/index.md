# Quill.nvim Documentation

Intelligent comment toggling for Neovim with TreeSitter-based context detection, 46 built-in languages, and advanced features like debug region management and trailing comment alignment.

## Documentation

| Document | Audience | Description |
|----------|----------|-------------|
| [Usage Guide](./usage.md) | Users | Installation, configuration, keybindings, commands, full API reference, and extension examples |
| [Architecture](./architecture.md) | Contributors | Module structure, dependency graph, design patterns, and data flow diagrams |
| [Conventions](./conventions.md) | Contributors | Naming conventions, code style patterns, and contribution guidelines |

## Requirements

- Neovim >= 0.10
- TreeSitter (optional, enhances detection for embedded languages and JSX)

## Quick Start

```lua
-- lazy.nvim (zero configuration)
{
  "username/quill.nvim",
  event = "VeryLazy",
  opts = {},
}
```

## Key Features

| Feature | Description |
|---------|-------------|
| **Intelligent Detection** | TreeSitter-based context detection with filetype and `commentstring` fallback |
| **46 Languages** | Built-in support for Lua, Python, JavaScript, TypeScript, Go, Rust, and more |
| **JSX Support** | Automatic `{/* */}` comment style in JSX/TSX markup regions |
| **Text Objects** | `ic`/`ac` for comment blocks, `iC`/`aC` for comment lines |
| **Debug Regions** | Toggle `#region debug` blocks in buffer or project-wide |
| **Comment Alignment** | Align trailing comments to a consistent column |
| **Style Conversion** | Convert between line (`//`) and block (`/* */`) comments |
| **Normalize Spacing** | Fix inconsistent comment spacing across files |

## Default Keybindings

| Mapping | Mode | Description |
|---------|------|-------------|
| `<leader>cc` | Normal | Toggle current line |
| `[count]<leader>cc` | Normal | Toggle N lines |
| `<leader>cc` | Visual | Toggle selection |
| `ic` / `ac` | O-pending, Visual | Inner/around comment block |
| `iC` / `aC` | O-pending, Visual | Inner/around comment line |
| `<leader>cd` | Normal | Toggle debug (buffer) |
| `<leader>cD` | Normal | Toggle debug (project) |
| `<leader>cn` | Normal | Normalize spacing |
| `<leader>ca` | Normal | Align trailing comments |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      User Interface                             │
│  keymaps │ operators │ textobjects │ commands                   │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                      Core Services                              │
│  toggle │ detect │ comment │ undo                               │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                      Detection Layer                            │
│  treesitter │ languages │ regex                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                      Features Layer                             │
│  debug │ align │ normalize │ convert │ semantic                 │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                   Shared Infrastructure                         │
│  types │ utils                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## License

MIT
