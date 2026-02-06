---@class CommentMarkers
---@field start_pos number  Start position of comment marker (1-indexed)
---@field end_pos number    End position of comment marker (1-indexed)
---@field marker_type "line"|"block"  Type of comment marker

local utils = require("quill.utils")

local M = {}

---Detect if a line is commented using regex patterns
---Handles both line and block comment styles
---Skips comment markers inside quoted strings
---@param line string
---@param style CommentStyle
---@return boolean
function M.is_commented(line, style)
  if not line or line == "" then
    return false
  end

  -- Trim leading/trailing whitespace for analysis
  local trimmed = line:match("^%s*(.-)%s*$")

  if trimmed == "" then
    return false
  end

  -- Check for line comment first (more common and takes precedence)
  if style.line then
    local line_marker_escaped = utils.escape_pattern(style.line)
    -- Pattern: optional whitespace, then line comment marker
    local pattern = "^%s*" .. line_marker_escaped

    local start_pos = line:find(pattern)
    if start_pos then
      -- Find where the marker actually starts (after leading whitespace)
      local marker_start = line:find(line_marker_escaped, start_pos)
      if marker_start and not utils.is_inside_string(line, marker_start) then
        return true
      end
    end
  end

  -- Check for block comment on single line
  if style.block then
    local block_start_escaped = utils.escape_pattern(style.block[1])
    local block_end_escaped = utils.escape_pattern(style.block[2])

    -- Find start marker
    local start_pos = line:find(block_start_escaped)
    if start_pos and not utils.is_inside_string(line, start_pos) then
      -- Find corresponding end marker after start
      local end_pos = line:find(block_end_escaped, start_pos + #style.block[1])
      if end_pos and not utils.is_inside_string(line, end_pos) then
        -- Verify this is the primary comment structure (start at beginning, end at end)
        local before_start = line:sub(1, start_pos - 1):match("^%s*$")
        local after_end = line:sub(end_pos + #style.block[2]):match("^%s*$")
        if before_start and after_end then
          return true
        end
      end
    end
  end

  return false
end

---Extract comment markers from a commented line
---Returns the position and type of comment markers
---@param line string
---@param style CommentStyle
---@return CommentMarkers|nil
function M.get_comment_markers(line, style)
  if not line or line == "" then
    return nil
  end

  -- Check for block comment first (to handle cases like Lua's --[[ vs --)
  if style.block then
    local block_start_escaped = utils.escape_pattern(style.block[1])
    local block_end_escaped = utils.escape_pattern(style.block[2])

    -- Find start marker
    local start_begin, start_end = line:find(block_start_escaped)
    if start_begin and not utils.is_inside_string(line, start_begin) then
      -- Verify start is at beginning (after whitespace)
      local before_start = line:sub(1, start_begin - 1):match("^%s*$")
      if before_start then
        -- Find end marker
        local end_begin, end_end = line:find(block_end_escaped, start_end + 1)
        if end_begin and not utils.is_inside_string(line, end_begin) then
          -- Verify end is at end of line (before whitespace)
          local after_end = line:sub(end_end + 1):match("^%s*$")
          if after_end then
            return {
              start_pos = start_begin,
              end_pos = end_end,
              marker_type = "block",
            }
          end
        end
      end
    end
  end

  -- Check for line comment
  if style.line then
    local line_marker_escaped = utils.escape_pattern(style.line)

    local marker_start = line:find(line_marker_escaped)
    if marker_start then
      -- Check pattern match and string context
      local before = line:sub(1, marker_start - 1)
      if before:match("^%s*$") and not utils.is_inside_string(line, marker_start) then
        return {
          start_pos = marker_start,
          end_pos = marker_start + #style.line - 1,
          marker_type = "line",
        }
      end
    end
  end

  return nil
end

---Remove comment markers from a line
---Preserves original indentation
---Handles both line and block comment styles
---@param line string
---@param style CommentStyle
---@return string
function M.strip_comment(line, style)
  if not line or line == "" then
    return line
  end

  -- Get the original indentation
  local indent = line:match("^(%s*)")

  -- Try to remove block comment first if it exists (to handle cases like Lua's --[[ vs --)
  if style.block then
    local block_start_escaped = utils.escape_pattern(style.block[1])
    local block_end_escaped = utils.escape_pattern(style.block[2])

    -- Find start marker
    local start_begin, start_end = line:find(block_start_escaped)
    if start_begin and not utils.is_inside_string(line, start_begin) then
      -- Check if start is at beginning (after whitespace)
      local before_start = line:sub(1, start_begin - 1)
      if before_start:match("^%s*$") then
        -- Find end marker
        local end_begin, end_end = line:find(block_end_escaped, start_end + 1)
        if end_begin and not utils.is_inside_string(line, end_begin) then
          -- Verify this is a block comment (ends at end of line)
          local after = line:sub(end_end + 1)
          if after:match("^%s*$") then
            -- Extract content between markers
            local content = line:sub(start_end + 1, end_begin - 1)

            -- Trim one space after start marker and before end marker if present
            content = content:gsub("^%s?", ""):gsub("%s?$", "")

            -- Preserve original indentation
            if content == "" then
              return indent
            end
            return indent .. content
          end
        end
      end
    end
  end

  -- Try to remove line comment
  if style.line then
    local line_marker_escaped = utils.escape_pattern(style.line)

    local marker_pos = line:find(line_marker_escaped)
    if marker_pos then
      -- Check if marker is at start (after whitespace)
      local before = line:sub(1, marker_pos - 1)
      if before:match("^%s*$") and not utils.is_inside_string(line, marker_pos) then
        -- Extract content after marker, removing one optional space
        local content_start = marker_pos + #style.line
        local content = line:sub(content_start)
        content = content:gsub("^%s?", "") -- Remove single space if present

        -- Preserve original indentation
        return indent .. content
      end
    end
  end

  -- No comment found, return original line
  return line
end

---Add comment markers to a line
---Preserves original indentation
---Adds appropriate spacing around markers
---@param line string
---@param style CommentStyle
---@param use_block boolean|nil Whether to use block comments (defaults to false)
---@return string
function M.add_comment(line, style, use_block)
  if not line then
    return line
  end

  -- Get the original indentation
  local indent = line:match("^(%s*)")
  local content = line:match("^%s*(.*)$")

  -- If line is empty or whitespace-only, just add comment marker to indentation
  if content == "" then
    if use_block and style.block then
      return indent .. style.block[1] .. " " .. style.block[2]
    elseif style.line then
      return indent .. style.line
    else
      return line
    end
  end

  -- Use block comment if requested and available
  if use_block and style.block then
    return indent .. style.block[1] .. " " .. content .. " " .. style.block[2]
  end

  -- Use line comment (most common)
  if style.line then
    return indent .. style.line .. " " .. content
  end

  -- Fallback to block comment if line comment not available
  if style.block then
    return indent .. style.block[1] .. " " .. content .. " " .. style.block[2]
  end

  -- No comment style available, return original
  return line
end

return M
