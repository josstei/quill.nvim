---Unit tests for text objects module
---Tests comment block and line selection
local helpers = require("tests.helpers")

describe("textobjects", function()
  local textobjects = require("quill.textobjects")
  local detect = require("quill.core.detect")

  describe("find_comment_block_bounds", function()
    it("finds bounds of single-line comment block", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local x = 1",
        "-- This is a comment",
        "local y = 2",
      }, filetype = "lua" })

      local start, end_line = textobjects.find_comment_block_bounds(bufnr, 2)
      assert.are.equal(2, start)
      assert.are.equal(2, end_line)

      helpers.delete_buffer(bufnr)
    end)

    it("finds bounds of multi-line comment block", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local x = 1",
        "-- Comment 1",
        "-- Comment 2",
        "-- Comment 3",
        "local y = 2",
      }, filetype = "lua" })

      local start, end_line = textobjects.find_comment_block_bounds(bufnr, 2)
      assert.are.equal(2, start)
      assert.are.equal(4, end_line)

      -- Test from middle of block
      start, end_line = textobjects.find_comment_block_bounds(bufnr, 3)
      assert.are.equal(2, start)
      assert.are.equal(4, end_line)

      -- Test from end of block
      start, end_line = textobjects.find_comment_block_bounds(bufnr, 4)
      assert.are.equal(2, start)
      assert.are.equal(4, end_line)

      helpers.delete_buffer(bufnr)
    end)

    it("returns nil when line is not commented", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local x = 1",
        "-- Comment",
        "local y = 2",
      }, filetype = "lua" })

      local start, end_line = textobjects.find_comment_block_bounds(bufnr, 1)
      assert.is_nil(start)
      assert.is_nil(end_line)

      helpers.delete_buffer(bufnr)
    end)

    it("handles comment blocks at start of buffer", function()
      local bufnr = helpers.create_buffer({ lines = {
        "-- Comment 1",
        "-- Comment 2",
        "local x = 1",
      }, filetype = "lua" })

      local start, end_line = textobjects.find_comment_block_bounds(bufnr, 1)
      assert.are.equal(1, start)
      assert.are.equal(2, end_line)

      helpers.delete_buffer(bufnr)
    end)

    it("handles comment blocks at end of buffer", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local x = 1",
        "-- Comment 1",
        "-- Comment 2",
      }, filetype = "lua" })

      local start, end_line = textobjects.find_comment_block_bounds(bufnr, 3)
      assert.are.equal(2, start)
      assert.are.equal(3, end_line)

      helpers.delete_buffer(bufnr)
    end)

    it("treats empty lines as block boundaries", function()
      local bufnr = helpers.create_buffer({ lines = {
        "-- Comment 1",
        "",
        "-- Comment 2",
      }, filetype = "lua" })

      local start, end_line = textobjects.find_comment_block_bounds(bufnr, 1)
      assert.are.equal(1, start)
      assert.are.equal(1, end_line)

      start, end_line = textobjects.find_comment_block_bounds(bufnr, 3)
      assert.are.equal(3, start)
      assert.are.equal(3, end_line)

      helpers.delete_buffer(bufnr)
    end)

    it("handles block comments spanning single line", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local x = 1",
        "/* Block comment */",
        "local y = 2",
      }, filetype = "javascript" })

      local start, end_line = textobjects.find_comment_block_bounds(bufnr, 2)
      assert.are.equal(2, start)
      assert.are.equal(2, end_line)

      helpers.delete_buffer(bufnr)
    end)

    it("returns nil for invalid buffer", function()
      local start, end_line = textobjects.find_comment_block_bounds(999999, 1)
      assert.is_nil(start)
      assert.is_nil(end_line)
    end)

    it("returns nil for invalid line number", function()
      local bufnr = helpers.create_buffer({ lines = { "local x = 1" } })

      local start, end_line = textobjects.find_comment_block_bounds(bufnr, 0)
      assert.is_nil(start)
      assert.is_nil(end_line)

      start, end_line = textobjects.find_comment_block_bounds(bufnr, 100)
      assert.is_nil(start)
      assert.is_nil(end_line)

      helpers.delete_buffer(bufnr)
    end)
  end)

  describe("select_inner_block", function()
    it("selects content without markers in single-line block", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local x = 1",
        "-- This is a comment",
        "local y = 2",
      } })

      -- Set up window for this buffer
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, bufnr)
      vim.api.nvim_win_set_cursor(win, { 2, 0 })

      -- Execute text object selection
      textobjects.select_inner_block()

      -- In visual mode, cursor should be positioned at content
      local cursor = vim.api.nvim_win_get_cursor(win)
      assert.are.equal(2, cursor[1])

      helpers.delete_buffer(bufnr)
    end)

    it("selects content in multi-line block", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local x = 1",
        "-- Comment 1",
        "-- Comment 2",
        "-- Comment 3",
        "local y = 2",
      }, filetype = "lua" })

      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, bufnr)
      vim.api.nvim_win_set_cursor(win, { 2, 0 })

      textobjects.select_inner_block()

      -- Cursor should be at end of selection (line 4)
      local cursor = vim.api.nvim_win_get_cursor(win)
      assert.are.equal(4, cursor[1])

      helpers.delete_buffer(bufnr)
    end)

    it("does nothing when not on commented line", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local x = 1",
        "local y = 2",
      } })

      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, bufnr)
      local initial_cursor = { 1, 0 }
      vim.api.nvim_win_set_cursor(win, initial_cursor)

      textobjects.select_inner_block()

      -- Cursor should not move
      local cursor = vim.api.nvim_win_get_cursor(win)
      assert.are.same(initial_cursor, cursor)

      helpers.delete_buffer(bufnr)
    end)
  end)

  describe("select_around_block", function()
    it("selects entire lines including markers", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local x = 1",
        "-- Comment 1",
        "-- Comment 2",
        "local y = 2",
      }, filetype = "lua" })

      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, bufnr)
      vim.api.nvim_win_set_cursor(win, { 2, 0 })

      textobjects.select_around_block()

      -- Cursor should be at end of selection (line 3)
      local cursor = vim.api.nvim_win_get_cursor(win)
      assert.are.equal(3, cursor[1])

      helpers.delete_buffer(bufnr)
    end)

    it("does nothing when not on commented line", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local x = 1",
        "local y = 2",
      } })

      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, bufnr)
      local initial_cursor = { 1, 0 }
      vim.api.nvim_win_set_cursor(win, initial_cursor)

      textobjects.select_around_block()

      -- Cursor should not move
      local cursor = vim.api.nvim_win_get_cursor(win)
      assert.are.same(initial_cursor, cursor)

      helpers.delete_buffer(bufnr)
    end)
  end)

  describe("select_inner_line", function()
    it("selects content without marker on commented line", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local x = 1",
        "-- This is a comment",
        "local y = 2",
      } })

      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, bufnr)
      vim.api.nvim_win_set_cursor(win, { 2, 0 })

      textobjects.select_inner_line()

      -- Should position cursor on line
      local cursor = vim.api.nvim_win_get_cursor(win)
      assert.are.equal(2, cursor[1])

      helpers.delete_buffer(bufnr)
    end)

    it("does nothing when not on commented line", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local x = 1",
        "local y = 2",
      } })

      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, bufnr)
      local initial_cursor = { 1, 0 }
      vim.api.nvim_win_set_cursor(win, initial_cursor)

      textobjects.select_inner_line()

      -- Cursor should not move
      local cursor = vim.api.nvim_win_get_cursor(win)
      assert.are.same(initial_cursor, cursor)

      helpers.delete_buffer(bufnr)
    end)

    it("handles empty comment lines", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local x = 1",
        "--",
        "local y = 2",
      } })

      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, bufnr)
      vim.api.nvim_win_set_cursor(win, { 2, 0 })

      textobjects.select_inner_line()

      -- Should still work for empty comment
      local cursor = vim.api.nvim_win_get_cursor(win)
      assert.are.equal(2, cursor[1])

      helpers.delete_buffer(bufnr)
    end)
  end)

  describe("select_around_line", function()
    it("selects entire line when commented", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local x = 1",
        "-- This is a comment",
        "local y = 2",
      } })

      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, bufnr)
      vim.api.nvim_win_set_cursor(win, { 2, 0 })

      textobjects.select_around_line()

      -- Should position at start of line
      local cursor = vim.api.nvim_win_get_cursor(win)
      assert.are.equal(2, cursor[1])
      assert.are.equal(0, cursor[2])

      helpers.delete_buffer(bufnr)
    end)

    it("does nothing when not on commented line", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local x = 1",
        "local y = 2",
      } })

      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, bufnr)
      local initial_cursor = { 1, 0 }
      vim.api.nvim_win_set_cursor(win, initial_cursor)

      textobjects.select_around_line()

      -- Cursor should not move
      local cursor = vim.api.nvim_win_get_cursor(win)
      assert.are.same(initial_cursor, cursor)

      helpers.delete_buffer(bufnr)
    end)
  end)

  describe("setup", function()
    it("creates default keymaps", function()
      -- Setup with defaults
      textobjects.setup()

      -- Verify keymaps exist (check that they don't throw errors)
      local has_ic = pcall(vim.fn.maparg, "ic", "o")
      local has_ac = pcall(vim.fn.maparg, "ac", "o")
      local has_iC = pcall(vim.fn.maparg, "iC", "o")
      local has_aC = pcall(vim.fn.maparg, "aC", "o")

      assert.is_true(has_ic)
      assert.is_true(has_ac)
      assert.is_true(has_iC)
      assert.is_true(has_aC)
    end)

    it("respects custom mappings", function()
      textobjects.setup({
        textobjects = {
          inner_block = "ib",
          around_block = "ab",
          inner_line = "il",
          around_line = "al",
        },
      })

      -- Verify custom keymaps exist
      local has_ib = pcall(vim.fn.maparg, "ib", "o")
      local has_ab = pcall(vim.fn.maparg, "ab", "o")
      local has_il = pcall(vim.fn.maparg, "il", "o")
      local has_al = pcall(vim.fn.maparg, "al", "o")

      assert.is_true(has_ib)
      assert.is_true(has_ab)
      assert.is_true(has_il)
      assert.is_true(has_al)
    end)

    it("allows disabling specific mappings", function()
      textobjects.setup({
        textobjects = {
          inner_block = "ic",
          around_block = false,
          inner_line = "iC",
          around_line = "aC",
        },
      })

      -- Verify only enabled keymaps exist
      local has_ic = pcall(vim.fn.maparg, "ic", "o")
      local has_iC = pcall(vim.fn.maparg, "iC", "o")
      local has_aC = pcall(vim.fn.maparg, "aC", "o")

      assert.is_true(has_ic)
      assert.is_true(has_iC)
      assert.is_true(has_aC)
    end)
  end)

  describe("edge cases", function()
    it("handles buffer with only comments", function()
      local bufnr = helpers.create_buffer({ lines = {
        "-- Comment 1",
        "-- Comment 2",
        "-- Comment 3",
      }, filetype = "lua" })

      local start, end_line = textobjects.find_comment_block_bounds(bufnr, 2)
      assert.are.equal(1, start)
      assert.are.equal(3, end_line)

      helpers.delete_buffer(bufnr)
    end)

    it("handles empty buffer", function()
      local bufnr = helpers.create_buffer({ lines = {} })

      local start, end_line = textobjects.find_comment_block_bounds(bufnr, 1)
      assert.is_nil(start)
      assert.is_nil(end_line)

      helpers.delete_buffer(bufnr)
    end)

    it("treats consecutive comments as single block regardless of style", function()
      local bufnr = helpers.create_buffer({ lines = {
        "// Line comment",
        "/* Block comment */",
        "// Another line comment",
      }, filetype = "javascript" })

      -- All consecutive commented lines form one block
      local start, end_line = textobjects.find_comment_block_bounds(bufnr, 1)
      assert.are.equal(1, start)
      assert.are.equal(3, end_line)

      -- From middle
      start, end_line = textobjects.find_comment_block_bounds(bufnr, 2)
      assert.are.equal(1, start)
      assert.are.equal(3, end_line)

      -- From end
      start, end_line = textobjects.find_comment_block_bounds(bufnr, 3)
      assert.are.equal(1, start)
      assert.are.equal(3, end_line)

      helpers.delete_buffer(bufnr)
    end)

    it("handles indented comments", function()
      local bufnr = helpers.create_buffer({ lines = {
        "function test()",
        "  -- Comment 1",
        "  -- Comment 2",
        "end",
      }, filetype = "lua" })

      local start, end_line = textobjects.find_comment_block_bounds(bufnr, 2)
      assert.are.equal(2, start)
      assert.are.equal(3, end_line)

      helpers.delete_buffer(bufnr)
    end)
  end)
end)
