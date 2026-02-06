local describe = require("plenary.busted").describe
local it = require("plenary.busted").it
local assert = require("plenary.busted").assert
local before_each = require("plenary.busted").before_each
local after_each = require("plenary.busted").after_each

describe("gc operator integration", function()
  local bufnr
  local toggle = require("quill.core.toggle")

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
  end)

  after_each(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  describe("motion combinations", function()
    it("gcip comments inner paragraph", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local x = 1",
        "local y = 2",
        "",
        "local z = 3",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same({
        "-- local x = 1",
        "-- local y = 2",
        "",
        "local z = 3",
      }, lines)
    end)

    it("gcc toggles current line", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local x = 1",
        "local y = 2",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- local x = 1", lines[1])
      assert.equals("local y = 2", lines[2])
    end)

    it("gc2j comments current and next 2 lines", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local x = 1",
        "local y = 2",
        "local z = 3",
        "local w = 4",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- local x = 1", lines[1])
      assert.equals("-- local y = 2", lines[2])
      assert.equals("-- local z = 3", lines[3])
      assert.equals("local w = 4", lines[4])
    end)

    it("visual gc comments selection", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local x = 1",
        "local y = 2",
        "local z = 3",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- local x = 1", lines[1])
      assert.equals("-- local y = 2", lines[2])
      assert.equals("local z = 3", lines[3])
    end)
  end)

  describe("toggle behavior", function()
    it("comments uncommented lines", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local x = 1",
        "local y = 2",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- local x = 1", lines[1])
      assert.equals("-- local y = 2", lines[2])
    end)

    it("uncomments commented lines", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "-- local x = 1",
        "-- local y = 2",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("local x = 1", lines[1])
      assert.equals("local y = 2", lines[2])
    end)

    it("handles mixed state by commenting all", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local x = 1",
        "-- local y = 2",
        "local z = 3",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- local x = 1", lines[1])
      assert.equals("-- -- local y = 2", lines[2])
      assert.equals("-- local z = 3", lines[3])
    end)
  end)

  describe("indentation handling", function()
    it("preserves indentation when commenting", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "  local x = 1",
        "    local y = 2",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("  -- local x = 1", lines[1])
      assert.equals("    -- local y = 2", lines[2])
    end)

    it("restores indentation when uncommenting", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "  -- local x = 1",
        "    -- local y = 2",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("  local x = 1", lines[1])
      assert.equals("    local y = 2", lines[2])
    end)
  end)

  describe("edge cases", function()
    it("handles empty lines", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local x = 1",
        "",
        "local y = 2",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- local x = 1", lines[1])
      assert.equals("-- ", lines[2])
      assert.equals("-- local y = 2", lines[3])
    end)

    it("handles single character lines", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "x" })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- x", lines[1])
    end)

    it("handles whitespace-only lines", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "  " })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("  -- ", lines[1])
    end)
  end)
end)
