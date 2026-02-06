local quill = require("quill")

describe("quill", function()
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
  end)

  after_each(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe("setup()", function()
    it("initializes the plugin", function()
      assert.has_no.errors(function()
        quill.setup()
      end)
    end)

    it("accepts user configuration", function()
      assert.has_no.errors(function()
        quill.setup({
          align = {
            column = 100,
          },
        })
      end)
    end)
  end)

  describe("Public API", function()
    describe("toggle_line()", function()
      it("exists", function()
        assert.is_function(quill.toggle_line)
      end)

      it("toggles the current line", function()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "local x = 1" })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        quill.toggle_line()
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        assert.equals("-- local x = 1", lines[1])
      end)
    end)

    describe("toggle_range()", function()
      it("exists", function()
        assert.is_function(quill.toggle_range)
      end)

      it("validates parameters", function()
        assert.has_error(function()
          quill.toggle_range("not a number", 5)
        end, "lines[1] must be a number, got string")

        assert.has_error(function()
          quill.toggle_range(1, "not a number")
        end, "lines[2] must be a number, got string")
      end)

      it("toggles a range of lines", function()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
          "local x = 1",
          "local y = 2",
        })
        quill.toggle_range(1, 2)
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        assert.equals("-- local x = 1", lines[1])
        assert.equals("-- local y = 2", lines[2])
      end)
    end)

    describe("comment()", function()
      it("exists", function()
        assert.is_function(quill.comment)
      end)

      it("validates parameters", function()
        assert.has_error(function()
          quill.comment("not a number", 5)
        end, "lines[1] must be a number, got string")

        assert.has_error(function()
          quill.comment(1, 5, "invalid")
        end, "style must be 'line' or 'block'")
      end)

      it("comments a range of lines", function()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "local x = 1" })
        quill.comment(1, 1, "line")
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        assert.equals("-- local x = 1", lines[1])
      end)
    end)

    describe("uncomment()", function()
      it("exists", function()
        assert.is_function(quill.uncomment)
      end)

      it("validates parameters", function()
        assert.has_error(function()
          quill.uncomment("not a number", 5)
        end, "lines[1] must be a number, got string")
      end)

      it("uncomments a range of lines", function()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "-- local x = 1" })
        quill.uncomment(1, 1)
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        assert.equals("local x = 1", lines[1])
      end)
    end)

    describe("get_style()", function()
      it("exists", function()
        assert.is_function(quill.get_style)
      end)

      it("validates parameters", function()
        assert.has_error(function()
          quill.get_style("not a number", 1, 1)
        end, "bufnr[1] must be a number, got string")

        assert.has_error(function()
          quill.get_style(0, "not a number", 1)
        end, "line[1] must be a number, got string")

        assert.has_error(function()
          quill.get_style(0, 1, "not a number")
        end, "col[1] must be a number, got string")
      end)

      it("returns comment style for buffer", function()
        local style = quill.get_style(bufnr, 1, 0)
        assert.is_table(style)
        assert.equals("--", style.line)
      end)
    end)

    describe("is_commented()", function()
      it("exists", function()
        assert.is_function(quill.is_commented)
      end)

      it("validates parameters", function()
        assert.has_error(function()
          quill.is_commented("not a number", 1)
        end, "bufnr[1] must be a number, got string")

        assert.has_error(function()
          quill.is_commented(0, "not a number")
        end, "line[1] must be a number, got string")
      end)

      it("detects commented lines", function()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "-- comment", "code" })
        assert.is_true(quill.is_commented(bufnr, 1))
        assert.is_false(quill.is_commented(bufnr, 2))
      end)
    end)

    describe("normalize()", function()
      it("exists", function()
        assert.is_function(quill.normalize)
      end)

      it("validates parameters", function()
        assert.has_error(function()
          quill.normalize("not a number")
        end, "bufnr[1] must be a number, got string")
      end)

      it("normalizes comments in buffer", function()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "--no space" })
        quill.normalize(bufnr)
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        assert.equals("-- no space", lines[1])
      end)
    end)

    describe("align()", function()
      it("exists", function()
        assert.is_function(quill.align)
      end)

      it("validates parameters", function()
        assert.has_error(function()
          quill.align("not a number", 5)
        end, "lines[1] must be a number, got string")

        assert.has_error(function()
          quill.align(1, 5, "not a table")
        end, "opts must be a table")
      end)

      it("aligns trailing comments", function()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
          "local x = 1 -- short",
          "local foo = 'bar' -- longer",
        })
        quill.align(1, 2)
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        -- Both comments should be aligned to same column
        local pos1 = lines[1]:find("--")
        local pos2 = lines[2]:find("--")
        assert.equals(pos1, pos2)
      end)
    end)

    describe("toggle_debug()", function()
      it("exists", function()
        assert.is_function(quill.toggle_debug)
      end)

      it("validates parameters", function()
        assert.has_error(function()
          quill.toggle_debug("invalid")
        end, "scope must be 'buffer' or 'project'")
      end)

      it("toggles debug regions in buffer", function()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
          "-- #region debug",
          "print('debug')",
          "-- #endregion",
        })
        quill.toggle_debug("buffer")
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        -- Content should be commented
        assert.matches("^%s*%-%-", lines[2])
      end)
    end)
  end)
end)
