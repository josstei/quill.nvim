---Style conversion feature
---Convert between line and block comment styles
---@module quill.features.convert

local detect = require("quill.core.detect")
local regex = require("quill.detection.regex")
local undo = require("quill.core.undo")
local utils = require("quill.utils")

local M = {}

---@alias CommentStyleType "line"|"block"|"mixed"|"none"

---@class ConversionResult
---@field success boolean True if conversion succeeded
---@field error_msg string|nil Error message if conversion failed
---@field count number Number of lines converted


---Check if a line is a block comment (start and end markers on same line)
---@param line string Line content
---@param block table|nil Block comment markers { start, end }
---@return boolean
local function is_block_commented(line, block)
  if not block or not line or line == "" then
    return false
  end

  local trimmed = line:match("^%s*(.-)%s*$")
  if trimmed == "" then
    return false
  end

  local block_start_escaped = utils.escape_pattern(block[1])
  local block_end_escaped = utils.escape_pattern(block[2])

  -- Check for block comment markers at start and end
  local start_pos = line:find(block_start_escaped)
  if not start_pos then
    return false
  end

  -- Verify start is at beginning (after whitespace)
  local before_start = line:sub(1, start_pos - 1):match("^%s*$")
  if not before_start then
    return false
  end

  -- Find end marker after start
  local end_pos = line:find(block_end_escaped, start_pos + #block[1])
  if not end_pos then
    return false
  end

  -- Verify end is at end (before trailing whitespace)
  local after_end = line:sub(end_pos + #block[2]):match("^%s*$")
  return after_end ~= nil
end

---Check if a line is a line comment
---@param line string Line content
---@param line_marker string|nil Line comment marker
---@return boolean
local function is_line_commented(line, line_marker)
  if not line_marker or not line or line == "" then
    return false
  end

  local trimmed = line:match("^%s*(.-)%s*$")
  if trimmed == "" then
    return false
  end

  local marker_escaped = utils.escape_pattern(line_marker)
  local pattern = "^%s*" .. marker_escaped

  return line:match(pattern) ~= nil
end

---Extract content from a block comment line
---Removes block markers and optional spacing
---@param line string Line content
---@param block table|nil Block comment markers { start, end }
---@return string Extracted content
local function extract_block_content(line, block)
  if not block then
    return line
  end

  -- Use regex module's strip_comment function with a dummy style
  local style = {
    block = block,
    line = nil,
  }

  local stripped = regex.strip_comment(line, style)
  return stripped:match("^%s*(.-)%s*$") or ""
end

---Detect current comment style in range
---@param bufnr number Buffer number
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@return CommentStyleType style Current style
function M.detect_current_style(bufnr, start_line, end_line)
  local style = detect.get_comment_style(bufnr, start_line, 0)
  if not style then
    return "none"
  end

  local has_line = false
  local has_block = false
  local has_none = false

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  for _, line in ipairs(lines) do
    -- Skip empty lines
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed == "" then
      -- Skip
    elseif is_block_commented(line, style.block) then
      has_block = true
    elseif is_line_commented(line, style.line) then
      has_line = true
    else
      has_none = true
    end
  end

  -- Determine overall style
  if has_none and not has_line and not has_block then
    return "none"
  elseif has_line and not has_block then
    return "line"
  elseif has_block and not has_line then
    return "block"
  else
    return "mixed"
  end
end

---Convert to line comments
---@param bufnr number Buffer number
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@return ConversionResult
function M.convert_to_line(bufnr, start_line, end_line)
  local style = detect.get_comment_style(bufnr, start_line, 0)

  -- Check if language supports line comments
  if not style or not style.line then
    return {
      success = false,
      error_msg = "Language doesn't support line comments",
      count = 0,
    }
  end

  local current = M.detect_current_style(bufnr, start_line, end_line)

  -- Already in target style or no comments
  if current == "none" then
    return { success = true, error_msg = nil, count = 0 }
  end

  if current == "line" then
    return { success = true, error_msg = nil, count = 0 }
  end

  -- Convert block or mixed to line
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local new_lines = {}
  local count = 0

  for i, line in ipairs(lines) do
    local trimmed = line:match("^%s*(.-)%s*$")

    -- Preserve empty lines
    if trimmed == "" then
      new_lines[i] = line
    elseif is_block_commented(line, style.block) then
      -- Convert block comment to line comment
      local content = extract_block_content(line, style.block)
      local indent = line:match("^(%s*)")

      if content == "" then
        new_lines[i] = indent .. style.line
      else
        new_lines[i] = indent .. style.line .. " " .. content
      end

      count = count + 1
    elseif is_line_commented(line, style.line) then
      -- Already line comment, preserve
      new_lines[i] = line
    else
      -- Not commented, preserve
      new_lines[i] = line
    end
  end

  -- Apply changes with undo grouping
  undo.with_undo_group(function()
    vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, new_lines)
  end)

  return { success = true, error_msg = nil, count = count }
end

---Convert to block comments
---@param bufnr number Buffer number
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@return ConversionResult
function M.convert_to_block(bufnr, start_line, end_line)
  local style = detect.get_comment_style(bufnr, start_line, 0)

  -- Check if language supports block comments
  if not style or not style.block then
    return {
      success = false,
      error_msg = "Language doesn't support block comments",
      count = 0,
    }
  end

  local current = M.detect_current_style(bufnr, start_line, end_line)

  -- Already in target style or no comments
  if current == "none" then
    return { success = true, error_msg = nil, count = 0 }
  end

  if current == "block" then
    return { success = true, error_msg = nil, count = 0 }
  end

  -- Convert line or mixed to block
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local new_lines = {}
  local open, close = style.block[1], style.block[2]
  local count = 0

  for i, line in ipairs(lines) do
    local trimmed = line:match("^%s*(.-)%s*$")

    -- Preserve empty lines
    if trimmed == "" then
      new_lines[i] = line
    elseif is_block_commented(line, style.block) then
      -- Already block comment, preserve
      new_lines[i] = line
    elseif is_line_commented(line, style.line) then
      -- Convert line comment to block comment
      local content = regex.strip_comment(line, style)
      local indent = line:match("^(%s*)")

      -- Trim content
      content = content:match("^%s*(.-)%s*$") or ""

      if content == "" then
        new_lines[i] = indent .. open .. " " .. close
      else
        new_lines[i] = indent .. open .. " " .. content .. " " .. close
      end

      count = count + 1
    else
      -- Not commented, preserve
      new_lines[i] = line
    end
  end

  -- Apply changes with undo grouping
  undo.with_undo_group(function()
    vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, new_lines)
  end)

  return { success = true, error_msg = nil, count = count }
end

return M
