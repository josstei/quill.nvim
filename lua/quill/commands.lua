---Command dispatcher for :Quill user command
---Routes subcommands to appropriate feature modules
---@module quill.commands

local M = {}

local debug = require("quill.features.debug")
local normalize = require("quill.features.normalize")
local align = require("quill.features.align")
local convert = require("quill.features.convert")

---Parse command arguments from raw string
---@param args_string string Raw argument string
---@return string[] args Parsed arguments
local function parse_args(args_string)
  local args = {}
  for arg in args_string:gmatch("%S+") do
    table.insert(args, arg)
  end
  return args
end

---Handle debug subcommand
---Supports: debug, debug --project, debug --list
---@param args table Command arguments from nvim_create_user_command
local function cmd_debug(args)
  local parsed = parse_args(args.args)
  table.remove(parsed, 1)

  local has_project = vim.tbl_contains(parsed, "--project")
  local has_list = vim.tbl_contains(parsed, "--list")

  if has_list then
    local scope = has_project and "project" or "buffer"
    debug.list_regions(scope)
  elseif has_project then
    debug.toggle_project({ confirm = true, preview = true })
  else
    debug.toggle_buffer()
  end
end

---Handle normalize subcommand
---Supports: normalize (buffer), :'<,'>normalize (range)
---@param args table Command arguments
local function cmd_normalize(args)
  local bufnr = vim.api.nvim_get_current_buf()

  if args.range == 2 then
    local count = normalize.normalize_range(bufnr, args.line1, args.line2)
    vim.notify(string.format("Normalized %d lines", count), vim.log.levels.INFO)
  else
    local count = normalize.normalize_buffer(bufnr)
    vim.notify(string.format("Normalized %d lines", count), vim.log.levels.INFO)
  end
end

---Handle align subcommand
---Supports: :'<,'>align (requires visual selection)
---@param args table Command arguments
local function cmd_align(args)
  if args.range ~= 2 then
    vim.notify("Quill align requires a visual selection", vim.log.levels.ERROR)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local count = align.align_lines(bufnr, args.line1, args.line2)
  vim.notify(string.format("Aligned %d lines", count), vim.log.levels.INFO)
end

---Handle convert subcommand
---Supports: :'<,'>convert line, :'<,'>convert block
---@param args table Command arguments
local function cmd_convert(args)
  if args.range ~= 2 then
    vim.notify("Quill convert requires a visual selection", vim.log.levels.ERROR)
    return
  end

  local parsed = parse_args(args.args)
  table.remove(parsed, 1)

  local target = parsed[1]
  if not target then
    vim.notify("Usage: Quill convert <line|block>", vim.log.levels.ERROR)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local result

  if target == "line" then
    result = convert.convert_to_line(bufnr, args.line1, args.line2)
  elseif target == "block" then
    result = convert.convert_to_block(bufnr, args.line1, args.line2)
  else
    vim.notify("Unknown target: " .. target .. ". Use 'line' or 'block'", vim.log.levels.ERROR)
    return
  end

  if not result.success then
    vim.notify(result.error_msg, vim.log.levels.ERROR)
  else
    vim.notify(
      string.format("Converted %d lines to %s comments", result.count, target),
      vim.log.levels.INFO
    )
  end
end

---Main dispatch function
---Routes subcommand to appropriate handler
---@param args table Command arguments from nvim_create_user_command
local function dispatch(args)
  local parsed = parse_args(args.args)
  local subcommand = parsed[1]

  if not subcommand then
    vim.notify("Usage: Quill <debug|normalize|align|convert>", vim.log.levels.ERROR)
    return
  end

  local handlers = {
    debug = cmd_debug,
    normalize = cmd_normalize,
    align = cmd_align,
    convert = cmd_convert,
  }

  local handler = handlers[subcommand]
  if not handler then
    vim.notify("Unknown subcommand: " .. subcommand, vim.log.levels.ERROR)
    return
  end

  handler(args)
end

---Completion function for command arguments
---Provides tab-completion for subcommands and their options
---@param arglead string Current argument being completed
---@param cmdline string Full command line
---@param cursorpos number Cursor position
---@return string[] completions
local function complete(arglead, cmdline, cursorpos)
  local parts = vim.split(cmdline, "%s+")

  if #parts <= 2 then
    local subcommands = { "debug", "normalize", "align", "convert" }
    return vim.tbl_filter(function(s)
      return s:find(arglead, 1, true) == 1
    end, subcommands)
  end

  local subcommand = parts[2]

  if subcommand == "debug" then
    local options = { "--project", "--list" }
    return vim.tbl_filter(function(s)
      return s:find(arglead, 1, true) == 1
    end, options)
  elseif subcommand == "convert" then
    local targets = { "line", "block" }
    return vim.tbl_filter(function(s)
      return s:find(arglead, 1, true) == 1
    end, targets)
  end

  return {}
end

---Setup the :Quill command
---Registers user command with completion
function M.setup()
  vim.api.nvim_create_user_command("Quill", dispatch, {
    nargs = "+",
    range = true,
    complete = complete,
    desc = "Quill commands: debug, normalize, align, convert",
  })
end

return M
