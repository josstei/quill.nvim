---Toggle logic for smart comment/uncomment operations
---Analyzes current state and applies the inverse operation
---@module quill.core.toggle

local detect = require("quill.core.detect")
local comment = require("quill.core.comment")
local undo = require("quill.core.undo")

local M = {}

---Check if lines form a wrapped block comment
---Detects when first line is block start marker and last line is block end marker
---@param lines string[] Lines to check
---@param style CommentStyle|nil Comment style with block markers
---@return boolean True if lines are wrapped in block comment
local function is_block_wrapped(lines, style)
  if not style or not style.block or #lines < 2 then
    return false
  end

  local first_trimmed = lines[1]:match("^%s*(.-)%s*$")
  local last_trimmed = lines[#lines]:match("^%s*(.-)%s*$")

  local block_start = style.block[1]
  local block_end = style.block[2]

  return first_trimmed == block_start and last_trimmed == block_end
end

---Analyze the comment state of a range of lines
---Determines if lines are commented, mixed, or uncommented
---Detects both line comments and wrapped block comments
---Skips empty/whitespace-only lines in analysis
---@param bufnr number Buffer number (0 for current buffer)
---@param start_line number Starting line number (1-indexed, inclusive)
---@param end_line number Ending line number (1-indexed, inclusive)
---@return "all_commented"|"none_commented"|"mixed"|nil Comment state (nil on error)
---@return string|nil error Error message if validation failed
function M.analyze_lines(bufnr, start_line, end_line)
  bufnr = bufnr or 0

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil, "Invalid buffer"
  end

  if start_line < 1 or end_line < start_line then
    return nil, "Invalid line range"
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  if #lines == 0 then
    return "none_commented", nil
  end

  local style = detect.get_filetype_style(bufnr)

  if is_block_wrapped(lines, style) then
    return "all_commented", nil
  end

  local commented_count = 0
  local uncommented_count = 0

  for i, line_content in ipairs(lines) do
    local trimmed = line_content:match("^%s*(.-)%s*$")
    if trimmed ~= "" then
      local line_num = start_line + i - 1
      if detect.is_commented(bufnr, line_num) then
        commented_count = commented_count + 1
      else
        uncommented_count = uncommented_count + 1
      end
    end
  end

  if commented_count == 0 and uncommented_count == 0 then
    return "none_commented", nil
  elseif commented_count > 0 and uncommented_count == 0 then
    return "all_commented", nil
  elseif commented_count == 0 and uncommented_count > 0 then
    return "none_commented", nil
  else
    return "mixed", nil
  end
end

---Toggle comment state for a range of lines
---Analyzes current state and applies inverse operation in single undo group
---@param bufnr number Buffer number (0 for current buffer)
---@param start_line number Starting line number (1-indexed, inclusive)
---@param end_line number Ending line number (1-indexed, inclusive)
---@param opts {style_type: "line"|"block"|nil, force_comment: boolean|nil, force_uncomment: boolean|nil}|nil Options
---@return boolean success True if operation succeeded
---@return string|nil error Error message if operation failed
function M.toggle_lines(bufnr, start_line, end_line, opts)
  bufnr = bufnr or 0
  opts = opts or {}

  -- Validate buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false, "Invalid buffer"
  end

  -- Validate line range
  if start_line < 1 or end_line < start_line then
    return false, "Invalid line range"
  end

  -- Validate style_type option
  if opts.style_type and opts.style_type ~= "line" and opts.style_type ~= "block" then
    return false, "Invalid style_type: must be 'line' or 'block'"
  end

  -- Validate conflicting options
  if opts.force_comment and opts.force_uncomment then
    return false, "Cannot force both comment and uncomment"
  end

  -- Get comment style for the range (use first non-empty line's position)
  local style = nil
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  for i, line_content in ipairs(lines) do
    local trimmed = line_content:match("^%s*(.-)%s*$")
    if trimmed ~= "" then
      local line_num = start_line + i - 1
      style = detect.get_comment_style(bufnr, line_num, 0)
      break
    end
  end

  -- Fall back to filetype style if no non-empty line found
  if not style then
    style = detect.get_filetype_style(bufnr)
  end

  if not style then
    return false, "No comment style available for this buffer"
  end

  -- Determine operation based on current state and options
  local should_comment = false

  if opts.force_comment then
    should_comment = true
  elseif opts.force_uncomment then
    should_comment = false
  else
    -- Auto-detect based on current state
    local state, err = M.analyze_lines(bufnr, start_line, end_line)
    if err then
      return false, err
    end

    -- Toggle logic:
    -- - all_commented → uncomment
    -- - none_commented → comment
    -- - mixed → comment (treat as uncommenting partial)
    should_comment = (state == "none_commented" or state == "mixed")
  end

  -- Apply operation in single undo group
  local result, err = undo.with_undo_group(function()
    -- Get current lines
    local current_lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

    -- Apply comment or uncomment operation
    local new_lines
    if should_comment then
      new_lines = comment.comment_lines(current_lines, style, { style_type = opts.style_type })
    else
      new_lines = comment.uncomment_lines(current_lines, style)
    end

    -- Set the new lines
    vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, new_lines)

    return true
  end)

  if err then
    return false, "Failed to toggle comments: " .. tostring(err)
  end

  return result, nil
end

---Toggle comment for a single line
---Convenience wrapper around toggle_lines
---@param bufnr number Buffer number (0 for current buffer)
---@param line number Line number (1-indexed)
---@param opts {style_type: "line"|"block"|nil, force_comment: boolean|nil, force_uncomment: boolean|nil}|nil Options
---@return boolean success True if operation succeeded
---@return string|nil error Error message if operation failed
function M.toggle_line(bufnr, line, opts)
  return M.toggle_lines(bufnr, line, line, opts)
end

---Toggle comment for a visual selection
---Currently identical to toggle_lines, may handle visual block mode differently in future
---@param bufnr number Buffer number (0 for current buffer)
---@param start_line number Starting line number (1-indexed, inclusive)
---@param end_line number Ending line number (1-indexed, inclusive)
---@param opts {style_type: "line"|"block"|nil, force_comment: boolean|nil, force_uncomment: boolean|nil}|nil Options
---@return boolean success True if operation succeeded
---@return string|nil error Error message if operation failed
function M.toggle_visual(bufnr, start_line, end_line, opts)
  -- Currently same as toggle_lines
  -- In the future, this could handle visual block mode differently
  return M.toggle_lines(bufnr, start_line, end_line, opts)
end

return M
