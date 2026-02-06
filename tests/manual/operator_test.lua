---Manual test for operators
---Run with: nvim --clean -u tests/manual_operator_test.lua

-- Add plugin to runtimepath
vim.opt.rtp:prepend(vim.fn.getcwd())

-- Setup the plugin
require("quill").setup({})

-- Create test buffer
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(bufnr)
vim.bo.filetype = "lua"

-- Set initial content
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "local x = 1",
  "local y = 2",
  "local z = 3",
  "",
  "function test()",
  "  print('hello')",
  "end",
})

print("=== Operator Test Buffer Created ===")
print("Try these commands:")
print("  gcc     - Toggle current line")
print("  gc2j    - Toggle current line + 2 down")
print("  gcip    - Toggle paragraph")
print("  V2jgc   - Visual select 3 lines, toggle")
print("  :q      - Quit test")
print("")
print("Initial content:")
for i, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
  print(string.format("  %d: %s", i, line))
end
