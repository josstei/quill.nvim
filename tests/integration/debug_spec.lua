local describe = require("plenary.busted").describe
local it = require("plenary.busted").it
local assert = require("plenary.busted").assert
local before_each = require("plenary.busted").before_each
local after_each = require("plenary.busted").after_each

describe("debug region integration", function()
  local debug = require("quill.features.debug")
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
  end)

  after_each(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  describe("region detection", function()
    it("finds single debug region", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const x = 1;",
        "// #region debug",
        "console.log(x);",
        "// #endregion",
        "const y = 2;",
      })

      local regions = debug.find_debug_regions(bufnr)
      assert.equals(1, #regions)
      assert.equals(2, regions[1].start_line)
      assert.equals(4, regions[1].end_line)
      assert.is_false(regions[1].is_commented)
    end)

    it("finds multiple debug regions", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// #region debug",
        "console.log('first');",
        "// #endregion",
        "",
        "const x = 1;",
        "",
        "// #region debug",
        "console.log('second');",
        "// #endregion",
      })

      local regions = debug.find_debug_regions(bufnr)
      assert.equals(2, #regions)
      assert.equals(1, regions[1].start_line)
      assert.equals(3, regions[1].end_line)
      assert.equals(7, regions[2].start_line)
      assert.equals(9, regions[2].end_line)
    end)

    it("detects commented debug region", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// #region debug",
        "// console.log(x);",
        "// #endregion",
      })

      local regions = debug.find_debug_regions(bufnr)
      assert.equals(1, #regions)
      assert.is_true(regions[1].is_commented)
    end)

    it("handles nested regions", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// #region debug",
        "// #region inner",
        "console.log('nested');",
        "// #endregion",
        "// #endregion",
      })

      local regions = debug.find_debug_regions(bufnr)
      assert.equals(2, #regions)
    end)

    it("ignores non-debug regions", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// #region utilities",
        "function util() {}",
        "// #endregion",
        "",
        "// #region debug",
        "console.log('debug');",
        "// #endregion",
      })

      local regions = debug.find_debug_regions(bufnr)
      assert.equals(1, #regions)
      assert.equals(5, regions[1].start_line)
    end)
  end)

  describe("region toggling", function()
    it("comments all content in debug region", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const x = 1;",
        "// #region debug",
        "console.log(x);",
        "console.log('test');",
        "// #endregion",
        "const y = 2;",
      })

      debug.toggle_buffer(bufnr)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("const x = 1;", lines[1])
      assert.equals("// #region debug", lines[2])
      assert.equals("// console.log(x);", lines[3])
      assert.equals("// console.log('test');", lines[4])
      assert.equals("// #endregion", lines[5])
      assert.equals("const y = 2;", lines[6])
    end)

    it("uncomments all content in debug region", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// #region debug",
        "// console.log(x);",
        "// #endregion",
      })

      debug.toggle_buffer(bufnr)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// #region debug", lines[1])
      assert.equals("console.log(x);", lines[2])
      assert.equals("// #endregion", lines[3])
    end)

    it("toggles multiple regions independently", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// #region debug",
        "console.log('first');",
        "// #endregion",
        "",
        "// #region debug",
        "// console.log('second');",
        "// #endregion",
      })

      debug.toggle_buffer(bufnr)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// console.log('first');", lines[2])
      assert.equals("console.log('second');", lines[6])
    end)

    it("preserves indentation when toggling", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "function test() {",
        "  // #region debug",
        "  console.log('test');",
        "  // #endregion",
        "}",
      })

      debug.toggle_buffer(bufnr)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("  // console.log('test');", lines[3])
    end)
  end)

  describe("list_regions", function()
    it("populates quickfix list with debug regions", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// #region debug",
        "console.log('first');",
        "// #endregion",
        "",
        "// #region debug",
        "console.log('second');",
        "// #endregion",
      })

      debug.list_regions(bufnr)

      local qflist = vim.fn.getqflist()
      assert.equals(2, #qflist)
      assert.equals(1, qflist[1].lnum)
      assert.equals(5, qflist[2].lnum)
    end)

    it("includes region state in quickfix entry", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// #region debug",
        "console.log('active');",
        "// #endregion",
        "",
        "// #region debug",
        "// console.log('commented');",
        "// #endregion",
      })

      debug.list_regions(bufnr)

      local qflist = vim.fn.getqflist()
      assert.matches("active", qflist[1].text)
      assert.matches("commented", qflist[2].text)
    end)

    it("shows message when no debug regions found", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const x = 1;",
        "console.log(x);",
      })

      local messages = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      debug.list_regions(bufnr)

      vim.notify = original_notify

      assert.equals(1, #messages)
      assert.matches("No debug regions found", messages[1].msg)
    end)
  end)

  describe("edge cases", function()
    it("handles unclosed debug region", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// #region debug",
        "console.log('test');",
      })

      local regions = debug.find_debug_regions(bufnr)
      assert.equals(0, #regions)
    end)

    it("handles region marker without matching end", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// #region debug",
        "console.log('test');",
        "// #region debug",
        "// #endregion",
      })

      local regions = debug.find_debug_regions(bufnr)
      assert.equals(1, #regions)
      assert.equals(3, regions[1].start_line)
    end)

    it("handles empty debug region", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// #region debug",
        "// #endregion",
      })

      local regions = debug.find_debug_regions(bufnr)
      assert.equals(1, #regions)
      assert.equals(1, regions[1].start_line)
      assert.equals(2, regions[1].end_line)
    end)
  end)
end)
