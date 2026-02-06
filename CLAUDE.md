# CLAUDE.md

This file provides guidance to Claude Code when working with the quill.nvim codebase.

## Project Overview

Quill.nvim is a Neovim plugin for intelligent comment toggling with TreeSitter-based context detection, support for 40+ languages, and advanced features like debug region management and trailing comment alignment.

## Documentation

**Before making changes, review the relevant documentation:**

| Document | Purpose | Review When |
|----------|---------|-------------|
| [docs/architecture.md](docs/architecture.md) | Module structure, design patterns, data flow | Adding/modifying modules, changing dependencies |
| [docs/usage.md](docs/usage.md) | API reference, configuration, keybindings | Changing public API, config options, keymaps |
| [docs/conventions.md](docs/conventions.md) | Naming conventions, code style patterns | Writing any new code |
| [docs/index.md](docs/index.md) | Overview and quick reference | General orientation |

## Documentation Maintenance

**IMPORTANT: Keep documentation in sync with code changes.**

When making changes, update the relevant documentation:

| Change Type | Update Required |
|-------------|-----------------|
| New module | `docs/architecture.md` - add to structure and dependency graph |
| New public function | `docs/usage.md` - add to API reference |
| New config option | `docs/usage.md` - add to configuration schema |
| New keybinding | `docs/usage.md` - add to keybindings table |
| New command | `docs/usage.md` - add to commands section |
| Changed data flow | `docs/architecture.md` - update diagrams |
| New pattern/convention | `docs/conventions.md` - document the pattern |
| Major feature | `docs/index.md` - update feature list |

## Project Structure

```
quill.nvim/
├── plugin/quill.lua           # Entry point (VimEnter autocmd)
├── lua/quill/
│   ├── init.lua               # Public API
│   ├── config.lua             # Configuration management
│   ├── commands.lua           # :Quill command dispatcher
│   ├── keymaps.lua            # Keymap registration
│   ├── operators.lua          # Vim operator implementation
│   ├── textobjects.lua        # Text objects (ic, ac, iC, aC)
│   ├── core/                  # Core functionality
│   │   ├── toggle.lua         # Toggle orchestration
│   │   ├── detect.lua         # Detection facade
│   │   ├── comment.lua        # Marker manipulation
│   │   └── undo.lua           # Undo group management
│   ├── detection/             # Detection strategies
│   │   ├── treesitter.lua     # TreeSitter adapter
│   │   ├── regex.lua          # Regex fallback
│   │   └── languages.lua      # Language registry (40+)
│   └── features/              # Extended features
│       ├── debug.lua          # Debug region toggling
│       ├── align.lua          # Trailing comment alignment
│       ├── normalize.lua      # Spacing normalization
│       ├── convert.lua        # Style conversion
│       └── semantic.lua       # Semantic selection
├── tests/                     # Test suites
│   ├── unit/                  # Unit tests
│   ├── integration/           # Integration tests
│   └── languages/             # Language-specific tests
└── docs/                      # Documentation
```

## Development Commands

```bash
# Run all tests
./scripts/run_tests.sh

# Run specific test file
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/unit/toggle_spec.lua"

# Test in LuxVim (if available)
lux --cmd "lua vim.g.quill_debug = true"
```

## Key Architectural Decisions

1. **Detection Fallback Chain**: TreeSitter → filetype → commentstring
2. **Undo Grouping**: All multi-line operations wrapped in single undo group
3. **String Awareness**: Regex detection avoids false positives inside strings
4. **JSX Context**: "Nearest ancestor wins" logic for JSX vs JSX expression

## Code Style Quick Reference

- **Functions**: `verb_noun()` for actions, `get_noun()` for getters, `is_adjective()` for predicates
- **Variables**: `snake_case` for locals, `UPPER_SNAKE_CASE` for constants
- **Modules**: Return `M` table, use `local function` for private helpers
- **Errors**: Return `nil, "error message"` tuple for recoverable errors
- **Types**: Use LuaDoc annotations (`---@param`, `---@return`, `---@class`)

See [docs/conventions.md](docs/conventions.md) for complete style guide.

## Common Tasks

### Adding a New Language

1. Edit `lua/quill/detection/languages.lua`
2. Add entry to the languages table with `line`, `block`, `supports_nesting`, `jsx` fields
3. Add tests in `tests/languages/`
4. Update `docs/usage.md` if documenting supported languages

### Adding a New Feature

1. Create module in `lua/quill/features/`
2. Follow module structure pattern from `docs/conventions.md`
3. Wire up in `lua/quill/commands.lua` if command-accessible
4. Add keybinding in `lua/quill/keymaps.lua` if needed
5. Update `docs/architecture.md` with new module
6. Update `docs/usage.md` with API/commands/keybindings

### Modifying Public API

1. Update function in `lua/quill/init.lua`
2. Update `docs/usage.md` API reference
3. Ensure backward compatibility or document breaking change
4. Add/update tests

### Adding Configuration Option

1. Add to defaults in `lua/quill/config.lua`
2. Add validation if needed
3. Update `docs/usage.md` configuration schema
4. Add tests for the option
