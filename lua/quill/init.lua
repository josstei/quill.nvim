local M = {}

local config = require("quill.config")
local keymaps = require("quill.keymaps")
local commands = require("quill.commands")
local toggle = require("quill.core.toggle")
local detect = require("quill.core.detect")
local textobjects = require("quill.textobjects")
local utils = require("quill.utils")

local initialized = false

function M.setup(opts)
  if initialized then
    return
  end

  if not config.setup(opts) then
    return
  end

  keymaps.setup()
  textobjects.setup(config.get())
  commands.setup()

  initialized = true
end

function M.toggle_line()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.fn.line(".")
  return toggle.toggle_line(bufnr, line, {})
end

function M.toggle_range(start_line, end_line)
  utils.assert_numbers("lines", start_line, end_line)
  local bufnr = vim.api.nvim_get_current_buf()
  return toggle.toggle_lines(bufnr, start_line, end_line, {})
end

function M.comment(start_line, end_line, style)
  utils.assert_numbers("lines", start_line, end_line)
  if style and style ~= "line" and style ~= "block" then
    error("style must be 'line' or 'block'")
  end
  local bufnr = vim.api.nvim_get_current_buf()
  return toggle.toggle_lines(bufnr, start_line, end_line, {
    force_comment = true,
    style_type = style,
  })
end

function M.uncomment(start_line, end_line)
  utils.assert_numbers("lines", start_line, end_line)
  local bufnr = vim.api.nvim_get_current_buf()
  return toggle.toggle_lines(bufnr, start_line, end_line, {
    force_uncomment = true,
  })
end

function M.get_style(bufnr, line, col)
  utils.assert_numbers("bufnr", bufnr)
  utils.assert_numbers("line", line)
  utils.assert_numbers("col", col)
  return detect.get_comment_style(bufnr, line, col)
end

function M.is_commented(bufnr, line)
  utils.assert_numbers("bufnr", bufnr)
  utils.assert_numbers("line", line)
  return detect.is_commented(bufnr, line)
end

function M.normalize(bufnr)
  if bufnr then
    utils.assert_numbers("bufnr", bufnr)
  end
  local normalize = require("quill.features.normalize")
  return normalize.normalize_buffer(bufnr)
end

function M.align(start_line, end_line, opts)
  utils.assert_numbers("lines", start_line, end_line)
  if opts and type(opts) ~= "table" then
    error("opts must be a table")
  end
  local align = require("quill.features.align")
  local bufnr = vim.api.nvim_get_current_buf()
  return align.align_lines(bufnr, start_line, end_line, opts)
end

function M.toggle_debug(scope)
  if scope and scope ~= "buffer" and scope ~= "project" then
    error("scope must be 'buffer' or 'project'")
  end
  local debug = require("quill.features.debug")
  if scope == "project" then
    return debug.toggle_project()
  else
    return debug.toggle_buffer()
  end
end

return M
