---Unit tests for core/detect.lua
---Tests detection orchestration, config overrides, and fallback behavior

describe("detect orchestrator", function()
  local detect
  local config

  before_each(function()
    -- Clear package cache to get fresh modules
    package.loaded["quill.core.detect"] = nil
    package.loaded["quill.config"] = nil

    detect = require("quill.core.detect")
    config = require("quill.config")

    -- Reset config to defaults
    config.setup({})
  end)

  describe("get_comment_style", function()
    it("should return style for lua files", function()
      -- Create a buffer with lua filetype
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "-- comment", "local x = 1" })

      local style = detect.get_comment_style(bufnr, 1, 0)

      assert.is_not_nil(style)
      assert.equals("--", style.line)
      assert.is_table(style.block)
      assert.equals("--[[", style.block[1])
      assert.equals("]]", style.block[2])

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should return style for javascript files", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "// comment", "const x = 1;" })

      local style = detect.get_comment_style(bufnr, 1, 0)

      assert.is_not_nil(style)
      assert.equals("//", style.line)
      assert.is_table(style.block)
      assert.equals("/*", style.block[1])
      assert.equals("*/", style.block[2])

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should return style for python files", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "# comment", "x = 1" })

      local style = detect.get_comment_style(bufnr, 1, 0)

      assert.is_not_nil(style)
      assert.equals("#", style.line)
      assert.is_table(style.block)
      assert.equals('"""', style.block[1])
      assert.equals('"""', style.block[2])

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should apply config overrides", function()
      -- Configure custom override for python
      config.setup({
        languages = {
          python = {
            line = "##",
          },
        },
      })

      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "## custom comment", "x = 1" })

      local style = detect.get_comment_style(bufnr, 1, 0)

      assert.is_not_nil(style)
      assert.equals("##", style.line)
      -- Block should remain unchanged
      assert.is_table(style.block)
      assert.equals('"""', style.block[1])

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should handle filetype with no explicit definition via commentstring", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "customlang")
      vim.api.nvim_buf_set_option(bufnr, "commentstring", "### %s")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "### comment" })

      local style = detect.get_comment_style(bufnr, 1, 0)

      assert.is_not_nil(style)
      assert.equals("###", style.line)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should handle filetype with block commentstring", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "blocklang")
      vim.api.nvim_buf_set_option(bufnr, "commentstring", "/* %s */")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "/* comment */" })

      local style = detect.get_comment_style(bufnr, 1, 0)

      assert.is_not_nil(style)
      assert.is_table(style.block)
      assert.equals("/*", style.block[1])
      assert.equals("*/", style.block[2])

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should return nil for empty commentstring", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "nocomments")
      vim.api.nvim_buf_set_option(bufnr, "commentstring", "")

      local style = detect.get_comment_style(bufnr, 1, 0)

      assert.is_nil(style)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("get_filetype_style", function()
    it("should return style for known filetype", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")

      local style = detect.get_filetype_style(bufnr)

      assert.is_not_nil(style)
      assert.equals("--", style.line)
      assert.is_table(style.block)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should fall back to commentstring for unknown filetype", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "unknowntype")
      vim.api.nvim_buf_set_option(bufnr, "commentstring", "!! %s")

      local style = detect.get_filetype_style(bufnr)

      assert.is_not_nil(style)
      assert.equals("!!", style.line)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should return nil when no commentstring set", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "nocomments")
      vim.api.nvim_buf_set_option(bufnr, "commentstring", "")

      local style = detect.get_filetype_style(bufnr)

      assert.is_nil(style)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("is_commented", function()
    it("should detect lua line comment", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "-- This is a comment" })

      local is_commented = detect.is_commented(bufnr, 1)

      assert.is_true(is_commented)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should detect javascript line comment", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "// This is a comment" })

      local is_commented = detect.is_commented(bufnr, 1)

      assert.is_true(is_commented)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should detect python comment", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "# This is a comment" })

      local is_commented = detect.is_commented(bufnr, 1)

      assert.is_true(is_commented)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should detect block comment on single line", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "/* This is a comment */" })

      local is_commented = detect.is_commented(bufnr, 1)

      assert.is_true(is_commented)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should not detect uncommented lines", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "local x = 1" })

      local is_commented = detect.is_commented(bufnr, 1)

      assert.is_false(is_commented)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should handle empty lines", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })

      local is_commented = detect.is_commented(bufnr, 1)

      assert.is_false(is_commented)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should handle whitespace-only lines", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "    " })

      local is_commented = detect.is_commented(bufnr, 1)

      assert.is_false(is_commented)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should detect comments with leading whitespace", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "    -- indented comment" })

      local is_commented = detect.is_commented(bufnr, 1)

      assert.is_true(is_commented)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should not detect inline comments", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "local x = 1 -- inline comment" })

      local is_commented = detect.is_commented(bufnr, 1)

      assert.is_false(is_commented)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should not detect comment markers in strings", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'local x = "-- not a comment"' })

      local is_commented = detect.is_commented(bufnr, 1)

      assert.is_false(is_commented)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("config override precedence", function()
    it("should override line comment marker", function()
      config.setup({
        languages = {
          lua = {
            line = "---",
          },
        },
      })

      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")

      local style = detect.get_comment_style(bufnr, 1, 0)

      assert.equals("---", style.line)
      -- Block should remain unchanged
      assert.is_table(style.block)
      assert.equals("--[[", style.block[1])

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should override block comment markers", function()
      config.setup({
        languages = {
          lua = {
            block = { "{--", "--}" },
          },
        },
      })

      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")

      local style = detect.get_comment_style(bufnr, 1, 0)

      assert.equals("--", style.line) -- unchanged
      assert.is_table(style.block)
      assert.equals("{--", style.block[1])
      assert.equals("--}", style.block[2])

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should override multiple fields", function()
      config.setup({
        languages = {
          lua = {
            line = "##",
            block = { "/*", "*/" },
            supports_nesting = true,
          },
        },
      })

      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")

      local style = detect.get_comment_style(bufnr, 1, 0)

      assert.equals("##", style.line)
      assert.is_table(style.block)
      assert.equals("/*", style.block[1])
      assert.equals("*/", style.block[2])
      assert.is_true(style.supports_nesting)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should not affect other filetypes", function()
      config.setup({
        languages = {
          lua = {
            line = "##",
          },
        },
      })

      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "python")

      local style = detect.get_comment_style(bufnr, 1, 0)

      -- Python should be unaffected
      assert.equals("#", style.line)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("edge cases", function()
    it("should handle buffer 0 (current buffer)", function()
      vim.api.nvim_set_option_value("filetype", "lua", { buf = 0 })

      local style = detect.get_comment_style(0, 1, 0)

      assert.is_not_nil(style)
      assert.equals("--", style.line)
    end)

    it("should handle invalid buffer gracefully", function()
      -- Invalid buffer should return nil without throwing errors
      local style = detect.get_comment_style(99999, 1, 0)

      assert.is_nil(style)
    end)

    it("should handle out of range line numbers", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line 1" })

      -- Line 100 doesn't exist
      local is_commented = detect.is_commented(bufnr, 100)

      assert.is_false(is_commented)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)
end)
