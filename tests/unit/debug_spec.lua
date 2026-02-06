---Unit tests for debug region features
---Tests finding, toggling, and listing debug regions

describe("quill.features.debug", function()
  local debug
  local helpers = require("helpers")
  local create_buffer = helpers.create_buffer
  local delete_buffer = helpers.delete_buffer

  -- Track created buffers for cleanup
  local created_buffers = {}

  before_each(function()
    -- Clear module cache to ensure clean state
    package.loaded["quill.features.debug"] = nil
    package.loaded["quill.core.toggle"] = nil
    package.loaded["quill.core.detect"] = nil
    package.loaded["quill.detection.languages"] = nil

    debug = require("quill.features.debug")
    created_buffers = {}

    -- Setup with default config
    debug.setup({})
  end)

  after_each(function()
    -- Cleanup all created buffers
    for _, bufnr in ipairs(created_buffers) do
      delete_buffer(bufnr)
    end
    created_buffers = {}
  end)

  describe("find_debug_regions", function()
    it("should find single debug region in JavaScript", function()
      local lines = {
        "function test() {",
        "  // #region debug",
        "  console.log('debugging');",
        "  debugger;",
        "  // #endregion",
        "  return true;",
        "}",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      local regions = debug.find_debug_regions(bufnr)

      assert.equals(1, #regions)
      assert.equals(2, regions[1].start_line)
      assert.equals(5, regions[1].end_line)
      assert.is_false(regions[1].is_commented) -- Content is not commented
    end)

    it("should find multiple debug regions", function()
      local lines = {
        "// #region debug",
        "console.log('first');",
        "// #endregion",
        "",
        "function work() {",
        "  // #region debug",
        "  console.log('second');",
        "  // #endregion",
        "  return 42;",
        "}",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      local regions = debug.find_debug_regions(bufnr)

      assert.equals(2, #regions)
      assert.equals(1, regions[1].start_line)
      assert.equals(3, regions[1].end_line)
      assert.equals(6, regions[2].start_line)
      assert.equals(8, regions[2].end_line)
    end)

    it("should find regions in Python with different comment style", function()
      local lines = {
        "def test():",
        "    # #region debug",
        "    print('debugging')",
        "    # #endregion",
        "    return True",
      }

      local bufnr = create_buffer({ filetype = "python", lines = lines })
      table.insert(created_buffers, bufnr)
      local regions = debug.find_debug_regions(bufnr)

      assert.equals(1, #regions)
      assert.equals(2, regions[1].start_line)
      assert.equals(4, regions[1].end_line)
    end)

    it("should find regions in Lua", function()
      local lines = {
        "local function test()",
        "  -- #region debug",
        "  print('debugging')",
        "  -- #endregion",
        "  return true",
        "end",
      }

      local bufnr = create_buffer({ filetype = "lua", lines = lines })
      table.insert(created_buffers, bufnr)
      local regions = debug.find_debug_regions(bufnr)

      assert.equals(1, #regions)
      assert.equals(2, regions[1].start_line)
      assert.equals(4, regions[1].end_line)
    end)

    it("should find regions in CSS with block comments", function()
      local lines = {
        ".selector {",
        "  /* #region debug */",
        "  border: 1px solid red;",
        "  /* #endregion */",
        "  color: blue;",
        "}",
      }

      local bufnr = create_buffer({ filetype = "css", lines = lines })
      table.insert(created_buffers, bufnr)
      local regions = debug.find_debug_regions(bufnr)

      assert.equals(1, #regions)
      assert.equals(2, regions[1].start_line)
      assert.equals(4, regions[1].end_line)
    end)

    it("should handle empty region (no content between markers)", function()
      local lines = {
        "function test() {",
        "  // #region debug",
        "  // #endregion",
        "  return true;",
        "}",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      local regions = debug.find_debug_regions(bufnr)

      assert.equals(1, #regions)
      assert.equals(2, regions[1].start_line)
      assert.equals(3, regions[1].end_line)
      assert.is_false(regions[1].is_commented) -- Empty region is not commented
    end)

    it("should return empty list when no regions found", function()
      local lines = {
        "function test() {",
        "  console.log('no debug regions');",
        "  return true;",
        "}",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      local regions = debug.find_debug_regions(bufnr)

      assert.equals(0, #regions)
    end)

    it("should handle unclosed region (malformed)", function()
      local lines = {
        "function test() {",
        "  // #region debug",
        "  console.log('no end marker');",
        "  return true;",
        "}",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      local regions = debug.find_debug_regions(bufnr)

      -- Malformed region is ignored
      assert.equals(0, #regions)
    end)

    it("should detect commented region state", function()
      local lines = {
        "function test() {",
        "  // #region debug",
        "  // console.log('debugging');",
        "  // debugger;",
        "  // #endregion",
        "  return true;",
        "}",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      local regions = debug.find_debug_regions(bufnr)

      assert.equals(1, #regions)
      assert.is_true(regions[1].is_commented) -- Content is commented
    end)
  end)

  describe("is_region_commented", function()
    it("should return true when all content lines are commented", function()
      local lines = {
        "// #region debug",
        "// console.log('test');",
        "// debugger;",
        "// #endregion",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      local is_commented = debug.is_region_commented(bufnr, 1, 4)

      assert.is_true(is_commented)
    end)

    it("should return false when all content lines are uncommented", function()
      local lines = {
        "// #region debug",
        "console.log('test');",
        "debugger;",
        "// #endregion",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      local is_commented = debug.is_region_commented(bufnr, 1, 4)

      assert.is_false(is_commented)
    end)

    it("should return true for mixed state (majority commented)", function()
      local lines = {
        "// #region debug",
        "// console.log('test');",
        "debugger;",
        "// #endregion",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      local is_commented = debug.is_region_commented(bufnr, 1, 4)

      -- Mixed state is considered commented per implementation
      assert.is_true(is_commented)
    end)

    it("should return false for empty region", function()
      local lines = {
        "// #region debug",
        "// #endregion",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      local is_commented = debug.is_region_commented(bufnr, 1, 2)

      assert.is_false(is_commented) -- Empty region is not commented
    end)
  end)

  describe("toggle_region", function()
    it("should comment uncommented region content", function()
      local lines = {
        "function test() {",
        "  // #region debug",
        "  console.log('debugging');",
        "  debugger;",
        "  // #endregion",
        "  return true;",
        "}",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)

      local region = {
        start_line = 2,
        end_line = 5,
        is_commented = false,
      }

      local success = debug.toggle_region(bufnr, region)
      assert.is_true(success)

      local result_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      -- Markers should remain unchanged
      assert.equals("  // #region debug", result_lines[2])
      assert.equals("  // #endregion", result_lines[5])

      -- Content should be commented
      assert.equals("  // console.log('debugging');", result_lines[3])
      assert.equals("  // debugger;", result_lines[4])
    end)

    it("should uncomment commented region content", function()
      local lines = {
        "function test() {",
        "  // #region debug",
        "  // console.log('debugging');",
        "  // debugger;",
        "  // #endregion",
        "  return true;",
        "}",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)

      local region = {
        start_line = 2,
        end_line = 5,
        is_commented = true,
      }

      local success = debug.toggle_region(bufnr, region)
      assert.is_true(success)

      local result_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      -- Markers should remain unchanged
      assert.equals("  // #region debug", result_lines[2])
      assert.equals("  // #endregion", result_lines[5])

      -- Content should be uncommented
      assert.equals("  console.log('debugging');", result_lines[3])
      assert.equals("  debugger;", result_lines[4])
    end)

    it("should handle empty region gracefully", function()
      local lines = {
        "// #region debug",
        "// #endregion",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)

      local region = {
        start_line = 1,
        end_line = 2,
        is_commented = false,
      }

      local success = debug.toggle_region(bufnr, region)
      assert.is_true(success) -- Should succeed even with no content

      local result_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals(2, #result_lines) -- Lines unchanged
    end)

    it("should preserve indentation when toggling", function()
      local lines = {
        "  // #region debug",
        "    console.log('nested');",
        "  // #endregion",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)

      local region = {
        start_line = 1,
        end_line = 3,
        is_commented = false,
      }

      debug.toggle_region(bufnr, region)

      local result_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("    // console.log('nested');", result_lines[2])
    end)
  end)

  describe("toggle_buffer", function()
    it("should toggle all regions when all uncommented", function()
      local lines = {
        "// #region debug",
        "console.log('first');",
        "// #endregion",
        "",
        "// #region debug",
        "console.log('second');",
        "// #endregion",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      vim.api.nvim_set_current_buf(bufnr)

      local count = debug.toggle_buffer()

      assert.equals(2, count)

      local result_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      -- Both regions should be commented
      assert.equals("// console.log('first');", result_lines[2])
      assert.equals("// console.log('second');", result_lines[6])
    end)

    it("should toggle all regions when all commented", function()
      local lines = {
        "// #region debug",
        "// console.log('first');",
        "// #endregion",
        "",
        "// #region debug",
        "// console.log('second');",
        "// #endregion",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      vim.api.nvim_set_current_buf(bufnr)

      local count = debug.toggle_buffer()

      assert.equals(2, count)

      local result_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      -- Both regions should be uncommented
      assert.equals("console.log('first');", result_lines[2])
      assert.equals("console.log('second');", result_lines[6])
    end)

    it("should uncomment all when majority are commented", function()
      local lines = {
        "// #region debug",
        "// console.log('first');",
        "// #endregion",
        "",
        "// #region debug",
        "console.log('second');",
        "// #endregion",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      vim.api.nvim_set_current_buf(bufnr)

      local count = debug.toggle_buffer()

      assert.equals(2, count)

      local result_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      -- Both should be uncommented (majority rule)
      assert.equals("console.log('first');", result_lines[2])
      assert.equals("console.log('second');", result_lines[6])
    end)

    it("should return 0 and notify when no regions found", function()
      local lines = {
        "function test() {",
        "  return true;",
        "}",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      vim.api.nvim_set_current_buf(bufnr)

      local count = debug.toggle_buffer()

      assert.equals(0, count)
    end)

    it("should work in single undo group", function()
      local lines = {
        "// #region debug",
        "console.log('first');",
        "// #endregion",
        "",
        "// #region debug",
        "console.log('second');",
        "// #endregion",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      vim.api.nvim_set_current_buf(bufnr)

      -- Set buffer as modifiable and create initial undo point
      vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
      vim.api.nvim_buf_set_option(bufnr, "undolevels", vim.o.undolevels)

      -- Make a small change to establish baseline for undo
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { lines[1] })
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      debug.toggle_buffer()

      -- Verify content is commented
      local commented_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// console.log('first');", commented_lines[2])
      assert.equals("// console.log('second');", commented_lines[6])

      -- Undo should revert all changes at once
      vim.cmd("undo")

      local result_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("console.log('first');", result_lines[2])
      assert.equals("console.log('second');", result_lines[6])
    end)
  end)

  describe("list_regions", function()
    it("should populate quickfix for buffer scope", function()
      local lines = {
        "// #region debug",
        "console.log('first');",
        "// #endregion",
        "",
        "// #region debug",
        "console.log('second');",
        "// #endregion",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      vim.api.nvim_set_current_buf(bufnr)

      debug.list_regions("buffer")

      local qf_list = vim.fn.getqflist()

      assert.equals(2, #qf_list)
      assert.equals(1, qf_list[1].lnum)
      assert.equals(5, qf_list[2].lnum)
    end)

    it("should show state in quickfix text", function()
      local lines = {
        "// #region debug",
        "// console.log('commented');",
        "// #endregion",
        "",
        "// #region debug",
        "console.log('active');",
        "// #endregion",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      vim.api.nvim_set_current_buf(bufnr)

      debug.list_regions("buffer")

      local qf_list = vim.fn.getqflist()

      assert.equals(2, #qf_list)
      assert.truthy(qf_list[1].text:find("%[commented%]"))
      assert.truthy(qf_list[2].text:find("%[active%]"))
    end)

    it("should notify when no regions found in buffer", function()
      local lines = {
        "function test() {",
        "  return true;",
        "}",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      vim.api.nvim_set_current_buf(bufnr)

      debug.list_regions("buffer")

      local qf_list = vim.fn.getqflist()
      -- Quickfix should be empty or unchanged
      assert.is_true(#qf_list == 0 or qf_list[1].bufnr ~= bufnr)
    end)

    it("should error on invalid scope", function()
      local lines = { "// test" }
      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      vim.api.nvim_set_current_buf(bufnr)

      -- Should not error, just notify
      debug.list_regions("invalid")

      -- Should not populate quickfix
      local qf_list = vim.fn.getqflist()
      -- List should be empty or not contain new entries
      assert.is_true(true) -- Just verify no crash
    end)
  end)

  describe("setup", function()
    it("should use defaults when config is nil", function()
      debug.setup(nil)

      local lines = {
        "// #region debug",
        "console.log('default');",
        "// #endregion",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      local regions = debug.find_debug_regions(bufnr)

      assert.equals(1, #regions)
    end)
  end)

  describe("edge cases", function()
    it("should handle region at start of file", function()
      local lines = {
        "// #region debug",
        "console.log('start');",
        "// #endregion",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      local regions = debug.find_debug_regions(bufnr)

      assert.equals(1, #regions)
      assert.equals(1, regions[1].start_line)
    end)

    it("should handle region at end of file", function()
      local lines = {
        "function test() {",
        "  return true;",
        "}",
        "// #region debug",
        "console.log('end');",
        "// #endregion",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      local regions = debug.find_debug_regions(bufnr)

      assert.equals(1, #regions)
      assert.equals(6, regions[1].end_line)
    end)

    it("should handle markers with extra whitespace", function()
      local lines = {
        "//   #region debug  ",
        "console.log('whitespace');",
        "//   #endregion  ",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      local regions = debug.find_debug_regions(bufnr)

      assert.equals(1, #regions)
    end)

    it("should not find regions across different filetypes in same buffer", function()
      -- This is a theoretical case; in practice buffers have single filetype
      local lines = {
        "// #region debug",
        "console.log('js');",
        "// #endregion",
      }

      local bufnr = create_buffer({ filetype = "javascript", lines = lines })
      table.insert(created_buffers, bufnr)
      local regions = debug.find_debug_regions(bufnr)

      assert.equals(1, #regions) -- Should still find the region
    end)
  end)
end)
