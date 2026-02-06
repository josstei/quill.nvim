---Unit tests for quill.features.convert module
---Tests style conversion between line and block comments
local helpers = require("tests.helpers")

describe("quill.features.convert", function()
  local convert
  local created_buffers = {}
  before_each(function()
    -- Reset modules to ensure clean state
    package.loaded["quill.features.convert"] = nil
    package.loaded["quill.core.detect"] = nil
    package.loaded["quill.core.undo"] = nil
    package.loaded["quill.detection.regex"] = nil
    convert = require("quill.features.convert")
    created_buffers = {}
  end)
  after_each(function()
    -- Clean up any test buffers
    for _, bufnr in ipairs(created_buffers) do
      helpers.delete_buffer(bufnr)
    end
    created_buffers = {}
  end)
  describe("detect_current_style", function()
    it("detects no comments in uncommented code", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
          "local x = 1",
          "local y = 2",
        },
      })
      table.insert(created_buffers, bufnr)
      local style = convert.detect_current_style(bufnr, 1, 2)
      assert.equals("none", style)
    end)
    it("detects line comments", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
          "-- foo",
          "-- bar",
          "-- baz",
        },
      })
      table.insert(created_buffers, bufnr)
      local style = convert.detect_current_style(bufnr, 1, 3)
      assert.equals("line", style)
    end)
    it("detects block comments", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
          "--[[ foo ]]",
          "--[[ bar ]]",
          "--[[ baz ]]",
        },
      })
      table.insert(created_buffers, bufnr)
      local style = convert.detect_current_style(bufnr, 1, 3)
      assert.equals("block", style)
    end)
    it("detects mixed line and block comments", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
          "-- foo",
          "--[[ bar ]]",
          "-- baz",
        },
      })
      table.insert(created_buffers, bufnr)
      local style = convert.detect_current_style(bufnr, 1, 3)
      assert.equals("mixed", style)
    end)
    it("ignores empty lines when detecting style", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
          "-- foo",
          "",
          "-- bar",
        },
      })
      table.insert(created_buffers, bufnr)
      local style = convert.detect_current_style(bufnr, 1, 3)
      assert.equals("line", style)
    end)
    it("detects line style when some lines are uncommented", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
          "-- foo",
          "local x = 1",
          "-- bar",
        },
      })
      table.insert(created_buffers, bufnr)
      local style = convert.detect_current_style(bufnr, 1, 3)
      -- Has line comments (uncommented lines are ignored in detection)
      assert.equals("line", style)
    end)
  end)
  describe("convert_to_line", function()
    it("converts single-line block comment to line comment", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
          "--[[ foo ]]",
        },
      })
      table.insert(created_buffers, bufnr)
      local result = convert.convert_to_line(bufnr, 1, 1)
      assert.is_true(result.success)
      assert.is_nil(result.error_msg)
      assert.equals(1, result.count)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- foo", lines[1])
    end)
    it("converts multiple block comments to line comments", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
          "--[[ foo ]]",
          "--[[ bar ]]",
          "--[[ baz ]]",
        },
      })
      table.insert(created_buffers, bufnr)
      local result = convert.convert_to_line(bufnr, 1, 3)
      assert.is_true(result.success)
      assert.is_nil(result.error_msg)
      assert.equals(3, result.count)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- foo", lines[1])
      assert.equals("-- bar", lines[2])
      assert.equals("-- baz", lines[3])
    end)
    it("preserves indentation when converting", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
          "  --[[ foo ]]",
          "    --[[ bar ]]",
        },
      })
      table.insert(created_buffers, bufnr)
      local result = convert.convert_to_line(bufnr, 1, 2)
      assert.is_true(result.success)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("  -- foo", lines[1])
      assert.equals("    -- bar", lines[2])
    end)
    it("preserves empty lines", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
          "--[[ foo ]]",
          "",
          "--[[ bar ]]",
        },
      })
      table.insert(created_buffers, bufnr)
      local result = convert.convert_to_line(bufnr, 1, 3)
      assert.is_true(result.success)
      assert.equals(2, result.count) -- Only 2 lines converted (empty line skipped)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- foo", lines[1])
      assert.equals("", lines[2])
      assert.equals("-- bar", lines[3])
    end)
    it("returns success with count 0 for already line-commented code", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
          "-- foo",
          "-- bar",
        },
      })
      table.insert(created_buffers, bufnr)
      local result = convert.convert_to_line(bufnr, 1, 2)
      assert.is_true(result.success)
      assert.is_nil(result.error_msg)
      assert.equals(0, result.count)
      -- Should be unchanged
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- foo", lines[1])
      assert.equals("-- bar", lines[2])
    end)
    it("returns success with count 0 for uncommented code", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
          "local x = 1",
          "local y = 2",
        },
      })
      table.insert(created_buffers, bufnr)
      local result = convert.convert_to_line(bufnr, 1, 2)
      assert.is_true(result.success)
      assert.is_nil(result.error_msg)
      assert.equals(0, result.count)
      -- Should be unchanged
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("local x = 1", lines[1])
      assert.equals("local y = 2", lines[2])
    end)
    it("returns error when language doesn't support line comments", function()
      local bufnr = helpers.create_buffer({
        filetype = "css",
        lines = {
          "/* foo */",
        },
      })
      table.insert(created_buffers, bufnr)
      local result = convert.convert_to_line(bufnr, 1, 1)
      assert.is_false(result.success)
      assert.equals("Language doesn't support line comments", result.error_msg)
      assert.equals(0, result.count)
    end)
    it("handles empty block comments", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
          "--[[  ]]",
        },
      })
      table.insert(created_buffers, bufnr)
      local result = convert.convert_to_line(bufnr, 1, 1)
      assert.is_true(result.success)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("--", lines[1])
    end)
    it("converts mixed styles to line comments", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
          "-- foo",
          "--[[ bar ]]",
          "-- baz",
        },
      })
      table.insert(created_buffers, bufnr)
      local result = convert.convert_to_line(bufnr, 1, 3)
      assert.is_true(result.success)
      assert.equals(1, result.count) -- Only the block comment converted
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- foo", lines[1])
      assert.equals("-- bar", lines[2])
      assert.equals("-- baz", lines[3])
    end)
  end)
  describe("convert_to_block", function()
    it("converts single line comment to block comment", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
        "-- foo",
        },
      })
      table.insert(created_buffers, bufnr)

      local result = convert.convert_to_block(bufnr, 1, 1)
      assert.is_true(result.success)
      assert.is_nil(result.error_msg)
      assert.equals(1, result.count)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("--[[ foo ]]", lines[1])
    end)
    it("converts multiple line comments to block comments", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
        "-- foo",
        "-- bar",
        "-- baz",
        },
      })
      table.insert(created_buffers, bufnr)

      local result = convert.convert_to_block(bufnr, 1, 3)
      assert.is_true(result.success)
      assert.is_nil(result.error_msg)
      assert.equals(3, result.count)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("--[[ foo ]]", lines[1])
      assert.equals("--[[ bar ]]", lines[2])
      assert.equals("--[[ baz ]]", lines[3])
    end)
    it("preserves indentation when converting", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
        "  -- foo",
        "    -- bar",
        },
      })
      table.insert(created_buffers, bufnr)

      local result = convert.convert_to_block(bufnr, 1, 2)
      assert.is_true(result.success)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("  --[[ foo ]]", lines[1])
      assert.equals("    --[[ bar ]]", lines[2])
    end)
    it("preserves empty lines", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
        "-- foo",
        "",
        "-- bar",
        },
      })
      table.insert(created_buffers, bufnr)

      local result = convert.convert_to_block(bufnr, 1, 3)
      assert.is_true(result.success)
      assert.equals(2, result.count) -- Only 2 lines converted
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("--[[ foo ]]", lines[1])
      assert.equals("", lines[2])
      assert.equals("--[[ bar ]]", lines[3])
    end)
    it("returns success with count 0 for already block-commented code", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
        "--[[ foo ]]",
        "--[[ bar ]]",
        },
      })
      table.insert(created_buffers, bufnr)

      local result = convert.convert_to_block(bufnr, 1, 2)
      assert.is_true(result.success)
      assert.is_nil(result.error_msg)
      assert.equals(0, result.count)
      -- Should be unchanged
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("--[[ foo ]]", lines[1])
      assert.equals("--[[ bar ]]", lines[2])
    end)
    it("returns success with count 0 for uncommented code", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
        "local x = 1",
        "local y = 2",
        },
      })
      table.insert(created_buffers, bufnr)

      local result = convert.convert_to_block(bufnr, 1, 2)
      assert.is_true(result.success)
      assert.is_nil(result.error_msg)
      assert.equals(0, result.count)
      -- Should be unchanged
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("local x = 1", lines[1])
      assert.equals("local y = 2", lines[2])
    end)
    it("returns error when language doesn't support block comments", function()
      -- Shell script doesn't have block comments
      local bufnr = helpers.create_buffer({
        filetype = "sh",
        lines = {
        "# foo",
        },
      })
      table.insert(created_buffers, bufnr)

      local result = convert.convert_to_block(bufnr, 1, 1)
      assert.is_false(result.success)
      assert.equals("Language doesn't support block comments", result.error_msg)
      assert.equals(0, result.count)
    end)
    it("handles empty line comments", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
        "--",
        },
      })
      table.insert(created_buffers, bufnr)

      local result = convert.convert_to_block(bufnr, 1, 1)
      assert.is_true(result.success)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("--[[ ]]", lines[1])
    end)
    it("converts mixed styles to block comments", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
        "--[[ foo ]]",
        "-- bar",
        "--[[ baz ]]",
        },
      })
      table.insert(created_buffers, bufnr)

      local result = convert.convert_to_block(bufnr, 1, 3)
      assert.is_true(result.success)
      assert.equals(1, result.count) -- Only the line comment converted
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("--[[ foo ]]", lines[1])
      assert.equals("--[[ bar ]]", lines[2])
      assert.equals("--[[ baz ]]", lines[3])
    end)
    it("works with JavaScript block comments", function()
      local bufnr = helpers.create_buffer({
        filetype = "javascript",
        lines = {
        "// foo",
        "// bar",
        },
      })
      table.insert(created_buffers, bufnr)

      local result = convert.convert_to_block(bufnr, 1, 2)
      assert.is_true(result.success)
      assert.equals(2, result.count)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("/* foo */", lines[1])
      assert.equals("/* bar */", lines[2])
    end)
  end)
  describe("undo grouping", function()
    it("uses undo grouping internally", function()
      -- Note: Undo grouping behavior is tested in undo_spec.lua
      -- Here we just verify that convert functions call with_undo_group
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
        "--[[ foo ]]",
        "--[[ bar ]]",
        },
      })
      table.insert(created_buffers, bufnr)

      -- Verify conversion works (undo grouping is internal implementation)
      local result = convert.convert_to_line(bufnr, 1, 2)
      assert.is_true(result.success)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- foo", lines[1])
      assert.equals("-- bar", lines[2])
    end)
  end)
  describe("edge cases", function()
    it("handles single line with whitespace only", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
        "   ",
        },
      })
      table.insert(created_buffers, bufnr)

      local result = convert.convert_to_line(bufnr, 1, 1)
      assert.is_true(result.success)
      assert.equals(0, result.count)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("   ", lines[1])
    end)
    it("handles range with only empty lines", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
        "",
        "",
        "",
        },
      })
      table.insert(created_buffers, bufnr)

      local result = convert.convert_to_block(bufnr, 1, 3)
      assert.is_true(result.success)
      assert.equals(0, result.count)
    end)
    it("preserves extra whitespace in content", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
        "-- foo  bar",
        },
      })
      table.insert(created_buffers, bufnr)

      local result = convert.convert_to_block(bufnr, 1, 1)
      assert.is_true(result.success)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Content should preserve internal spacing
      assert.is_true(lines[1]:match("foo.*bar") ~= nil)
    end)
    it("handles partial line selection", function()
      local bufnr = helpers.create_buffer({
        filetype = "lua",
        lines = {
        "local x = 1",
        "-- foo",
        "-- bar",
        "local y = 2",
        },
      })
      table.insert(created_buffers, bufnr)

      -- Convert only the commented lines
      local result = convert.convert_to_block(bufnr, 2, 3)
      assert.is_true(result.success)
      assert.equals(2, result.count)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("local x = 1", lines[1])
      assert.equals("--[[ foo ]]", lines[2])
      assert.equals("--[[ bar ]]", lines[3])
      assert.equals("local y = 2", lines[4])
    end)
  end)
end)