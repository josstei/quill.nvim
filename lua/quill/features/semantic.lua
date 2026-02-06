---@class SemanticConfig
---@field include_decorators boolean Include decorators when commenting functions
---@field include_doc_comments boolean Include doc comments when commenting functions

local utils = require("quill.utils")

local M = {}

local config = {
  include_decorators = true,
  include_doc_comments = true,
}

local DECORATOR_PATTERNS = {
  python = "^%s*@%w+",
  typescript = "^%s*@%w+",
  javascript = "^%s*@%w+",
  java = "^%s*@%w+",
}

local MAX_DOCSTRING_SEARCH_LINES = 20

local FUNCTION_PATTERNS = {
  python = "^%s*def%s+%w+",
  javascript = "^%s*function%s+%w+",
  typescript = "^%s*function%s+%w+",
  lua = "^%s*function%s+%w+",
  c = "^%s*%w+%s+%w+%s*%(.*%)%s*{",
  cpp = "^%s*%w+%s+%w+%s*%(.*%)%s*{",
  java = "^%s*%w+%s+%w+%s*%(.*%)%s*{",
  rust = "^%s*fn%s+%w+",
}

--- Check if a line is a decorator
---@param line_text string The line text
---@param filetype string The buffer filetype
---@return boolean is_decorator
local function is_decorator_line(line_text, filetype)
  local pattern = DECORATOR_PATTERNS[filetype]
  if not pattern then
    return false
  end
  return line_text:match(pattern) ~= nil
end

--- Find decorators attached to a function
---@param bufnr number Buffer number
---@param func_start_line number Line where function starts (1-indexed)
---@return number[] decorator_lines List of decorator line numbers
function M.find_attached_decorators(bufnr, func_start_line)
  local filetype = vim.bo[bufnr].filetype
  local decorator_pattern = DECORATOR_PATTERNS[filetype]

  if not decorator_pattern then
    return {}
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, func_start_line, false)
  local decorators = {}

  -- Walk backwards from function start
  local current_line = func_start_line - 1
  while current_line > 0 do
    local line_text = lines[current_line]

    -- Stop at blank line
    if utils.is_blank_line(line_text) then
      break
    end

    -- Check if decorator
    if is_decorator_line(line_text, filetype) then
      table.insert(decorators, 1, current_line)
    else
      -- Non-decorator, non-blank line - stop
      break
    end

    current_line = current_line - 1
  end

  return decorators
end

--- Try to find function node using TreeSitter
---@param bufnr number Buffer number
---@param line number Line number (1-indexed)
---@return table|nil node TreeSitter node or nil
local function find_function_node_ts(bufnr, line)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return nil
  end

  local parse_ok, trees = pcall(function() return parser:parse() end)
  if not parse_ok or not trees or #trees == 0 then
    return nil
  end

  local root = trees[1]:root()

  -- Function-like node types
  local function_types = {
    "function_definition",
    "function_declaration",
    "method_definition",
    "method_declaration",
    "function_item",
    "function",
    "arrow_function",
  }

  -- Convert 1-indexed line to 0-indexed for TreeSitter
  local target_line = line - 1

  local function find_containing_function(node)
    if not node then
      return nil
    end

    local node_type = node:type()
    local start_row, _, end_row, _ = node:range()

    -- Check if this node contains our target line
    if start_row <= target_line and target_line <= end_row then
      -- Check if it's a function node
      for _, func_type in ipairs(function_types) do
        if node_type == func_type then
          return node
        end
      end

      -- Recurse into children
      for child in node:iter_children() do
        local result = find_containing_function(child)
        if result then
          return result
        end
      end
    end

    return nil
  end

  return find_containing_function(root)
end

--- Find function start using regex patterns
---@param bufnr number Buffer number
---@param line number Starting line (1-indexed)
---@return number|nil func_start Function start line or nil
local function find_function_start_regex(bufnr, line)
  local filetype = vim.bo[bufnr].filetype
  local pattern = FUNCTION_PATTERNS[filetype]

  if not pattern then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, line, false)

  -- Search backwards from current line
  for i = line, 1, -1 do
    local line_text = lines[i]
    if line_text:match(pattern) then
      return i
    end
  end

  return nil
end

--- Find function end using indentation heuristic
---@param bufnr number Buffer number
---@param func_start_line number Function start line (1-indexed)
---@return number func_end Function end line
local function find_function_end_heuristic(bufnr, func_start_line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local total_lines = #lines

  -- Get indentation of function definition
  local func_line = lines[func_start_line]
  local func_indent = func_line:match("^%s*")

  -- Track last non-blank line in function body
  local last_body_line = func_start_line

  -- Find first line with same or less indentation (non-blank)
  for i = func_start_line + 1, total_lines do
    local line_text = lines[i]
    if not utils.is_blank_line(line_text) then
      local line_indent = line_text:match("^%s*")
      if #line_indent <= #func_indent then
        -- Found next item at same or lower indentation
        return last_body_line
      end
      -- This line is still part of function body
      last_body_line = i
    end
  end

  return last_body_line
end

--- Find function bounds including decorators
---@param bufnr number Buffer number
---@param line number Current line (1-indexed)
---@return { start_line: number, end_line: number }|nil bounds
function M.find_function_with_decorators(bufnr, line)
  local func_start = nil
  local func_end = nil

  -- Try TreeSitter first
  local func_node = find_function_node_ts(bufnr, line)
  if func_node then
    local start_row, _, end_row, _ = func_node:range()
    func_start = start_row + 1 -- Convert to 1-indexed
    func_end = end_row + 1
  else
    -- Fallback to regex
    func_start = find_function_start_regex(bufnr, line)
    if not func_start then
      return nil
    end
    func_end = find_function_end_heuristic(bufnr, func_start)
  end

  -- Find attached decorators
  if config.include_decorators then
    local decorators = M.find_attached_decorators(bufnr, func_start)
    if #decorators > 0 then
      func_start = decorators[1]
    end
  end

  return {
    start_line = func_start,
    end_line = func_end,
  }
end

--- Find Python docstring inside function
---@param bufnr number Buffer number
---@param func_start_line number Function definition line (1-indexed)
---@return { start_line: number, end_line: number }|nil doc_bounds
local function find_python_docstring(bufnr, func_start_line)
  -- nvim_buf_get_lines uses 0-indexed start, so func_start_line (1-indexed) gives us the line after
  -- Example: func_start_line=1 means line 1, API call (1, 21) gets lines 2-21 (indices 1-20 in result)
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local end_line = math.min(func_start_line + MAX_DOCSTRING_SEARCH_LINES, total_lines)
  local lines = vim.api.nvim_buf_get_lines(bufnr, func_start_line, end_line, false)

  -- Find first non-blank line after function definition
  local first_statement = nil

  for i = 1, #lines do
    if not utils.is_blank_line(lines[i]) then
      first_statement = i
      break
    end
  end

  if not first_statement then
    return nil
  end

  local first_line = lines[first_statement]

  -- Check for docstring patterns
  local triple_quote_patterns = {
    '^%s*"""',  -- Triple double quotes
    "^%s*'''",  -- Triple single quotes
  }

  for _, pattern in ipairs(triple_quote_patterns) do
    if first_line:match(pattern) then
      local quote_type = first_line:match('"""') and '"""' or "'''"
      -- doc_start is the line number (1-indexed) where the docstring starts
      local doc_start = func_start_line + first_statement

      -- Check if single-line docstring (opening and closing on same line)
      -- Find position after opening quotes
      local opening_end = first_line:find(quote_type)
      if opening_end then
        local after_opening = opening_end + #quote_type
        -- Check if closing quotes appear after the opening
        if first_line:find(quote_type, after_opening) then
          return { start_line = doc_start, end_line = doc_start }
        end
      end

      -- Multi-line docstring - find closing quotes
      for i = first_statement + 1, #lines do
        if lines[i]:match(quote_type) then
          -- Convert array index to line number
          return { start_line = doc_start, end_line = func_start_line + i }
        end
      end
    end
  end

  return nil
end

--- Find JSDoc comment above function
---@param bufnr number Buffer number
---@param func_start_line number Function definition line (1-indexed)
---@return { start_line: number, end_line: number }|nil doc_bounds
local function find_jsdoc_comment(bufnr, func_start_line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, func_start_line, false)

  -- Walk backwards from function to find JSDoc
  local current_line = func_start_line - 1
  local doc_end = nil

  -- Skip blank lines
  while current_line > 0 and utils.is_blank_line(lines[current_line]) do
    current_line = current_line - 1
  end

  -- Check for closing */
  if current_line > 0 and lines[current_line]:match("%*/%s*$") then
    doc_end = current_line
  else
    return nil
  end

  -- Find opening /**
  while current_line > 0 do
    if lines[current_line]:match("^%s*/%*%*") then
      return { start_line = current_line, end_line = doc_end }
    end
    current_line = current_line - 1
  end

  return nil
end

--- Find doc comment for a function
---@param bufnr number Buffer number
---@param line number Function start line (1-indexed)
---@return { start_line: number, end_line: number }|nil doc_bounds
function M.find_doc_comment(bufnr, line)
  local filetype = vim.bo[bufnr].filetype

  if filetype == "python" then
    return find_python_docstring(bufnr, line)
  elseif filetype == "javascript" or filetype == "typescript" or filetype == "javascriptreact" or filetype == "typescriptreact" then
    return find_jsdoc_comment(bufnr, line)
  end

  return nil
end

--- Expand selection to include semantic elements
---@param bufnr number Buffer number
---@param start_line number Selection start (1-indexed)
---@param end_line number Selection end (1-indexed)
---@param opts? { include_decorators: boolean, include_doc_comments: boolean }
---@return number new_start Expanded start line
---@return number new_end Expanded end line
function M.expand_selection_semantic(bufnr, start_line, end_line, opts)
  opts = opts or {}
  local include_decorators = opts.include_decorators
  if include_decorators == nil then
    include_decorators = config.include_decorators
  end
  local include_doc_comments = opts.include_doc_comments
  if include_doc_comments == nil then
    include_doc_comments = config.include_doc_comments
  end

  local new_start = start_line
  local new_end = end_line

  -- Find decorators above start line
  if include_decorators then
    local decorators = M.find_attached_decorators(bufnr, start_line)
    if #decorators > 0 then
      new_start = math.min(new_start, decorators[1])
    end
  end

  -- Find doc comment
  if include_doc_comments then
    local doc_bounds = M.find_doc_comment(bufnr, start_line)
    if doc_bounds then
      -- Determine if doc is above or inside function
      if doc_bounds.start_line < start_line then
        -- JSDoc above function
        new_start = math.min(new_start, doc_bounds.start_line)
      else
        -- Python docstring inside function
        new_end = math.max(new_end, doc_bounds.end_line)
      end
    end
  end

  return new_start, new_end
end

--- Setup with configuration
---@param cfg table Configuration
function M.setup(cfg)
  if cfg and cfg.semantic then
    if cfg.semantic.include_decorators ~= nil then
      config.include_decorators = cfg.semantic.include_decorators
    end
    if cfg.semantic.include_doc_comments ~= nil then
      config.include_doc_comments = cfg.semantic.include_doc_comments
    end
  end
end

return M
