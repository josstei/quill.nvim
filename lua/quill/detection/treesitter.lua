---TreeSitter-based comment detection system
---Provides accurate language detection for embedded languages and context-aware commenting
---@module quill.detection.treesitter

local languages = require("quill.detection.languages")

local M = {}

---Node type names that represent comments across different language parsers
---Used by multiple parsers including: lua, javascript, typescript, python, rust, go, etc.
---Common variants: comment, line_comment, block_comment, doc_comment
---@type table<string, boolean>
local COMMENT_NODE_TYPES = {
  ["comment"] = true,
  ["line_comment"] = true,
  ["block_comment"] = true,
  ["doc_comment"] = true,
  ["comment_block"] = true,
  ["shebang"] = true,
}

---Node type names that represent strings across different language parsers
---Used by multiple parsers including: javascript, typescript, python, rust, go, etc.
---Covers quoted strings, template strings, raw strings, and string content nodes
---@type table<string, boolean>
local STRING_NODE_TYPES = {
  ["string"] = true,
  ["string_literal"] = true,
  ["string_content"] = true,
  ["template_string"] = true,
  ["quoted_string"] = true,
  ["raw_string"] = true,
  ["interpreted_string_literal"] = true,
}

---Node type names that represent JSX markup elements
---Used by tree-sitter-javascript and tree-sitter-typescript parsers for JSX/TSX
---Includes elements, fragments, and opening/closing tags
---@type table<string, boolean>
local JSX_NODE_TYPES = {
  ["jsx_element"] = true,
  ["jsx_fragment"] = true,
  ["jsx_self_closing_element"] = true,
  ["jsx_opening_element"] = true,
  ["jsx_closing_element"] = true,
}

---Node type names that represent JSX JavaScript expressions
---Used by tree-sitter-javascript and tree-sitter-typescript parsers for JSX/TSX
---Represents JavaScript code embedded within JSX via {...} syntax
---@type table<string, boolean>
local JSX_EXPRESSION_TYPES = {
  ["jsx_expression"] = true,
  ["jsx_expression_statement"] = true,
}

---JSX comment style for markup contexts
---JSX markup uses {/* */} syntax instead of HTML <!-- --> or JS //
---@type CommentStyle
local JSX_COMMENT_STYLE = {
  line = nil,
  block = { "{/*", "*/}" },
  supports_nesting = false,
  jsx = true,
}

---Check if TreeSitter parser is available for buffer
---@param bufnr number Buffer number (0 for current buffer)
---@return boolean
function M.is_available(bufnr)
  bufnr = bufnr or 0

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  return ok and parser ~= nil
end

---Get the language at a specific position in the buffer
---Handles embedded languages (e.g., JS in HTML, CSS in HTML)
---@param bufnr number Buffer number (0 for current buffer)
---@param row number Row position (0-indexed)
---@param col number Column position (0-indexed)
---@return string|nil Language string or nil if unavailable
function M.get_lang_at_position(bufnr, row, col)
  bufnr = bufnr or 0

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return nil
  end

  -- Get the language tree for this position
  local lang_tree = parser:language_for_range({ row, col, row, col })
  if not lang_tree then
    return nil
  end

  -- Return the language name
  return lang_tree:lang()
end

---Walk up the syntax tree to find an ancestor node matching a predicate
---@param node TSNode Starting node
---@param predicate fun(node: TSNode): boolean Predicate function that tests each ancestor
---@return TSNode|nil Matching ancestor node or nil if none found
local function find_ancestor(node, predicate)
  local current = node

  while current do
    if predicate(current) then
      return current
    end
    current = current:parent()
  end

  return nil
end

---Check if position is inside a comment node
---@param bufnr number Buffer number (0 for current buffer)
---@param row number Row position (0-indexed)
---@param col number Column position (0-indexed)
---@return boolean
function M.is_in_comment(bufnr, row, col)
  bufnr = bufnr or 0

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return false
  end

  -- Get the language tree for this position
  local lang_tree = parser:language_for_range({ row, col, row, col })
  if not lang_tree then
    return false
  end

  -- Get the syntax trees (plural - can be multiple)
  local trees = lang_tree:trees()
  if not trees or #trees == 0 then
    return false
  end

  -- Check each tree for a node at this position
  for _, tree in ipairs(trees) do
    local root = tree:root()
    if root then
      -- Find the smallest node at this position
      local node = root:descendant_for_range(row, col, row, col)
      if node then
        -- Check if current node or any ancestor is a comment
        local is_comment = find_ancestor(node, function(n)
          return COMMENT_NODE_TYPES[n:type()] == true
        end)

        if is_comment then
          return true
        end
      end
    end
  end

  return false
end

---Check if position is inside JSX markup context
---Returns true if inside JSX markup, false if inside JS expression within JSX
---Uses "nearest context wins" logic: if the closest context-determining ancestor
---is a JSX element, we're in JSX context. If it's a JSX expression, we're in JS context.
---
---Example:
---  <div>{items.map(item => <span>{item}</span>)}</div>
---  - The <span> tag is in JSX context (nearest is jsx_element)
---  - The {item} expression is in JS context (nearest is jsx_expression)
---
---@param bufnr number Buffer number (0 for current buffer)
---@param row number Row position (0-indexed)
---@param col number Column position (0-indexed)
---@return boolean
function M.is_in_jsx_context(bufnr, row, col)
  bufnr = bufnr or 0

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return false
  end

  -- Get the language tree for this position
  local lang_tree = parser:language_for_range({ row, col, row, col })
  if not lang_tree then
    return false
  end

  -- Get the syntax trees (plural - can be multiple)
  local trees = lang_tree:trees()
  if not trees or #trees == 0 then
    return false
  end

  -- Check each tree for a node at this position
  for _, tree in ipairs(trees) do
    local root = tree:root()
    if root then
      -- Find the smallest node at this position
      local node = root:descendant_for_range(row, col, row, col)
      if node then
        -- Walk up ancestors to find the nearest context-determining node
        -- Context is determined by JSX elements or JSX expressions
        -- The NEAREST (closest to cursor) context wins
        local current = node
        while current do
          local node_type = current:type()

          -- If we hit a JSX expression first, we're in JS context
          if JSX_EXPRESSION_TYPES[node_type] then
            return false
          end

          -- If we hit a JSX element first, we're in JSX context
          if JSX_NODE_TYPES[node_type] then
            return true
          end

          current = current:parent()
        end
      end
    end
  end

  return false
end

---Get the appropriate comment style for a buffer position
---Uses TreeSitter to detect language and context (JSX, embedded languages)
---Falls back to language definitions if TreeSitter unavailable
---@param bufnr number Buffer number (0 for current buffer)
---@param row number Row position (0-indexed)
---@param col number Column position (0-indexed)
---@return CommentStyle|nil Comment style or nil if unavailable
function M.get_comment_style(bufnr, row, col)
  bufnr = bufnr or 0

  -- Check if TreeSitter is available
  if not M.is_available(bufnr) then
    -- Fall back to buffer filetype
    local filetype = vim.bo[bufnr].filetype
    return languages.get_style(filetype) or languages.get_default(bufnr)
  end

  -- Get language at position
  local lang = M.get_lang_at_position(bufnr, row, col)
  if not lang then
    -- Fall back to buffer filetype
    local filetype = vim.bo[bufnr].filetype
    return languages.get_style(filetype) or languages.get_default(bufnr)
  end

  -- Special case: Check for JSX context in React files
  -- If we're in JSX markup (not in JS expression), use JSX-style comments
  local filetype = vim.bo[bufnr].filetype
  local is_react = filetype == "javascriptreact" or filetype == "typescriptreact"

  if is_react and M.is_in_jsx_context(bufnr, row, col) then
    -- JSX markup uses {/* */} comment syntax
    return JSX_COMMENT_STYLE
  end

  -- Get the comment style for the detected language
  local style = languages.get_style(lang)

  if style then
    return style
  end

  -- Fall back to buffer filetype if language not in registry
  return languages.get_style(filetype) or languages.get_default(bufnr)
end

return M
