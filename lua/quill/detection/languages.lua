---@class CommentStyle
---@field line string|nil           Line comment marker (e.g., "//", "#")
---@field block [string, string]|nil  Block comment pair (e.g., {"/*", "*/"})
---@field supports_nesting boolean  Can block comments nest?
---@field jsx boolean               Is this a JSX context?

local M = {}

---Filetype aliases for common variations
---@type table<string, string>
local FILETYPE_ALIASES = {
  -- JSX/TSX aliases
  jsx = "javascriptreact",
  tsx = "typescriptreact",
  ["javascript.jsx"] = "javascriptreact",
  ["typescript.tsx"] = "typescriptreact",
}

---Language-specific comment styles
---@type table<string, CommentStyle>
local LANGUAGE_STYLES = {
  -- Lua
  lua = {
    line = "--",
    block = { "--[[", "]]" },
    supports_nesting = false,
    jsx = false,
  },

  -- Python
  python = {
    line = "#",
    block = { '"""', '"""' },
    supports_nesting = false,
    jsx = false,
  },

  -- JavaScript
  javascript = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- TypeScript
  typescript = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- JSX (JavaScript React)
  javascriptreact = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = true,
  },

  -- TSX (TypeScript React)
  typescriptreact = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = true,
  },

  -- CSS
  css = {
    line = nil,
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- SCSS
  scss = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- Less
  less = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- HTML
  html = {
    line = nil,
    block = { "<!--", "-->" },
    supports_nesting = false,
    jsx = false,
  },

  -- XML
  xml = {
    line = nil,
    block = { "<!--", "-->" },
    supports_nesting = false,
    jsx = false,
  },

  -- Rust
  rust = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = true,
    jsx = false,
  },

  -- Go
  go = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- C
  c = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- C++
  cpp = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- Objective-C
  objc = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- Ruby
  ruby = {
    line = "#",
    block = { "=begin", "=end" },
    supports_nesting = false,
    jsx = false,
  },

  -- Bash
  bash = {
    line = "#",
    block = nil,
    supports_nesting = false,
    jsx = false,
  },

  -- Shell
  sh = {
    line = "#",
    block = nil,
    supports_nesting = false,
    jsx = false,
  },

  -- Zsh
  zsh = {
    line = "#",
    block = nil,
    supports_nesting = false,
    jsx = false,
  },

  -- SQL
  sql = {
    line = "--",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- Vim
  vim = {
    line = '"',
    block = nil,
    supports_nesting = false,
    jsx = false,
  },

  -- YAML
  yaml = {
    line = "#",
    block = nil,
    supports_nesting = false,
    jsx = false,
  },

  -- TOML
  toml = {
    line = "#",
    block = nil,
    supports_nesting = false,
    jsx = false,
  },

  -- JSON (no comments)
  json = {
    line = nil,
    block = nil,
    supports_nesting = false,
    jsx = false,
  },

  -- JSONC (JSON with Comments)
  jsonc = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- Markdown
  markdown = {
    line = nil,
    block = { "<!--", "-->" },
    supports_nesting = false,
    jsx = false,
  },

  -- Java
  java = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- C#
  cs = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- PHP
  php = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- Perl
  perl = {
    line = "#",
    block = { "=pod", "=cut" },
    supports_nesting = false,
    jsx = false,
  },

  -- Haskell
  haskell = {
    line = "--",
    block = { "{-", "-}" },
    supports_nesting = true,
    jsx = false,
  },

  -- Elixir
  elixir = {
    line = "#",
    block = nil,
    supports_nesting = false,
    jsx = false,
  },

  -- Erlang
  erlang = {
    line = "%",
    block = nil,
    supports_nesting = false,
    jsx = false,
  },

  -- OCaml
  ocaml = {
    line = nil,
    block = { "(*", "*)" },
    supports_nesting = true,
    jsx = false,
  },

  -- Swift
  swift = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = true,
    jsx = false,
  },

  -- Kotlin
  kotlin = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- Scala
  scala = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- R
  r = {
    line = "#",
    block = nil,
    supports_nesting = false,
    jsx = false,
  },

  -- LaTeX
  tex = {
    line = "%",
    block = nil,
    supports_nesting = false,
    jsx = false,
  },

  -- Zig
  zig = {
    line = "//",
    block = nil,
    supports_nesting = false,
    jsx = false,
  },

  -- Dart
  dart = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  },

  -- Nim
  nim = {
    line = "#",
    block = { "#[", "]#" },
    supports_nesting = true,
    jsx = false,
  },

  -- Clojure
  clojure = {
    line = ";",
    block = nil,
    supports_nesting = false,
    jsx = false,
  },

  -- Scheme
  scheme = {
    line = ";",
    block = { "#|", "|#" },
    supports_nesting = true,
    jsx = false,
  },

  -- Racket
  racket = {
    line = ";",
    block = { "#|", "|#" },
    supports_nesting = true,
    jsx = false,
  },

  -- Lisp
  lisp = {
    line = ";",
    block = { "#|", "|#" },
    supports_nesting = true,
    jsx = false,
  },
}

---Get comment style for a specific filetype
---Handles filetype aliases and validates block comment structure
---@param filetype string
---@return CommentStyle|nil
function M.get_style(filetype)
  -- Resolve aliases
  local resolved_filetype = FILETYPE_ALIASES[filetype] or filetype

  local style = LANGUAGE_STYLES[resolved_filetype]

  if not style then
    return nil
  end

  -- Validate block comment structure
  if style.block then
    assert(
      type(style.block) == "table" and #style.block == 2,
      string.format("Invalid block comment structure for %s: must have exactly 2 elements", resolved_filetype)
    )
  end

  return style
end

---Common block comment patterns to detect
---@type table<string, [string, string]>
local BLOCK_PATTERNS = {
  ["/**/"] = { "/*", "*/" },
  ["<!---->"] = { "<!--", "-->" },
  ["{--}"] = { "{-", "-}" },
  ["(**)"] = { "(*", "*)" },
  ["#[]#"] = { "#[", "]#" },
  ["#||#"] = { "#|", "|#" },
}

---Parse vim commentstring to extract comment markers
---Detects both line comments and block comment patterns
---@param commentstring string
---@return table|nil Returns {line = string} or {block = {string, string}} or nil
local function parse_commentstring(commentstring)
  if not commentstring or commentstring == "" then
    return nil
  end

  -- Remove %s placeholder and trim whitespace
  local marker = commentstring:gsub("%%s", ""):gsub("^%s+", ""):gsub("%s+$", "")

  if marker == "" then
    return nil
  end

  -- Check if it matches a known block comment pattern
  if BLOCK_PATTERNS[marker] then
    return { block = BLOCK_PATTERNS[marker] }
  end

  -- Try to detect paired markers (e.g., "/* */", "<!-- -->")
  -- Look for two distinct parts separated by space or with symmetric structure
  local start_marker, end_marker = marker:match("^(.-)%s+(.+)$")
  if start_marker and end_marker and start_marker ~= "" and start_marker ~= end_marker then
    -- Found space-separated pair
    return { block = { start_marker, end_marker } }
  end

  -- Check for common symmetric patterns without space
  -- E.g., "/**/" -> "/*" and "*/"
  if marker:match("^/%*.*%*/$") then
    local start = marker:match("^(/%*.-)%*.$")
    if start then
      local end_part = marker:sub(#start + 1)
      return { block = { start, end_part } }
    end
  end

  if marker:match("^<!%-%-.*%-%-") then
    return { block = { "<!--", "-->" } }
  end

  -- Otherwise treat as line comment
  return { line = marker }
end

---Get default comment style from vim.bo.commentstring
---Falls back to commentstring when no explicit language definition exists
---Supports both line and block comment detection from commentstring
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@return CommentStyle|nil
function M.get_default(bufnr)
  bufnr = bufnr or 0

  local commentstring = vim.bo[bufnr].commentstring

  local parsed = parse_commentstring(commentstring)

  if not parsed then
    return nil
  end

  return {
    line = parsed.line or nil,
    block = parsed.block or nil,
    supports_nesting = false,
    jsx = false,
  }
end

return M
