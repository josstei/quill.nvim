local toggle = require("quill.core.toggle")
local detect = require("quill.core.detect")
local helpers = require("tests.helpers")

describe("core.toggle", function()
  -- Test fixtures
  local lua_style = {
    line = "--",
    block = { "--[[", "]]" },
    supports_nesting = false,
    jsx = false,
  }

  local js_style = {
    line = "//",
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  }

  local css_style = {
    line = nil,
    block = { "/*", "*/" },
    supports_nesting = false,
    jsx = false,
  }

  -- Mock detect.get_comment_style for controlled testing
  local original_get_comment_style = detect.get_comment_style
  local original_get_filetype_style = detect.get_filetype_style
  local original_is_commented = detect.is_commented

  before_each(function()
    -- Reset mocks
    detect.get_comment_style = original_get_comment_style
    detect.get_filetype_style = original_get_filetype_style
    detect.is_commented = original_is_commented
  end)

  describe("analyze_lines", function()
    it("should return 'none_commented' for uncommented lines", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local foo = 'bar'",
        "local baz = 'qux'",
      }, filetype = "lua" })

      -- Mock is_commented to return false
      detect.is_commented = function()
        return false
      end

      local state, err = toggle.analyze_lines(bufnr, 1, 2)
      assert.are.equal("none_commented", state)
      assert.is_nil(err)

      helpers.delete_buffer(bufnr)
    end)

    it("should return 'all_commented' for all commented lines", function()
      local bufnr = helpers.create_buffer({ lines = {
        "-- local foo = 'bar'",
        "-- local baz = 'qux'",
      }, filetype = "lua" })

      -- Mock is_commented to return true
      detect.is_commented = function()
        return true
      end

      local state, err = toggle.analyze_lines(bufnr, 1, 2)
      assert.are.equal("all_commented", state)
      assert.is_nil(err)

      helpers.delete_buffer(bufnr)
    end)

    it("should return 'mixed' for partially commented lines", function()
      local bufnr = helpers.create_buffer({ lines = {
        "-- local foo = 'bar'",
        "local baz = 'qux'",
      }, filetype = "lua" })

      -- Mock is_commented to alternate
      local call_count = 0
      detect.is_commented = function()
        call_count = call_count + 1
        return call_count == 1
      end

      local state, err = toggle.analyze_lines(bufnr, 1, 2)
      assert.are.equal("mixed", state)
      assert.is_nil(err)

      helpers.delete_buffer(bufnr)
    end)

    it("should skip empty lines in analysis", function()
      local bufnr = helpers.create_buffer({ lines = {
        "-- local foo = 'bar'",
        "",
        "-- local baz = 'qux'",
      }, filetype = "lua" })

      -- Mock is_commented to return true (only called for non-empty lines)
      detect.is_commented = function()
        return true
      end

      local state, err = toggle.analyze_lines(bufnr, 1, 3)
      assert.are.equal("all_commented", state)
      assert.is_nil(err)

      helpers.delete_buffer(bufnr)
    end)

    it("should skip whitespace-only lines in analysis", function()
      local bufnr = helpers.create_buffer({ lines = {
        "-- local foo = 'bar'",
        "    ",
        "-- local baz = 'qux'",
      }, filetype = "lua" })

      -- Mock is_commented to return true (only called for non-empty lines)
      detect.is_commented = function()
        return true
      end

      local state, err = toggle.analyze_lines(bufnr, 1, 3)
      assert.are.equal("all_commented", state)
      assert.is_nil(err)

      helpers.delete_buffer(bufnr)
    end)

    it("should return 'none_commented' for all empty lines", function()
      local bufnr = helpers.create_buffer({ lines = {
        "",
        "   ",
        "",
      }, filetype = "lua" })

      local state, err = toggle.analyze_lines(bufnr, 1, 3)
      assert.are.equal("none_commented", state)
      assert.is_nil(err)

      helpers.delete_buffer(bufnr)
    end)

    it("should return error on invalid buffer", function()
      local state, err = toggle.analyze_lines(999999, 1, 1)
      assert.is_nil(state)
      assert.are.equal("Invalid buffer", err)
    end)

    it("should return error on invalid line range", function()
      local bufnr = helpers.create_buffer({ lines = { "test" }, filetype = "lua" })

      local state, err = toggle.analyze_lines(bufnr, 0, 1)
      assert.is_nil(state)
      assert.are.equal("Invalid line range", err)

      state, err = toggle.analyze_lines(bufnr, 2, 1)
      assert.is_nil(state)
      assert.are.equal("Invalid line range", err)

      helpers.delete_buffer(bufnr)
    end)

    it("should detect block-wrapped content as all_commented", function()
      local bufnr = helpers.create_buffer({ lines = {
        "--[[",
        "local foo = 'bar'",
        "local baz = 'qux'",
        "]]",
      }, filetype = "lua" })

      detect.is_commented = function()
        return false
      end

      local state, err = toggle.analyze_lines(bufnr, 1, 4)
      assert.are.equal("all_commented", state)
      assert.is_nil(err)

      helpers.delete_buffer(bufnr)
    end)

    it("should detect JavaScript block-wrapped content", function()
      local bufnr = helpers.create_buffer({ lines = {
        "/*",
        "const x = 1;",
        "const y = 2;",
        "*/",
      }, filetype = "javascript" })

      detect.is_commented = function()
        return false
      end

      local state, err = toggle.analyze_lines(bufnr, 1, 4)
      assert.are.equal("all_commented", state)
      assert.is_nil(err)

      helpers.delete_buffer(bufnr)
    end)
  end)

  describe("toggle_lines", function()
    it("should comment uncommented lines", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local foo = 'bar'",
        "local baz = 'qux'",
      }, filetype = "lua" })

      -- Mock detect functions
      detect.get_comment_style = function()
        return lua_style
      end
      detect.is_commented = function()
        return false
      end

      local success, err = toggle.toggle_lines(bufnr, 1, 2)
      assert.is_true(success)
      assert.is_nil(err)

      local lines = helpers.get_buffer_lines(bufnr, 1, 2)
      assert.are.equal("-- local foo = 'bar'", lines[1])
      assert.are.equal("-- local baz = 'qux'", lines[2])

      helpers.delete_buffer(bufnr)
    end)

    it("should uncomment commented lines", function()
      local bufnr = helpers.create_buffer({ lines = {
        "-- local foo = 'bar'",
        "-- local baz = 'qux'",
      }, filetype = "lua" })

      -- Mock detect functions
      detect.get_comment_style = function()
        return lua_style
      end
      detect.is_commented = function()
        return true
      end

      local success, err = toggle.toggle_lines(bufnr, 1, 2)
      assert.is_true(success)
      assert.is_nil(err)

      local lines = helpers.get_buffer_lines(bufnr, 1, 2)
      assert.are.equal("local foo = 'bar'", lines[1])
      assert.are.equal("local baz = 'qux'", lines[2])

      helpers.delete_buffer(bufnr)
    end)

    it("should comment mixed state (partial comments)", function()
      local bufnr = helpers.create_buffer({ lines = {
        "-- local foo = 'bar'",
        "local baz = 'qux'",
      }, filetype = "lua" })

      -- Mock detect functions
      detect.get_comment_style = function()
        return lua_style
      end
      local call_count = 0
      detect.is_commented = function()
        call_count = call_count + 1
        return call_count == 1
      end

      local success, err = toggle.toggle_lines(bufnr, 1, 2)
      assert.is_true(success)
      assert.is_nil(err)

      local lines = helpers.get_buffer_lines(bufnr, 1, 2)
      -- Mixed state should result in commenting all
      assert.are.equal("-- -- local foo = 'bar'", lines[1])
      assert.are.equal("-- local baz = 'qux'", lines[2])

      helpers.delete_buffer(bufnr)
    end)

    it("should respect force_comment option", function()
      local bufnr = helpers.create_buffer({ lines = {
        "-- local foo = 'bar'",
      }, filetype = "lua" })

      -- Mock detect functions
      detect.get_comment_style = function()
        return lua_style
      end
      detect.is_commented = function()
        return true
      end

      local success, err = toggle.toggle_lines(bufnr, 1, 1, { force_comment = true })
      assert.is_true(success)
      assert.is_nil(err)

      local lines = helpers.get_buffer_lines(bufnr, 1, 1)
      -- Should comment even though already commented
      assert.are.equal("-- -- local foo = 'bar'", lines[1])

      helpers.delete_buffer(bufnr)
    end)

    it("should respect force_uncomment option", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local foo = 'bar'",
      }, filetype = "lua" })

      -- Mock detect functions
      detect.get_comment_style = function()
        return lua_style
      end
      detect.is_commented = function()
        return false
      end

      local success, err = toggle.toggle_lines(bufnr, 1, 1, { force_uncomment = true })
      assert.is_true(success)
      assert.is_nil(err)

      local lines = helpers.get_buffer_lines(bufnr, 1, 1)
      -- Should try to uncomment even though not commented (no-op)
      assert.are.equal("local foo = 'bar'", lines[1])

      helpers.delete_buffer(bufnr)
    end)

    it("should error on conflicting force options", function()
      local bufnr = helpers.create_buffer({ lines = { "test" }, filetype = "lua" })

      local success, err = toggle.toggle_lines(bufnr, 1, 1, {
        force_comment = true,
        force_uncomment = true,
      })

      assert.is_false(success)
      assert.are.equal("Cannot force both comment and uncomment", err)

      helpers.delete_buffer(bufnr)
    end)

    it("should error on invalid style_type", function()
      local bufnr = helpers.create_buffer({ lines = { "test" }, filetype = "lua" })

      local success, err = toggle.toggle_lines(bufnr, 1, 1, {
        style_type = "invalid",
      })

      assert.is_false(success)
      assert.are.equal("Invalid style_type: must be 'line' or 'block'", err)

      helpers.delete_buffer(bufnr)
    end)

    it("should respect style_type option", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local foo = 'bar'",
      }, filetype = "lua" })

      -- Mock detect functions
      detect.get_comment_style = function()
        return lua_style
      end
      detect.is_commented = function()
        return false
      end

      local success, err = toggle.toggle_lines(bufnr, 1, 1, { style_type = "block" })
      assert.is_true(success)
      assert.is_nil(err)

      local lines = helpers.get_buffer_lines(bufnr, 1, 1)
      -- Should use block comment style
      assert.are.equal("--[[ local foo = 'bar' ]]", lines[1])

      helpers.delete_buffer(bufnr)
    end)

    it("should error on invalid buffer", function()
      local success, err = toggle.toggle_lines(999999, 1, 1)
      assert.is_false(success)
      assert.are.equal("Invalid buffer", err)
    end)

    it("should error on invalid line range", function()
      local bufnr = helpers.create_buffer({ lines = { "test" }, filetype = "lua" })

      local success, err = toggle.toggle_lines(bufnr, 0, 1)
      assert.is_false(success)
      assert.are.equal("Invalid line range", err)

      success, err = toggle.toggle_lines(bufnr, 2, 1)
      assert.is_false(success)
      assert.are.equal("Invalid line range", err)

      helpers.delete_buffer(bufnr)
    end)

    it("should error when no comment style available", function()
      local bufnr = helpers.create_buffer({ lines = { "test" }, filetype = "unknown" })

      -- Mock detect to return nil
      detect.get_comment_style = function()
        return nil
      end
      detect.get_filetype_style = function()
        return nil
      end

      local success, err = toggle.toggle_lines(bufnr, 1, 1)
      assert.is_false(success)
      assert.are.equal("No comment style available for this buffer", err)

      helpers.delete_buffer(bufnr)
    end)

    it("should fall back to filetype style if no non-empty lines", function()
      local bufnr = helpers.create_buffer({ lines = {
        "",
        "   ",
      }, filetype = "lua" })

      -- Mock detect functions
      detect.get_comment_style = function()
        return nil
      end
      detect.get_filetype_style = function()
        return lua_style
      end
      detect.is_commented = function()
        return false
      end

      local success, err = toggle.toggle_lines(bufnr, 1, 2)
      assert.is_true(success)
      assert.is_nil(err)

      helpers.delete_buffer(bufnr)
    end)
  end)

  describe("toggle_line", function()
    it("should toggle a single line", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local foo = 'bar'",
      }, filetype = "lua" })

      -- Mock detect functions
      detect.get_comment_style = function()
        return lua_style
      end
      detect.is_commented = function()
        return false
      end

      local success, err = toggle.toggle_line(bufnr, 1)
      assert.is_true(success)
      assert.is_nil(err)

      local lines = helpers.get_buffer_lines(bufnr, 1, 1)
      assert.are.equal("-- local foo = 'bar'", lines[1])

      helpers.delete_buffer(bufnr)
    end)

    it("should accept options", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local foo = 'bar'",
      }, filetype = "lua" })

      -- Mock detect functions
      detect.get_comment_style = function()
        return lua_style
      end
      detect.is_commented = function()
        return false
      end

      local success, err = toggle.toggle_line(bufnr, 1, { style_type = "block" })
      assert.is_true(success)
      assert.is_nil(err)

      local lines = helpers.get_buffer_lines(bufnr, 1, 1)
      assert.are.equal("--[[ local foo = 'bar' ]]", lines[1])

      helpers.delete_buffer(bufnr)
    end)
  end)

  describe("toggle_visual", function()
    it("should toggle a visual selection", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local foo = 'bar'",
        "local baz = 'qux'",
      }, filetype = "lua" })

      -- Mock detect functions
      detect.get_comment_style = function()
        return lua_style
      end
      detect.is_commented = function()
        return false
      end

      local success, err = toggle.toggle_visual(bufnr, 1, 2)
      assert.is_true(success)
      assert.is_nil(err)

      local lines = helpers.get_buffer_lines(bufnr, 1, 2)
      assert.are.equal("-- local foo = 'bar'", lines[1])
      assert.are.equal("-- local baz = 'qux'", lines[2])

      helpers.delete_buffer(bufnr)
    end)

    it("should accept options", function()
      local bufnr = helpers.create_buffer({ lines = {
        "function test()",
        "  print('hello')",
        "end",
      }, filetype = "lua" })

      -- Mock detect functions
      detect.get_comment_style = function()
        return lua_style
      end
      detect.is_commented = function()
        return false
      end

      local success, err = toggle.toggle_visual(bufnr, 1, 3, { style_type = "block" })
      assert.is_true(success)
      assert.is_nil(err)

      -- Should wrap in block comment
      local lines = helpers.get_buffer_lines(bufnr, 1, 5)
      assert.are.equal("--[[", lines[1])
      assert.are.equal("function test()", lines[2])

      helpers.delete_buffer(bufnr)
    end)
  end)

  describe("undo grouping", function()
    it("should group all changes in single undo", function()
      local bufnr = helpers.create_buffer({ lines = {
        "local foo = 'bar'",
        "local baz = 'qux'",
      }, filetype = "lua" })

      -- Enable undo for the buffer
      vim.api.nvim_buf_set_option(bufnr, "undolevels", 1000)

      -- Make an initial change to establish undo history
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local foo = 'bar'",
        "local baz = 'qux'",
      })

      -- Mock detect functions
      detect.get_comment_style = function()
        return lua_style
      end
      detect.is_commented = function()
        return false
      end

      -- Toggle to comment
      toggle.toggle_lines(bufnr, 1, 2)

      -- Verify commented
      local lines = helpers.get_buffer_lines(bufnr, 1, 2)
      assert.are.equal("-- local foo = 'bar'", lines[1])
      assert.are.equal("-- local baz = 'qux'", lines[2])

      -- Undo once
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("silent! undo")
      end)

      -- Should revert all changes with single undo
      lines = helpers.get_buffer_lines(bufnr, 1, 2)
      assert.are.equal("local foo = 'bar'", lines[1])
      assert.are.equal("local baz = 'qux'", lines[2])

      helpers.delete_buffer(bufnr)
    end)
  end)
end)
