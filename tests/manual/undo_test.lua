---Manual test to verify undo grouping behavior in real Neovim
---Run this with: nvim --clean -u tests/manual_undo_test.lua

-- Add lua directory to package path
vim.opt.runtimepath:append(".")

local undo = require("quill.core.undo")

print("=== Testing Undo Grouping ===")
print()

-- Create a test buffer
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(bufnr)

-- Set initial content
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "line 1",
  "line 2",
  "line 3",
  "line 4",
  "line 5",
})

print("Initial buffer content:")
print(table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n"))
print()

-- Wait for user to see initial state
print("Press ENTER to comment all lines in a single undo group...")
vim.fn.getchar()

-- Comment all lines in a single undo group
undo.with_undo_group(function()
  for i = 0, 4 do
    local line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
    vim.api.nvim_buf_set_lines(bufnr, i, i + 1, false, { "// " .. line })
  end
end)

print("After commenting:")
print(table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n"))
print()

-- Instructions for manual testing
print("=== Manual Testing Instructions ===")
print("1. Press 'u' to undo - ALL 5 lines should revert at once")
print("2. Press Ctrl-R to redo - ALL 5 lines should be commented again")
print("3. Verify that a single 'u' undoes the entire operation")
print()
print("Press ENTER to test manual start/end style...")
vim.fn.getchar()

-- Reset buffer
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "manual 1",
  "manual 2",
  "manual 3",
})

print()
print("Buffer reset to:")
print(table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n"))
print()

-- Test manual start/end
print("Pressing ENTER will use manual start/end_undo_group...")
vim.fn.getchar()

undo.start_undo_group()

for i = 0, 2 do
  local line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
  vim.api.nvim_buf_set_lines(bufnr, i, i + 1, false, { "# " .. line })
end

undo.end_undo_group()

print("After manual group commenting:")
print(table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n"))
print()

print("Again, press 'u' to verify all 3 lines undo together")
print()
print("Test complete! Press ENTER to exit")
vim.fn.getchar()
