---@diagnostic disable: undefined-field
local align = require("quill.features.align")

describe("quill.features.align", function()
  describe("find_trailing_comment", function()
    it("finds trailing comment with line style", function()
      local style = { line = "--" }
      local result = align.find_trailing_comment('local x = 1 -- comment', style)

      assert.is_not_nil(result)
      assert.equals("local x = 1", result.code)
      assert.equals("comment", result.comment)
      assert.equals("--", result.marker)
    end)

    it("returns nil for full-line comment", function()
      local style = { line = "--" }
      local result = align.find_trailing_comment('  -- this is a comment', style)

      assert.is_nil(result)
    end)

    it("returns nil for line without comment", function()
      local style = { line = "--" }
      local result = align.find_trailing_comment('local x = 1', style)

      assert.is_nil(result)
    end)

    it("ignores comment marker inside double-quoted strings", function()
      local style = { line = "--" }
      local result = align.find_trailing_comment('local x = "hello -- world" -- actual comment', style)

      assert.is_not_nil(result)
      assert.equals('local x = "hello -- world"', result.code)
      assert.equals("actual comment", result.comment)
    end)

    it("ignores comment marker inside single-quoted strings", function()
      local style = { line = "--" }
      local result = align.find_trailing_comment("local x = 'hello -- world' -- actual comment", style)

      assert.is_not_nil(result)
      assert.equals("local x = 'hello -- world'", result.code)
      assert.equals("actual comment", result.comment)
    end)

    it("ignores comment marker inside backtick strings", function()
      local style = { line = "--" }
      local result = align.find_trailing_comment("local x = `hello -- world` -- actual comment", style)

      assert.is_not_nil(result)
      assert.equals("local x = `hello -- world`", result.code)
      assert.equals("actual comment", result.comment)
    end)

    it("handles escaped quotes in strings", function()
      local style = { line = "--" }
      local result = align.find_trailing_comment('local x = "hello \\" world" -- comment', style)

      assert.is_not_nil(result)
      assert.equals('local x = "hello \\" world"', result.code)
      assert.equals("comment", result.comment)
    end)

    it("handles multiple strings on same line", function()
      local style = { line = "--" }
      local result = align.find_trailing_comment('local x = "a" .. "b" -- comment', style)

      assert.is_not_nil(result)
      assert.equals('local x = "a" .. "b"', result.code)
      assert.equals("comment", result.comment)
    end)

    it("trims whitespace from code and comment", function()
      local style = { line = "--" }
      local result = align.find_trailing_comment('local x = 1     --   comment  ', style)

      assert.is_not_nil(result)
      assert.equals("local x = 1", result.code)
      assert.equals("comment  ", result.comment) -- Trailing whitespace preserved in comment
    end)

    it("handles empty comment content", function()
      local style = { line = "--" }
      local result = align.find_trailing_comment('local x = 1 --', style)

      assert.is_not_nil(result)
      assert.equals("local x = 1", result.code)
      assert.equals("", result.comment)
    end)

    it("handles different comment markers", function()
      local style = { line = "//" }
      local result = align.find_trailing_comment('int x = 1; // comment', style)

      assert.is_not_nil(result)
      assert.equals("int x = 1;", result.code)
      assert.equals("comment", result.comment)
      assert.equals("//", result.marker)
    end)

    it("returns nil when style has no line comment", function()
      local style = { block_start = "/*", block_end = "*/" }
      local result = align.find_trailing_comment('int x = 1; /* comment */', style)

      assert.is_nil(result)
    end)

    it("handles comment marker at start of code (returns nil)", function()
      local style = { line = "--" }
      local result = align.find_trailing_comment('--local x = 1', style)

      assert.is_nil(result)
    end)
  end)

  describe("calculate_target_column", function()
    it("calculates column with min_gap", function()
      local lines_info = {
        { code = "short", comment = "a" },
        { code = "longer line", comment = "b" },
        { code = "x", comment = "c" },
      }

      local target = align.calculate_target_column(lines_info, { min_gap = 2, column = 80 })

      -- "longer line" is 11 chars + 2 = 13
      assert.equals(13, target)
    end)

    it("caps at max column", function()
      local lines_info = {
        { code = string.rep("x", 100), comment = "long" },
      }

      local target = align.calculate_target_column(lines_info, { min_gap = 2, column = 80 })

      assert.equals(80, target)
    end)

    it("handles empty lines_info", function()
      local target = align.calculate_target_column({}, { min_gap = 2, column = 80 })

      assert.equals(80, target)
    end)

    it("handles tabs in code using display width", function()
      local lines_info = {
        { code = "x\ty", comment = "a" }, -- tab expands to spaces
      }

      local target = align.calculate_target_column(lines_info, { min_gap = 2, column = 80 })

      -- Display width of "x\ty" depends on tabstop (usually 8)
      -- Just verify it's greater than literal length
      assert.is_true(target >= 2 + 2) -- at least "xy" + min_gap
    end)

    it("uses default opts when not provided", function()
      local lines_info = {
        { code = "test", comment = "a" },
      }

      -- Should use default min_gap=2, column=80
      local target = align.calculate_target_column(lines_info)

      assert.equals(6, target) -- 4 + 2
    end)

    it("merges partial opts with defaults", function()
      local lines_info = {
        { code = "test", comment = "a" },
      }

      -- Only specify min_gap, should use default column
      local target = align.calculate_target_column(lines_info, { min_gap = 5 })

      assert.equals(9, target) -- 4 + 5
    end)
  end)

  describe("align_lines", function()
    local test_bufnr

    before_each(function()
      test_bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[test_bufnr].filetype = "lua"
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(test_bufnr) then
        vim.api.nvim_buf_delete(test_bufnr, { force = true })
      end
    end)

    it("aligns trailing comments correctly", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        'local x = 1 -- short',
        'local foo = "bar" -- longer',
        'local y = 2 -- another',
      })

      local count = align.align_lines(test_bufnr, 1, 3, { min_gap = 2, column = 80 })

      assert.equals(3, count)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)

      -- "local foo = "bar"" is 18 chars, +2 = column 20
      assert.equals('local x = 1        -- short', lines[1])
      assert.equals('local foo = "bar"  -- longer', lines[2])
      assert.equals('local y = 2        -- another', lines[3])
    end)

    it("skips lines without trailing comments", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        'local x = 1 -- comment',
        'local y = 2',
        'local z = 3 -- comment',
      })

      local count = align.align_lines(test_bufnr, 1, 3, { min_gap = 2, column = 80 })

      assert.equals(2, count)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)

      assert.equals('local x = 1  -- comment', lines[1])
      assert.equals('local y = 2', lines[2]) -- unchanged
      assert.equals('local z = 3  -- comment', lines[3])
    end)

    it("skips full-line comments", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        'local x = 1 -- comment',
        '-- this is a full comment',
        'local y = 2 -- comment',
      })

      local count = align.align_lines(test_bufnr, 1, 3, { min_gap = 2, column = 80 })

      assert.equals(2, count)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)

      assert.equals('local x = 1  -- comment', lines[1])
      assert.equals('-- this is a full comment', lines[2]) -- unchanged
      assert.equals('local y = 2  -- comment', lines[3])
    end)

    it("returns 0 when no trailing comments found", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        'local x = 1',
        'local y = 2',
      })

      local count = align.align_lines(test_bufnr, 1, 2, { min_gap = 2, column = 80 })

      assert.equals(0, count)
    end)

    it("respects max column setting", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        'local short = 1 -- comment',
        'local very_very_long_variable_name = "value" -- comment',
      })

      local count = align.align_lines(test_bufnr, 1, 2, { min_gap = 2, column = 40 })

      assert.equals(2, count)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)

      -- Should align to column 40 max, not longer line + min_gap
      assert.is_true(#lines[1] <= 60) -- rough check for capping
      assert.is_not_nil(lines[1]:match("%-%- comment$"))
      assert.is_not_nil(lines[2]:match("%-%- comment$"))
    end)

    it("uses min_gap when code exceeds max column", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        'local x = 1 -- comment',
        'local very_long_variable_name_that_exceeds_column_limit = "value" -- comment',
      })

      local count = align.align_lines(test_bufnr, 1, 2, { min_gap = 1, column = 20 })

      assert.equals(2, count)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)

      -- Long line should have min_gap only
      assert.is_not_nil(lines[2]:match('%S %-%- comment$'))
    end)

    it("handles partial range alignment", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        'local a = 1 -- first',
        'local b = 2 -- second',
        'local c = 3 -- third',
        'local d = 4 -- fourth',
      })

      -- Only align middle two lines
      local count = align.align_lines(test_bufnr, 2, 3, { min_gap = 2, column = 80 })

      assert.equals(2, count)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)

      assert.equals('local a = 1 -- first', lines[1]) -- unchanged
      assert.equals('local b = 2  -- second', lines[2]) -- aligned
      assert.equals('local c = 3  -- third', lines[3]) -- aligned
      assert.equals('local d = 4 -- fourth', lines[4]) -- unchanged
    end)

    it("handles tabs in code properly", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        'local x\t= 1 -- comment',
        'local y = 2 -- comment',
      })

      local count = align.align_lines(test_bufnr, 1, 2, { min_gap = 2, column = 80 })

      assert.equals(2, count)

      -- Both lines should have aligned comments
      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.is_not_nil(lines[1]:match('%-%- comment$'))
      assert.is_not_nil(lines[2]:match('%-%- comment$'))
    end)

    it("normalizes comment whitespace", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        'local x = 1 --   comment with extra spaces  ',
        'local y = 2 --comment no space',
      })

      local count = align.align_lines(test_bufnr, 1, 2, { min_gap = 2, column = 80 })

      assert.equals(2, count)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)

      -- Comments should be normalized with single space after marker
      assert.is_not_nil(lines[1]:match('%-%- comment with extra spaces$'))
      assert.is_not_nil(lines[2]:match('%-%- comment no space$'))
    end)

    it("uses default options when not provided", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        'local x = 1 -- comment',
      })

      local count = align.align_lines(test_bufnr, 1, 1) -- no opts

      assert.equals(1, count)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)

      -- Should use default min_gap=2
      assert.equals('local x = 1  -- comment', lines[1])
    end)
  end)

  describe("setup", function()
    it("updates default options", function()
      align.setup({
        align = {
          column = 100,
          min_gap = 4,
        }
      })

      local lines_info = {
        { code = "test", comment = "a" },
      }

      local target = align.calculate_target_column(lines_info)

      -- Should use new defaults: 4 + 4 = 8
      assert.equals(8, target)

      -- Reset to defaults for other tests
      align.setup({
        align = {
          column = 80,
          min_gap = 2,
        }
      })
    end)

    it("handles partial config", function()
      align.setup({
        align = {
          column = 120,
        }
      })

      local lines_info = {
        { code = string.rep("x", 118), comment = "a" },
      }

      local target = align.calculate_target_column(lines_info)

      -- Should cap at new column (118 + 2 = 120)
      assert.equals(120, target)

      -- Reset
      align.setup({
        align = {
          column = 80,
          min_gap = 2,
        }
      })
    end)

    it("handles nil config", function()
      align.setup(nil)
      -- Should not error
    end)

    it("handles config without align section", function()
      align.setup({
        other_option = true,
      })
      -- Should not error
    end)
  end)
end)
