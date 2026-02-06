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

---Assert that parameters are numbers, raising an error if not
---Convenience wrapper for public API boundary validation
---@param name string Parameter name for error message
---@param ... any Values to check
function M.assert_numbers(name, ...)
  local ok, err = M.validate_numbers(name, ...)
  if not ok then
    error(err, 2)
  end
end

return M
