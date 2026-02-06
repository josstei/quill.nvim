---@class quill.features.align
---@field setup fun(cfg: table)
---@field find_trailing_comment fun(line_text: string, style: CommentStyle): TrailingCommentInfo|nil
---@field calculate_target_column fun(lines_info: table[], opts?: {column: number, min_gap: number}): number
---@field align_lines fun(bufnr: number, start_line: number, end_line: number, opts?: {column: number, min_gap: number}): number

local M = {}

local detect = require("quill.core.detect")
local undo = require("quill.core.undo")

local default_opts = {
  column = 80,    -- Max column for alignment
  min_gap = 2,    -- Minimum spaces before comment
}

---@class TrailingCommentInfo
---@field code string The code part before the comment
---@field comment string The comment content (without marker)
---@field marker string The comment marker used

--- Find trailing comment on a line, avoiding comments inside strings
---@param line_text string The line text
---@param style CommentStyle The comment style for this line
---@return TrailingCommentInfo|nil info Trailing comment info or nil
function M.find_trailing_comment(line_text, style)
  if not style.line then return nil end

  -- Skip if line starts with comment (not trailing)
  local trimmed = line_text:gsub("^%s*", "")
  if trimmed:sub(1, #style.line) == style.line then
    return nil
  end

  -- Find comment marker outside strings
  local in_string = false
  local string_char = nil
  local escape_next = false
  local i = 1

  while i <= #line_text do
    local char = line_text:sub(i, i)

    -- Handle escape sequences
    if escape_next then
      escape_next = false
      i = i + 1
      goto continue
    end

    if char == "\\" then
      escape_next = true
      i = i + 1
      goto continue
    end

    -- Handle string state
    if not in_string and (char == '"' or char == "'" or char == '`') then
      in_string = true
      string_char = char
    elseif in_string and char == string_char then
      in_string = false
      string_char = nil
    end

    -- Check for comment marker outside strings
    if not in_string then
      local potential_marker = line_text:sub(i, i + #style.line - 1)
      if potential_marker == style.line then
        local code = line_text:sub(1, i - 1):gsub("%s+$", "")
        local comment = line_text:sub(i + #style.line):gsub("^%s*", "")

        -- Verify there's actual code before the comment
        if code == "" then
          return nil
        end

        return {
          code = code,
          comment = comment,
          marker = style.line
        }
      end
    end

    i = i + 1
    ::continue::
  end

  return nil
end

--- Calculate target alignment column based on code lengths
---@param lines_info table[] List of { line_num, code, comment, marker }
---@param opts? { column: number, min_gap: number }
---@return number column Target column
function M.calculate_target_column(lines_info, opts)
  opts = vim.tbl_extend("force", default_opts, opts or {})

  if #lines_info == 0 then
    return opts.column
  end

  local max_code_len = 0
  for _, info in ipairs(lines_info) do
    -- Use display width to handle tabs properly
    local display_len = vim.fn.strdisplaywidth(info.code)
    max_code_len = math.max(max_code_len, display_len)
  end

  local target = max_code_len + opts.min_gap
  return math.min(target, opts.column)
end

--- Format a line with aligned trailing comment
---@param code string The code part
---@param marker string The comment marker
---@param comment string The comment content
---@param target_col number The target column
---@return string line The formatted line
local function format_aligned_line(code, marker, comment, target_col)
  local code_len = vim.fn.strdisplaywidth(code)
  local padding = target_col - code_len
  if padding < 1 then padding = 1 end

  -- Normalize comment whitespace
  local normalized_comment = comment:gsub("^%s*", ""):gsub("%s+$", "")

  return code .. string.rep(" ", padding) .. marker .. " " .. normalized_comment
end

--- Align trailing comments in range
---@param bufnr number Buffer number
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@param opts? { column: number, min_gap: number }
---@return number count Lines modified
function M.align_lines(bufnr, start_line, end_line, opts)
  opts = vim.tbl_extend("force", default_opts, opts or {})

  -- Collect lines with trailing comments
  local lines_info = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  for i, line_text in ipairs(lines) do
    local line_num = start_line + i - 1
    local ft = vim.bo[bufnr].filetype
    local style = detect.get_comment_style(bufnr, line_num, ft)

    local trailing = M.find_trailing_comment(line_text, style)
    if trailing then
      table.insert(lines_info, {
        line_num = line_num,
        code = trailing.code,
        comment = trailing.comment,
        marker = trailing.marker
      })
    end
  end

  if #lines_info == 0 then
    return 0
  end

  -- Calculate target column
  local target_col = M.calculate_target_column(lines_info, opts)

  -- Rewrite lines with aligned comments in single undo group
  local modified_count = 0

  undo.start_undo_group()

  for _, info in ipairs(lines_info) do
    local new_line = format_aligned_line(info.code, info.marker, info.comment, target_col)
    vim.api.nvim_buf_set_lines(bufnr, info.line_num - 1, info.line_num, false, { new_line })
    modified_count = modified_count + 1
  end

  undo.end_undo_group()

  return modified_count
end

--- Setup with configuration
---@param cfg table Configuration
function M.setup(cfg)
  if cfg and cfg.align then
    if cfg.align.column ~= nil then
      default_opts.column = cfg.align.column
    end
    if cfg.align.min_gap ~= nil then
      default_opts.min_gap = cfg.align.min_gap
    end
  end
end

return M
