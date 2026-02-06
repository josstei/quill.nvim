---Text object support for selecting comment blocks and lines
---Provides `ic`, `ac`, `iC`, and `aC` text objects for operator-pending and visual modes
---@module quill.textobjects

local detect = require("quill.core.detect")
local regex = require("quill.detection.regex")

local M = {}

---Find bounds of contiguous comment block
---A comment block consists of consecutive commented lines with no empty lines
---@param bufnr number Buffer number
---@param line number Current line (1-indexed)
---@return number|nil start_line Start of comment block
---@return number|nil end_line End of comment block
function M.find_comment_block_bounds(bufnr, line)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil, nil
  end

  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  if line < 1 or line > total_lines then
    return nil, nil
  end

  -- Check if current line is commented
  if not detect.is_commented(bufnr, line) then
    return nil, nil
  end

  local start_line = line
  local end_line = line

  -- Find start of block (search upward)
  while start_line > 1 do
    local prev_line = start_line - 1
    if not detect.is_commented(bufnr, prev_line) then
      break
    end
    start_line = prev_line
  end

  -- Find end of block (search downward)
  while end_line < total_lines do
    local next_line = end_line + 1
    if not detect.is_commented(bufnr, next_line) then
      break
    end
    end_line = next_line
  end

  return start_line, end_line
end

---Extract content from a commented line (without markers)
---@param bufnr number Buffer number
---@param line_num number Line number (1-indexed)
---@return string|nil content Content without comment markers
---@return number|nil start_col Start column of content (1-indexed)
---@return number|nil end_col End column of content (1-indexed)
local function extract_line_content(bufnr, line_num)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
  if #lines == 0 then
    return nil, nil, nil
  end

  local line_text = lines[1]
  if not line_text or line_text == "" then
    return nil, nil, nil
  end

  -- Get comment style for this line
  local style = detect.get_comment_style(bufnr, line_num, 0)
  if not style then
    return nil, nil, nil
  end

  -- Get the original indentation
  local indent = line_text:match("^(%s*)")
  local indent_len = #indent

  -- Strip comment markers to get content
  local stripped = regex.strip_comment(line_text, style)
  local content = stripped:match("^%s*(.-)%s*$")

  if content == "" then
    -- Empty comment line
    return "", indent_len + 1, indent_len + 1
  end

  -- Find content start and end positions in original line
  -- The stripped line preserves indentation, so content starts after indent
  local content_start = stripped:find(content, indent_len + 1, true)
  if not content_start then
    return nil, nil, nil
  end

  local content_end = content_start + #content - 1

  return content, content_start, content_end
end

---Select inner comment block (ic)
---Selects content of contiguous commented lines without markers
function M.select_inner_block()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  local start_line, end_line = M.find_comment_block_bounds(bufnr, line)
  if not start_line or not end_line then
    -- Not in a comment block, do nothing
    return
  end

  -- For inner block, we select characterwise from first content char to last
  local first_content, first_start = extract_line_content(bufnr, start_line)
  local last_content, _, last_end = extract_line_content(bufnr, end_line)

  if not first_content or not last_content then
    return
  end

  -- Set visual selection
  vim.api.nvim_win_set_cursor(0, { start_line, (first_start or 1) - 1 })
  vim.cmd("normal! v")
  vim.api.nvim_win_set_cursor(0, { end_line, (last_end or 1) - 1 })
end

---Select around comment block (ac)
---Selects entire commented lines including markers
function M.select_around_block()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  local start_line, end_line = M.find_comment_block_bounds(bufnr, line)
  if not start_line or not end_line then
    -- Not in a comment block, do nothing
    return
  end

  -- Select entire lines (linewise)
  vim.api.nvim_win_set_cursor(0, { start_line, 0 })
  vim.cmd("normal! V")
  vim.api.nvim_win_set_cursor(0, { end_line, 0 })
end

---Select inner comment line (iC)
---Selects content of current commented line without marker
function M.select_inner_line()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  -- Check if line is commented
  if not detect.is_commented(bufnr, line) then
    -- Not on a commented line, do nothing
    return
  end

  local content, start_col, end_col = extract_line_content(bufnr, line)
  if not content then
    return
  end

  if content == "" then
    -- Empty comment, select at marker position
    vim.api.nvim_win_set_cursor(0, { line, (start_col or 1) - 1 })
    vim.cmd("normal! v")
    vim.api.nvim_win_set_cursor(0, { line, (start_col or 1) - 1 })
    return
  end

  -- Select content only
  vim.api.nvim_win_set_cursor(0, { line, (start_col or 1) - 1 })
  vim.cmd("normal! v")
  vim.api.nvim_win_set_cursor(0, { line, (end_col or 1) - 1 })
end

---Select around comment line (aC)
---Selects entire current line if it's commented
function M.select_around_line()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  -- Check if line is commented
  if not detect.is_commented(bufnr, line) then
    -- Not on a commented line, do nothing
    return
  end

  -- Select entire line (linewise)
  vim.api.nvim_win_set_cursor(0, { line, 0 })
  vim.cmd("normal! V")
end

---Setup text object mappings
---Registers keymaps in operator-pending and visual modes
---@param config table|nil Configuration (optional)
function M.setup(config)
  config = config or {}
  local mappings = config.textobjects or {
    inner_block = "ic",
    around_block = "ac",
    inner_line = "iC",
    around_line = "aC",
  }

  -- Register text objects in operator-pending and visual modes
  local modes = { "o", "x" }

  if mappings.inner_block then
    vim.keymap.set(modes, mappings.inner_block, M.select_inner_block, {
      desc = "Inner comment block (content only)",
      silent = true,
    })
  end

  if mappings.around_block then
    vim.keymap.set(modes, mappings.around_block, M.select_around_block, {
      desc = "Around comment block (with markers)",
      silent = true,
    })
  end

  if mappings.inner_line then
    vim.keymap.set(modes, mappings.inner_line, M.select_inner_line, {
      desc = "Inner comment line (content only)",
      silent = true,
    })
  end

  if mappings.around_line then
    vim.keymap.set(modes, mappings.around_line, M.select_around_line, {
      desc = "Around comment line (entire line)",
      silent = true,
    })
  end
end

return M
