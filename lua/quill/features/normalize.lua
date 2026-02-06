---Comment normalization feature
---Fixes spacing inconsistencies in comments:
---  //foo     -> // foo
---  /*foo*/   -> /* foo */
---  //  foo   -> // foo
---@module quill.features.normalize

local M = {}

local detect = require("quill.core.detect")
local undo = require("quill.core.undo")
local utils = require("quill.utils")

---Check if a line contains a multi-line block comment start
---Returns true if the line has block start but no matching end
---@param line_text string
---@param style CommentStyle
---@return boolean is_block_start
---@return string|nil indent
---@return string|nil content
local function is_block_start(line_text, style)
  if not style.block then
    return false
  end

  local indent = line_text:match("^(%s*)")
  local content = line_text:sub(#indent + 1)

  local block_start_escaped = utils.escape_pattern(style.block[1])
  local block_end_escaped = utils.escape_pattern(style.block[2])

  -- Check if line starts with block marker
  if not content:match("^" .. block_start_escaped) then
    return false
  end

  -- Check if end marker is on same line
  local _, end_pos = content:find(block_end_escaped)
  if end_pos then
    return false -- It's a single-line block comment
  end

  -- Extract content after block start
  local text_after_marker = content:sub(#style.block[1] + 1)

  return true, indent, text_after_marker
end

---Check if a line contains a multi-line block comment end
---Returns true if the line has block end but no preceding start
---@param line_text string
---@param style CommentStyle
---@return boolean is_block_end
---@return string|nil content
---@return string|nil indent
local function is_block_end(line_text, style)
  if not style.block then
    return false
  end

  local block_end_escaped = utils.escape_pattern(style.block[2])

  -- Find the end marker
  local end_start, end_finish = line_text:find(block_end_escaped)
  if not end_start then
    return false
  end

  -- Check that there's no start marker before it
  local block_start_escaped = utils.escape_pattern(style.block[1])
  local start_pos = line_text:find(block_start_escaped)
  if start_pos and start_pos < end_start then
    return false -- It's a single-line block comment
  end

  -- Extract content before block end and indentation after
  local content_before = line_text:sub(1, end_start - 1)
  local indent_after = line_text:sub(end_finish + 1)

  return true, content_before, indent_after
end

---Normalize spacing in a single commented line
---Fixes spacing after opening marker and before closing marker
---Preserves indentation and original structure
---@param line_text string The line text
---@param style CommentStyle The comment style
---@return string normalized The normalized line
---@return boolean changed Whether the line was modified
function M.normalize_line(line_text, style)
  if not line_text or line_text == "" then
    return line_text, false
  end

  -- Extract indentation
  local indent = line_text:match("^(%s*)")
  local content = line_text:sub(#indent + 1)

  -- Check for single-line block comment FIRST (handles languages like Lua where block starts with line marker)
  if style.block then
    local block_start = utils.escape_pattern(style.block[1])
    local block_end = utils.escape_pattern(style.block[2])

    -- Pattern: block_start ... block_end (on same line)
    local start_pos, start_end = content:find("^" .. block_start)
    if start_pos then
      local end_start, end_finish = content:find(block_end, start_end + 1)
      if end_start then
        -- Verify this is the end (no content after block end)
        local after_block = content:sub(end_finish + 1)
        if after_block:match("^%s*$") then
          -- Extract content between markers
          local between = content:sub(start_end + 1, end_start - 1)

          -- Empty block stays empty
          if between:match("^%s*$") then
            local normalized = indent .. style.block[1] .. style.block[2]
            return normalized, normalized ~= line_text
          end

          -- Normalize spacing: exactly one space after start, one before end
          local trimmed = between:gsub("^%s+", ""):gsub("%s+$", "")
          local normalized = indent .. style.block[1] .. " " .. trimmed .. " " .. style.block[2]

          return normalized, normalized ~= line_text
        end
      end
    end
  end

  -- Check for multi-line block start (before line comments, to handle Lua --[[ vs --)
  if style.block then
    local is_start, start_indent, text_after = is_block_start(line_text, style)
    if is_start then
      -- Empty start stays empty (/* alone on line)
      if text_after:match("^%s*$") then
        local normalized = start_indent .. style.block[1]
        return normalized, normalized ~= line_text
      end

      -- Normalize spacing after start marker
      local trimmed = text_after:gsub("^%s+", "")
      local normalized = start_indent .. style.block[1] .. " " .. trimmed

      return normalized, normalized ~= line_text
    end
  end

  -- Check for multi-line block end
  if style.block then
    local is_end, content_before, indent_after = is_block_end(line_text, style)
    if is_end then
      -- Empty end stays empty (just */ on line)
      if content_before:match("^%s*$") then
        local normalized = content_before .. style.block[2] .. indent_after
        return normalized, normalized ~= line_text
      end

      -- Normalize spacing before end marker
      local trimmed = content_before:gsub("%s+$", "")
      local normalized = trimmed .. " " .. style.block[2] .. indent_after

      return normalized, normalized ~= line_text
    end
  end

  -- Check for line comment (after block comments, to avoid matching -- in Lua's --[[)
  if style.line then
    local marker = utils.escape_pattern(style.line)
    local pattern = "^" .. marker .. "(.*)"
    local text = content:match(pattern)

    if text then
      -- Empty comment stays empty
      if text:match("^%s*$") then
        local normalized = indent .. style.line
        return normalized, normalized ~= line_text
      end

      -- Remove leading whitespace and ensure exactly one space
      local trimmed = text:gsub("^%s+", "")
      local normalized = indent .. style.line .. " " .. trimmed

      return normalized, normalized ~= line_text
    end
  end

  -- Not a comment or already normalized
  return line_text, false
end

---Normalize comments across a line range
---Detects comment style per line and fixes spacing
---@param bufnr number Buffer number
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@return number count Lines modified
local function normalize_lines_in_range(bufnr, start_line, end_line)
  local count = 0

  for line_num = start_line, end_line do
    local style = detect.get_comment_style(bufnr, line_num, 0)
    if style then
      local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
      if #lines > 0 then
        local normalized, changed = M.normalize_line(lines[1], style)
        if changed then
          vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, { normalized })
          count = count + 1
        end
      end
    end
  end

  return count
end

---Normalize all comments in buffer
---Finds all commented lines and normalizes their spacing
---Wraps all changes in single undo group
---@param bufnr? number Buffer number (default: current)
---@return number count Lines modified
function M.normalize_buffer(bufnr)
  local ctx = utils.get_buffer_context(bufnr)
  if not ctx then
    return 0
  end
  bufnr = ctx.bufnr

  undo.start_undo_group()
  local count = normalize_lines_in_range(bufnr, 1, vim.api.nvim_buf_line_count(bufnr))
  undo.end_undo_group()

  return count
end

---Normalize comments in range
---Normalizes all commented lines within the specified range
---Used for visual selection support
---@param bufnr number Buffer number
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@return number count Lines modified
function M.normalize_range(bufnr, start_line, end_line)
  if not utils.get_buffer_context(bufnr) then
    return 0
  end

  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  undo.start_undo_group()
  local count = normalize_lines_in_range(bufnr, start_line, end_line)
  undo.end_undo_group()

  return count
end

return M
