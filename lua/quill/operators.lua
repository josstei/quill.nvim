---Operator implementation for comment toggling
---Provides count-aware <leader>cc and visual mode toggling
---Visual line mode uses block comments for multi-line selections (2+ lines)
---@module quill.operators

local toggle = require("quill.core.toggle")
local config = require("quill.config")

local M = {}

---Toggle lines from cursor with optional count
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
---Uses block comments for multi-line selections and block-visual mode when language supports them
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

---Setup operator keymaps
---Registers count-aware <leader>cc and visual mode toggle
---@param opts table|nil Configuration options (uses config.operators for mapping names)
---@return nil
function M.setup_operators(opts)
  opts = opts or {}

  local cfg = config.get()
  local toggle_map = opts.toggle or cfg.operators.toggle

  vim.keymap.set('n', toggle_map, function()
    local count = vim.v.count1
    M.toggle_lines_with_count(count)
  end, {
    silent = true,
    desc = "Toggle comment (use count for multiple lines)",
  })

  -- Visual mode: use :<C-u> to exit visual mode and set '< '> marks properly
  -- This is the canonical pattern used by Comment.nvim and other plugins
  vim.keymap.set('x', toggle_map, ':<C-u>lua require("quill.operators").visual_toggle()<CR>', {
    silent = true,
    desc = "Toggle comment on selection",
  })
end

---Visual mode toggle handler (called from string mapping)
---Reads marks after visual mode has been exited by :<C-u>
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

return M
