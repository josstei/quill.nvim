---Keymap registration with conflict detection and warnings
---Handles registration of all plugin keymaps based on configuration
---@module quill.keymaps

local config = require("quill.config")
local operators = require("quill.operators")

local M = {}

---Check if a mapping already exists
---@param mode string Mode to check ("n", "x", "o", etc.)
---@param lhs string Left-hand side of mapping
---@return table|nil Existing mapping info or nil
local function check_conflict(mode, lhs)
  local maparg = vim.fn.maparg(lhs, mode, false, true)

  if maparg and maparg.lhs then
    return maparg
  end

  return nil
end

---Warn about mapping override
---@param mode string Mode being overridden
---@param lhs string Left-hand side being overridden
---@param existing table Existing mapping info
local function warn_override(mode, lhs, existing)
  local msg = string.format(
    "[quill] Overriding existing %s-mode mapping for '%s'",
    mode,
    lhs
  )

  if existing.rhs then
    msg = msg .. string.format(" (was: '%s')", existing.rhs)
  elseif existing.callback then
    msg = msg .. " (was: <Lua function>)"
  end

  vim.notify(msg, vim.log.levels.WARN)
end

---Register a keymap with optional conflict checking
---@param modes string|string[] Mode(s) to register in
---@param lhs string Left-hand side of mapping
---@param rhs string|function Right-hand side of mapping
---@param opts table|nil Keymap options
---@return nil
function M.register(modes, lhs, rhs, opts)
  opts = opts or {}
  local cfg = config.get()

  if type(modes) == "string" then
    modes = { modes }
  end

  if cfg.warn_on_override then
    for _, mode in ipairs(modes) do
      local existing = check_conflict(mode, lhs)
      if existing then
        warn_override(mode, lhs, existing)
      end
    end
  end

  for _, mode in ipairs(modes) do
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

---Setup all keymaps based on configuration
---@return nil
function M.setup()
  local cfg = config.get()

  -- Register operator keymaps (<leader>cc with count support)
  if cfg.keymaps.operators then
    operators.setup_operators()
  end

  -- Register textobject keymaps (ic, ac, iC, aC)
  if cfg.keymaps.textobjects then
    local textobjects = require("quill.textobjects")
    textobjects.setup(cfg)
  end

  -- Register leader keymaps
  if cfg.keymaps.leader then
    local debug = require("quill.features.debug")
    local normalize = require("quill.features.normalize")
    local align = require("quill.features.align")

    M.register("n", cfg.mappings.toggle, function()
      operators.toggle_lines_with_count(vim.v.count1)
    end, {
      desc = "Toggle comment on line(s)",
    })

    M.register("x", cfg.mappings.toggle, function()
      local start_line = vim.fn.line("'<")
      local end_line = vim.fn.line("'>")
      local mode = vim.fn.visualmode()
      operators.toggle_visual_range(start_line, end_line, mode)
    end, {
      desc = "Toggle comment on selection",
    })

    M.register("n", cfg.mappings.debug_buffer, function()
      debug.toggle_buffer()
    end, {
      desc = "Toggle debug comments in buffer",
    })

    M.register("n", cfg.mappings.debug_project, function()
      debug.toggle_project({ confirm = true })
    end, {
      desc = "Toggle debug comments in project",
    })

    M.register("n", cfg.mappings.normalize, function()
      normalize.normalize_buffer()
    end, {
      desc = "Normalize comment spacing",
    })

    M.register("n", cfg.mappings.align, function()
      local line = vim.fn.line(".")
      align.align_lines(0, line, line)
    end, {
      desc = "Align trailing comments",
    })
  end
end

return M
