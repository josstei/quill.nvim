---Shared test helpers for quill.nvim test suite
---@module tests.helpers

local M = {}

---Create a test buffer with optional content and filetype
---@param opts? {lines: string[]?, filetype: string?}
---@return number bufnr
function M.create_buffer(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_create_buf(false, true)

  if opts.lines then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, opts.lines)
  end

  if opts.filetype then
    vim.bo[bufnr].filetype = opts.filetype
  end

  return bufnr
end

---Delete a buffer safely
---@param bufnr number Buffer number
function M.delete_buffer(bufnr)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---Get buffer lines (1-indexed, inclusive)
---@param bufnr number Buffer number
---@param start_line? number Start line (default 1)
---@param end_line? number End line (default last)
---@return string[]
function M.get_buffer_lines(bufnr, start_line, end_line)
  start_line = start_line or 1
  end_line = end_line or vim.api.nvim_buf_line_count(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
end

return M
