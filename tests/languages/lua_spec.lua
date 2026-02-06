local describe = require("plenary.busted").describe
local it = require("plenary.busted").it
local assert = require("plenary.busted").assert
local before_each = require("plenary.busted").before_each
local after_each = require("plenary.busted").after_each

describe("Lua language support", function()
  local toggle = require("quill.core.toggle")
  local detect = require("quill.core.detect")
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
    vim.api.nvim_set_current_buf(bufnr)
  end)

  after_each(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  describe("comment detection", function()
    it("detects -- line comments", function()
      local style = detect.get_comment_style(bufnr, 1, 0)
      assert.equals("--", style.line)
    end)

    it("detects --[[ ]] block comments", function()
      local style = detect.get_comment_style(bufnr, 1, 0)
      assert.are.same({ "--[[", "]]" }, style.block)
    end)

    it("recognizes commented line", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "-- local x = 1",
      })

      local is_commented = detect.is_commented(bufnr, 1)
      assert.is_true(is_commented)
    end)

    it("recognizes uncommented line", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local x = 1",
      })

      local is_commented = detect.is_commented(bufnr, 1)
      assert.is_false(is_commented)
    end)
  end)

  describe("line comment toggle", function()
    it("comments single line", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local x = 1",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- local x = 1", lines[1])
    end)

    it("uncomments single line", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "-- local x = 1",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("local x = 1", lines[1])
    end)

    it("comments multiple lines", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local x = 1",
        "local y = 2",
        "local z = 3",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- local x = 1", lines[1])
      assert.equals("-- local y = 2", lines[2])
      assert.equals("-- local z = 3", lines[3])
    end)

    it("uncomments multiple lines", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "-- local x = 1",
        "-- local y = 2",
        "-- local z = 3",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("local x = 1", lines[1])
      assert.equals("local y = 2", lines[2])
      assert.equals("local z = 3", lines[3])
    end)
  end)

  describe("block comments", function()
    it("detects block comment start", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "--[[ multiline",
        "comment ]]",
      })

      local is_commented = detect.is_commented(bufnr, 1)
      assert.is_true(is_commented)
    end)

    it("handles nested block comments", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "--[=[ outer",
        "--[[ inner ]]",
        "]=]",
      })

      local is_commented = detect.is_commented(bufnr, 1)
      assert.is_true(is_commented)
    end)
  end)

  describe("indentation", function()
    it("preserves indentation when commenting", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "  local x = 1",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("  -- local x = 1", lines[1])
    end)

    it("preserves indentation when uncommenting", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "  -- local x = 1",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("  local x = 1", lines[1])
    end)

    it("handles mixed indentation levels", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local function test()",
        "  local x = 1",
        "    local y = 2",
        "end",
      })

      toggle.toggle_lines(bufnr, 2, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("  -- local x = 1", lines[2])
      assert.equals("    -- local y = 2", lines[3])
    end)
  end)

  describe("Lua-specific syntax", function()
    it("comments function declarations", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local function test()",
        "  return true",
        "end",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- local function test()", lines[1])
      assert.equals("--   return true", lines[2])
      assert.equals("-- end", lines[3])
    end)

    it("comments table literals", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local config = {",
        "  option = true,",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- local config = {", lines[1])
      assert.equals("--   option = true,", lines[2])
      assert.equals("-- }", lines[3])
    end)

    it("comments require statements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local module = require('module')",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- local module = require('module')", lines[1])
    end)

    it("comments metatables", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "setmetatable(t, {",
        "  __index = function(t, k)",
        "    return rawget(t, k)",
        "  end",
        "})",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- setmetatable(t, {", lines[1])
      assert.equals("--   __index = function(t, k)", lines[2])
    end)
  end)

  describe("edge cases", function()
    it("handles strings containing comment markers", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'local str = "-- not a comment"',
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('-- local str = "-- not a comment"', lines[1])
    end)

    it("handles empty lines", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- ", lines[1])
    end)

    it("handles lines with only whitespace", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "    " })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("    -- ", lines[1])
    end)

    it("handles double-dash in code", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local x = 5 -- 2",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- local x = 5 -- 2", lines[1])
    end)
  end)

  describe("Neovim API patterns", function()
    it("comments vim.api calls", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "vim.api.nvim_set_keymap('n', '<leader>x', ':lua test()<CR>', { noremap = true })",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^%-%- vim%.api", lines[1])
    end)

    it("comments autocommand definitions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "vim.api.nvim_create_autocmd('BufEnter', {",
        "  pattern = '*.lua',",
        "  callback = function() end",
        "})",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- vim.api.nvim_create_autocmd('BufEnter', {", lines[1])
      assert.equals("--   pattern = '*.lua',", lines[2])
    end)
  end)
end)
