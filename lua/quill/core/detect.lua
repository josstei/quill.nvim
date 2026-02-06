---Core detection orchestrator
---Coordinates TreeSitter and fallback detection to provide a unified API
---@module quill.core.detect

local treesitter = require("quill.detection.treesitter")
local languages = require("quill.detection.languages")
local regex = require("quill.detection.regex")
local config = require("quill.config")

local M = {}

---Apply user-configured language overrides to a comment style
---Merges user overrides from config.languages with detected style
---@param style CommentStyle Detected comment style
---@param filetype string Buffer filetype
---@return CommentStyle
local function apply_config_overrides(style, filetype)
  local cfg = config.get()

  if not cfg.languages or not cfg.languages[filetype] then
    return style
  end

  local override = cfg.languages[filetype]

  -- Create a deep copy to avoid modifying the original (including nested tables like block)
  local result = vim.deepcopy(style)

  -- Apply overrides
  if override.line ~= nil then
    result.line = override.line
  end

  if override.block ~= nil then
    result.block = override.block
  end

  if override.supports_nesting ~= nil then
    result.supports_nesting = override.supports_nesting
  end

  if override.jsx ~= nil then
    result.jsx = override.jsx
  end

  return result
end

---Get the appropriate comment style for a buffer position
---Main public API for comment style detection
---Uses TreeSitter when available, falls back to filetype-based detection
---Applies user configuration overrides
---@param bufnr number Buffer number (0 for current buffer)
---@param line number Line number (1-indexed)
---@param col number Column number (0-indexed)
---@return CommentStyle|nil Comment style or nil if detection fails
function M.get_comment_style(bufnr, line, col)
  bufnr = bufnr or 0

  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  -- Convert line to 0-indexed for TreeSitter
  local row = line - 1

  -- Try TreeSitter detection first
  if treesitter.is_available(bufnr) then
    local style = treesitter.get_comment_style(bufnr, row, col)
    if style then
      local filetype = vim.bo[bufnr].filetype
      return apply_config_overrides(style, filetype)
    end
  end

  -- Fall back to filetype-based detection
  local style = M.get_filetype_style(bufnr)
  if style then
    local filetype = vim.bo[bufnr].filetype
    return apply_config_overrides(style, filetype)
  end

  -- No style could be determined
  return nil
end

---Get comment style from filetype only
---Used when TreeSitter is not available or as a fallback
---Checks languages.lua first, then vim.bo.commentstring
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@return CommentStyle|nil
function M.get_filetype_style(bufnr)
  bufnr = bufnr or 0

  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local filetype = vim.bo[bufnr].filetype

  -- Try explicit language definition first
  local style = languages.get_style(filetype)
  if style then
    return style
  end

  -- Fall back to commentstring parsing
  return languages.get_default(bufnr)
end

---Check if a line is commented
---Uses TreeSitter if available, falls back to regex detection
---@param bufnr number Buffer number (0 for current buffer)
---@param line number Line number (1-indexed)
---@return boolean True if the line is commented
function M.is_commented(bufnr, line)
  bufnr = bufnr or 0

  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)
  if #lines == 0 then
    return false
  end

  local line_content = lines[1]
  if not line_content or line_content == "" then
    return false
  end

  -- Try TreeSitter-based detection first
  -- Check if the entire line is within a comment node
  if treesitter.is_available(bufnr) then
    -- Check at the first non-whitespace character
    local first_char = line_content:match("^%s*()")
    if first_char then
      -- Convert to 0-indexed for TreeSitter
      local row = line - 1
      local col = first_char - 1

      if treesitter.is_in_comment(bufnr, row, col) then
        return true
      end
    end
  end

  -- Fall back to regex-based detection
  local style = M.get_comment_style(bufnr, line, 0)
  if not style then
    return false
  end

  return regex.is_commented(line_content, style)
end

return M
