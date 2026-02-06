# AGENTS.md

Guidance for coding agents working in `quill.nvim`.

## Project Snapshot

- Type: Neovim plugin (Lua)
- Purpose: context-aware comment toggling with TreeSitter + fallbacks
- Entry point: `plugin/quill.lua` (lazy setup on `VimEnter`)
- Public API: `lua/quill/init.lua`

## Source Of Truth

- Trust runtime behavior in source files over docs when they diverge.
- For defaults and config schema, use `lua/quill/config.lua`.
- For operator mappings and behavior, use `lua/quill/operators.lua`.
- If you change behavior, update docs in the same change.

## Architecture (Practical Map)

- `lua/quill/init.lua`: public API, wires setup
- `lua/quill/config.lua`: defaults + validation
- `lua/quill/keymaps.lua`: keymap registration + conflict warnings
- `lua/quill/commands.lua`: `:Quill` subcommand dispatcher
- `lua/quill/operators.lua`: `gc{motion}`, `gcc`, visual `gc`
- `lua/quill/textobjects.lua`: `ic`/`ac`/`iC`/`aC`
- `lua/quill/core/`: toggle orchestration, detection facade, comment ops, undo grouping
- `lua/quill/detection/`: TreeSitter, regex fallback, language registry
- `lua/quill/features/`: debug, normalize, align, convert, semantic

Detection flow is: TreeSitter -> language registry -> `commentstring`.

## Code Conventions

- Follow `docs/conventions.md` naming and module patterns.
- Keep module-level constants in `UPPER_SNAKE_CASE`.
- Use LuaDoc annotations for public functions/types.
- Preserve error-handling patterns:
  - caller misuse: `error(...)`
  - recoverable operation failures: `nil, err` or `false, err`
- Keep line-number contracts explicit (most APIs are 1-indexed at boundaries).
- Multi-line buffer edits should stay grouped via `quill.core.undo`.

## Test Workflow

- Main unit suite:
  - `./scripts/run_tests.sh`
- Single test file:
  - `nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedFile tests/unit/<file>_spec.lua"`
- Integration suite:
  - `nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/integration/ { minimal_init = 'tests/minimal_init.lua' }"`
- Language suite:
  - `nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/languages/ { minimal_init = 'tests/minimal_init.lua' }"`

Notes:

- `tests/minimal_init.lua` auto-bootstraps `plenary.nvim` if missing.
- In restricted/sandboxed environments, headless Neovim may fail with swap-file errors (`E303`) unrelated to logic changes. Document this if encountered.

## Change Playbooks

### Add/Change a Language Definition

1. Edit `lua/quill/detection/languages.lua`
2. Add/update tests in `tests/languages/` (and unit tests if needed)
3. Update user docs if supported language list changes

### Add/Change a Feature or Command

1. Implement in `lua/quill/features/` (or `core/` when foundational)
2. Wire command routing in `lua/quill/commands.lua` when user-facing
3. Add keymaps in `lua/quill/keymaps.lua` only if required
4. Add/adjust tests (`tests/unit/` + `tests/integration/`)
5. Update docs (`docs/usage.md`, `docs/architecture.md`)

### Change Config or Mappings

1. Update defaults + validation in `lua/quill/config.lua`
2. Update consumers (`keymaps`, `operators`, feature modules)
3. Add tests for valid/invalid config paths
4. Update docs examples and keybinding tables

## Documentation Sync Requirements

When behavior changes, update the relevant docs in the same change:

- `docs/usage.md`: public API, config, commands, keymaps
- `docs/architecture.md`: module responsibilities/dependencies
- `docs/conventions.md`: new patterns or style rules
- `README.md`: user-facing examples and key features

