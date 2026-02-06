---Operator implementation for comment toggling via operatorfunc
---Provides configurable {toggle}{motion}, line-wise alias, and visual mappings
---Uses Vim's g@ mechanism for full composability with motions and text objects
---@module quill.operators

local toggle = require("quill.core.toggle")
local config = require("quill.config")

local M = {}

---@class OperatorContext
---@field source "operator"|"visual"
---@field visual_mode string|nil

---@type OperatorContext
local operator_context = {
  source = "operator",
  visual_mode = nil,
}

local OPERATORFUNC_REF = "v:lua.require'quill.operators'.operatorfunc"

---Operatorfunc callback invoked by Vim after g@ receives a motion
---Reads '[/'] marks for the operated range and delegates to toggle
---@param motion_type string Motion type from Vim: "line", "char", or "block"
---@return nil
function M.operatorfunc(motion_type)
  local bufnr = vim.api.nvim_get_current_buf()
  local start_line = vim.fn.line("'[")
  local end_line = vim.fn.line("']")

  if start_line < 1 or end_line < start_line then
    return
  end

  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  if end_line > total_lines then
    end_line = total_lines
  end

  local opts = {}

  if operator_context.source == "visual" then
    local is_multiline = end_line > start_line
    local is_block_visual = operator_context.visual_mode == "\22"
    local is_visual_line = operator_context.visual_mode == "V"

    if is_block_visual or (is_visual_line and is_multiline) then
      opts.style_type = "block"
    end
  end

  operator_context = { source = "operator", visual_mode = nil }

  local success, err
  if start_line == end_line then
    success, err = toggle.toggle_line(bufnr, start_line, opts)
  else
    success, err = toggle.toggle_lines(bufnr, start_line, end_line, opts)
  end

  if not success then
    vim.notify("[quill] " .. (err or "Failed to toggle comments"), vim.log.levels.ERROR)
  end
end

---Derive the line-wise toggle key from the operator key
---Doubles the last character: "<leader>cc" -> "<leader>ccc", "cm" -> "cmm"
---@param toggle_key string The operator key
---@return string
local function derive_line_key(toggle_key)
  local last_char = toggle_key:sub(-1)
  return toggle_key .. last_char
end

---Toggle lines from cursor with optional count
---Preserved for backward compatibility and direct programmatic use
---@param count number Number of lines to toggle (1 = current line only)
---@return nil
function M.toggle_lines_with_count(count)
  local bufnr = vim.api.nvim_get_current_buf()
  local start_line = vim.fn.line(".")
  local end_line = start_line + count - 1

  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  if end_line > total_lines then
    end_line = total_lines
  end

  local success, err
  if start_line == end_line then
    success, err = toggle.toggle_line(bufnr, start_line, {})
  else
    success, err = toggle.toggle_lines(bufnr, start_line, end_line, {})
  end

  if not success then
    vim.notify("[quill] " .. (err or "Failed to toggle comments"), vim.log.levels.ERROR)
  end
end

---Toggle visual selection with explicit range
---Preserved for backward compatibility and direct programmatic use
---@param start_line number Start line of selection
---@param end_line number End line of selection
---@param mode string|nil Visual mode ('v', 'V', or '\22' for block)
---@return nil
function M.toggle_visual_range(start_line, end_line, mode)
  local bufnr = vim.api.nvim_get_current_buf()

  if start_line < 1 or end_line < start_line then
    vim.notify("[quill] Invalid visual selection", vim.log.levels.ERROR)
    return
  end

  local opts = {}

  local is_multiline = end_line > start_line
  local is_block_visual = mode == "\22"
  local is_visual_line = mode == "V"

  if is_block_visual or (is_visual_line and is_multiline) then
    opts.style_type = "block"
  end

  local success, err = toggle.toggle_visual(bufnr, start_line, end_line, opts)

  if not success then
    vim.notify("[quill] " .. (err or "Failed to toggle visual selection"), vim.log.levels.ERROR)
  end
end

---Visual mode toggle handler
---Preserved for backward compatibility
---@return nil
function M.visual_toggle()
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  local mode = vim.fn.visualmode()

  if start_line < 1 or end_line < 1 or start_line > end_line then
    vim.notify("[quill] Invalid visual selection", vim.log.levels.ERROR)
    return
  end

  M.toggle_visual_range(start_line, end_line, mode)
end

---Setup operator keymaps using operatorfunc
---Registers toggle (operator), toggle_line (line-wise), and visual toggle mappings
---@param opts table|nil Configuration options
---@return nil
function M.setup_operators(opts)
  opts = opts or {}

  local cfg = config.get()
  local toggle_key = opts.toggle or cfg.operators.toggle
  local line_key = opts.toggle_line or cfg.operators.toggle_line or derive_line_key(toggle_key)

  vim.keymap.set("n", toggle_key, function()
    operator_context = { source = "operator", visual_mode = nil }
    vim.o.operatorfunc = OPERATORFUNC_REF
    return "g@"
  end, {
    expr = true,
    silent = true,
    desc = "Toggle comment (operator)",
  })

  vim.keymap.set("n", line_key, function()
    operator_context = { source = "operator", visual_mode = nil }
    vim.o.operatorfunc = OPERATORFUNC_REF
    return vim.v.count1 .. "g@_"
  end, {
    expr = true,
    silent = true,
    desc = "Toggle comment on line(s)",
  })

  vim.keymap.set("x", toggle_key, function()
    operator_context = {
      source = "visual",
      visual_mode = vim.fn.mode(),
    }
    vim.o.operatorfunc = OPERATORFUNC_REF
    return "g@"
  end, {
    expr = true,
    silent = true,
    desc = "Toggle comment on selection",
  })
end

return M
