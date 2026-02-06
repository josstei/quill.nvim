---Core comment implementation
---Handles adding and removing comment markers from lines
---@module quill.core.comment

local regex = require("quill.detection.regex")

local M = {}

---Add comment marker to a single line
---Preserves original indentation and adds proper spacing
---@param line string The line to comment
---@param style CommentStyle Comment style to use
---@param opts {style_type: "line"|"block"|nil}|nil Options
---@return string Commented line
function M.comment_line(line, style, opts)
  opts = opts or {}
  local style_type = opts.style_type or "line"

  -- Validate style_type
  if style_type ~= "line" and style_type ~= "block" then
    error("Invalid style_type: must be 'line' or 'block'")
  end

  -- Determine which comment style to use
  local use_block = false
  if style_type == "block" then
    if style.block then
      use_block = true
    elseif not style.line then
      -- No line comment available and block requested, use block if available
      use_block = style.block ~= nil
    end
    -- If block requested but not available, fall back to line comment
  end

  -- Use the regex helper to add comment
  return regex.add_comment(line, style, use_block)
end

---Remove comment marker from a single line
---Auto-detects whether line or block style was used
---Preserves original indentation
---@param line string The line to uncomment
---@param style CommentStyle Comment style to use
---@return string Uncommented line
function M.uncomment_line(line, style)
  -- Use the regex helper to strip comment
  return regex.strip_comment(line, style)
end

---Check if a selection contains block comments
---Used to determine if we should nest or use line comments
---@param lines string[] Lines to check
---@param style CommentStyle Comment style to use
---@return boolean True if any line contains block comment markers
function M.contains_block_comment(lines, style)
  if not style.block then
    return false
  end

  local block_start = style.block[1]
  local block_end = style.block[2]

  for _, line in ipairs(lines) do
    local markers = regex.get_comment_markers(line, style)
    if markers and markers.marker_type == "block" then
      return true
    end

    -- Also check for block markers anywhere in the line (even if not at start)
    -- This handles cases where block comments are mid-line
    if line:find(vim.pesc(block_start), 1, true) and line:find(vim.pesc(block_end), 1, true) then
      return true
    end
  end

  return false
end

---Comment multiple lines
---Handles both line and block comment styles with proper nesting logic
---@param lines string[] Lines to comment
---@param style CommentStyle Comment style to use
---@param opts {style_type: "line"|"block"|nil}|nil Options
---@return string[] Commented lines
function M.comment_lines(lines, style, opts)
  opts = opts or {}
  local style_type = opts.style_type or "line"

  -- Validate inputs
  if not lines or #lines == 0 then
    return lines or {}
  end

  -- Handle single line
  if #lines == 1 then
    return { M.comment_line(lines[1], style, opts) }
  end

  -- Multiple lines: decide on strategy based on style_type
  if style_type == "block" and style.block then
    -- Block comment strategy:
    -- Priority chain for handling nesting/conflicts:
    -- 1. Language supports nesting? → Nest naturally
    -- 2. Language has line comments? → Fall back to line comments
    -- 3. Block-only language? → Comment each line as individual blocks

    local has_block_comments = M.contains_block_comment(lines, style)

    if has_block_comments then
      -- We have existing block comments
      if style.supports_nesting then
        -- Language supports nesting, wrap entire selection
        return M._wrap_block_comment(lines, style)
      elseif style.line then
        -- Fall back to line comments
        local result = {}
        for _, line in ipairs(lines) do
          table.insert(result, M.comment_line(line, style, { style_type = "line" }))
        end
        return result
      else
        -- Block-only language, comment each line individually
        local result = {}
        for _, line in ipairs(lines) do
          table.insert(result, M.comment_line(line, style, { style_type = "block" }))
        end
        return result
      end
    else
      -- No existing block comments, wrap entire selection
      return M._wrap_block_comment(lines, style)
    end
  else
    -- Line comment strategy: comment each line individually
    local result = {}
    for _, line in ipairs(lines) do
      table.insert(result, M.comment_line(line, style, { style_type = "line" }))
    end
    return result
  end
end

---Uncomment multiple lines
---Detects if block or line commented and handles appropriately
---@param lines string[] Lines to uncomment
---@param style CommentStyle Comment style to use
---@return string[] Uncommented lines
function M.uncomment_lines(lines, style)
  if not lines or #lines == 0 then
    return lines or {}
  end

  -- Handle single line
  if #lines == 1 then
    return { M.uncomment_line(lines[1], style) }
  end

  -- Check if this is a block comment wrapping multiple lines
  if #lines >= 2 and style.block then
    local first_line = lines[1]
    local last_line = lines[#lines]

    -- Check raw content for block markers (before any comment stripping)
    local first_trimmed = first_line:match("^%s*(.-)%s*$")
    local last_trimmed = last_line:match("^%s*(.-)%s*$")

    local start_marker = style.block[1]
    local end_marker = style.block[2]

    -- Check if first line ONLY contains block start (or block start + end for single-line)
    local is_wrapped_block = false
    if first_trimmed == start_marker or first_trimmed == start_marker .. " " .. end_marker then
      -- Check if last line only contains block end
      if last_trimmed == end_marker then
        is_wrapped_block = true
      end
    end

    if is_wrapped_block then
      return M._unwrap_block_comment(lines, style)
    end
  end

  -- Not a wrapped block comment, uncomment each line individually
  local result = {}
  for _, line in ipairs(lines) do
    table.insert(result, M.uncomment_line(line, style))
  end
  return result
end

---Wrap lines with block comment markers
---Internal helper for block commenting multiple lines
---@param lines string[] Lines to wrap
---@param style CommentStyle Comment style with block markers
---@return string[] Lines wrapped with block comment
function M._wrap_block_comment(lines, style)
  if not style.block then
    error("Block comment style not available")
  end

  local block_start = style.block[1]
  local block_end = style.block[2]

  -- Get the minimum indentation from all non-empty lines
  local min_indent = nil
  for _, line in ipairs(lines) do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" then
      local indent = line:match("^(%s*)")
      if not min_indent or #indent < #min_indent then
        min_indent = indent
      end
    end
  end

  -- Default to no indentation if all lines are empty
  min_indent = min_indent or ""

  local result = {}

  -- Add opening block comment marker
  table.insert(result, min_indent .. block_start)

  -- Add all original lines (preserving their indentation)
  for _, line in ipairs(lines) do
    table.insert(result, line)
  end

  -- Add closing block comment marker
  table.insert(result, min_indent .. block_end)

  return result
end

---Unwrap block comment markers from lines
---Internal helper for uncommenting wrapped block comments
---@param lines string[] Lines with block comment wrapper
---@param style CommentStyle Comment style with block markers
---@return string[] Lines without block comment wrapper
function M._unwrap_block_comment(lines, style)
  if not style.block or #lines < 2 then
    return lines
  end

  local block_start = style.block[1]
  local block_end = style.block[2]

  -- Verify first and last lines are block markers
  local first_trimmed = lines[1]:match("^%s*(.-)%s*$")
  local last_trimmed = lines[#lines]:match("^%s*(.-)%s*$")

  if first_trimmed ~= block_start and first_trimmed ~= block_start .. " " .. block_end then
    -- Not a wrapped block comment, return as is
    return lines
  end

  if last_trimmed ~= block_end then
    -- Not a wrapped block comment, return as is
    return lines
  end

  -- Extract content between markers
  local result = {}
  for i = 2, #lines - 1 do
    table.insert(result, lines[i])
  end

  return result
end

return M
