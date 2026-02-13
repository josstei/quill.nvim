---Unit tests for quill.operators
---Tests count-aware toggle and visual mode operators

describe("quill.operators", function()
  local operators
  local toggle
  local config

  before_each(function()
    -- Reset modules
    package.loaded["quill.operators"] = nil
    package.loaded["quill.core.toggle"] = nil
    package.loaded["quill.config"] = nil

    operators = require("quill.operators")
    toggle = require("quill.core.toggle")
    config = require("quill.config")
  end)

  describe("toggle_lines_with_count", function()
    local test_bufnr

    before_each(function()
      test_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(test_bufnr)
      vim.bo[test_bufnr].filetype = "lua"
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(test_bufnr) then
        vim.api.nvim_buf_delete(test_bufnr, { force = true })
      end
    end)

    it("should toggle single line when count is 1", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "local x = 1",
        "local y = 2",
        "local z = 3",
      })

      vim.fn.line = function(arg)
        if arg == "." then
          return 2
        end
        return 1
      end

      operators.toggle_lines_with_count(1)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.are.equal("local x = 1", lines[1])
      assert.are.equal("-- local y = 2", lines[2])
      assert.are.equal("local z = 3", lines[3])
    end)

    it("should toggle multiple lines when count > 1", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "local x = 1",
        "local y = 2",
        "local z = 3",
        "local w = 4",
      })

      vim.fn.line = function(arg)
        if arg == "." then
          return 1
        end
        return 1
      end

      operators.toggle_lines_with_count(3)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.are.equal("-- local x = 1", lines[1])
      assert.are.equal("-- local y = 2", lines[2])
      assert.are.equal("-- local z = 3", lines[3])
      assert.are.equal("local w = 4", lines[4])
    end)

    it("should clamp count to buffer end", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "local x = 1",
        "local y = 2",
      })

      vim.fn.line = function(arg)
        if arg == "." then
          return 1
        end
        return 1
      end

      operators.toggle_lines_with_count(10)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.are.equal("-- local x = 1", lines[1])
      assert.are.equal("-- local y = 2", lines[2])
    end)

    it("should uncomment commented lines", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "-- local x = 1",
        "-- local y = 2",
      })

      vim.fn.line = function(arg)
        if arg == "." then
          return 1
        end
        return 1
      end

      operators.toggle_lines_with_count(2)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.are.equal("local x = 1", lines[1])
      assert.are.equal("local y = 2", lines[2])
    end)

    it("should handle empty lines", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "",
        "local x = 1",
      })

      vim.fn.line = function(arg)
        if arg == "." then
          return 1
        end
        return 1
      end

      operators.toggle_lines_with_count(1)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.truthy(lines)
    end)
  end)

  describe("toggle_visual", function()
    local test_bufnr

    before_each(function()
      test_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(test_bufnr)
      vim.bo[test_bufnr].filetype = "lua"
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(test_bufnr) then
        vim.api.nvim_buf_delete(test_bufnr, { force = true })
      end
    end)

    it("should toggle visual line selection with line comments for single line", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "local x = 1",
        "local y = 2",
        "local z = 3",
      })

      vim.fn.line = function(mark)
        if mark == "'<" then
          return 2
        elseif mark == "'>" then
          return 2
        end
        return 1
      end

      vim.fn.visualmode = function()
        return "V"
      end

      local start_line = vim.fn.line("'<")
      local end_line = vim.fn.line("'>")
      local mode = vim.fn.visualmode()
      operators.toggle_visual_range(start_line, end_line, mode)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.are.equal("local x = 1", lines[1])
      assert.are.equal("-- local y = 2", lines[2])
      assert.are.equal("local z = 3", lines[3])
    end)

    it("should toggle visual char selection", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "local x = 1",
        "local y = 2",
      })

      vim.fn.line = function(mark)
        if mark == "'<" then
          return 1
        elseif mark == "'>" then
          return 1
        end
        return 1
      end

      vim.fn.visualmode = function()
        return "v"
      end

      local start_line = vim.fn.line("'<")
      local end_line = vim.fn.line("'>")
      local mode = vim.fn.visualmode()
      operators.toggle_visual_range(start_line, end_line, mode)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.are.equal("-- local x = 1", lines[1])
      assert.are.equal("local y = 2", lines[2])
    end)

    it("should toggle visual line selection with block comments for multiple lines", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "local x = 1",
        "local y = 2",
        "local z = 3",
      })

      vim.fn.line = function(mark)
        if mark == "'<" then
          return 1
        elseif mark == "'>" then
          return 3
        end
        return 1
      end

      vim.fn.visualmode = function()
        return "V"
      end

      local start_line = vim.fn.line("'<")
      local end_line = vim.fn.line("'>")
      local mode = vim.fn.visualmode()
      operators.toggle_visual_range(start_line, end_line, mode)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      -- Visual line mode with multiple lines should use block comments
      assert.are.equal("--[[", lines[1])
      assert.are.equal("local x = 1", lines[2])
      assert.are.equal("local y = 2", lines[3])
      assert.are.equal("local z = 3", lines[4])
      assert.are.equal("]]", lines[5])
    end)

    it("should toggle visual block selection with block comments", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "local x = 1",
        "local y = 2",
        "local z = 3",
      })

      vim.fn.line = function(mark)
        if mark == "'<" then
          return 1
        elseif mark == "'>" then
          return 3
        end
        return 1
      end

      vim.fn.visualmode = function()
        return "\22"
      end

      local start_line = vim.fn.line("'<")
      local end_line = vim.fn.line("'>")
      local mode = vim.fn.visualmode()
      operators.toggle_visual_range(start_line, end_line, mode)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      -- Lua has block comments, so block-visual uses them
      assert.are.equal("--[[", lines[1])
      assert.are.equal("local x = 1", lines[2])
      assert.are.equal("local y = 2", lines[3])
      assert.are.equal("local z = 3", lines[4])
      assert.are.equal("]]", lines[5])
    end)

    it("should fall back to line comments when language has no block comments", function()
      vim.bo[test_bufnr].filetype = "sh"

      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "x=1",
        "y=2",
      })

      vim.fn.line = function(mark)
        if mark == "'<" then
          return 1
        elseif mark == "'>" then
          return 2
        end
        return 1
      end

      vim.fn.visualmode = function()
        return "\22"
      end

      local start_line = vim.fn.line("'<")
      local end_line = vim.fn.line("'>")
      local mode = vim.fn.visualmode()
      operators.toggle_visual_range(start_line, end_line, mode)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      -- Shell has no block comments, so falls back to line comments
      assert.are.equal("# x=1", lines[1])
      assert.are.equal("# y=2", lines[2])
    end)

    it("should handle invalid visual range", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "local x = 1",
      })

      vim.fn.line = function(mark)
        if mark == "'<" then
          return 5
        elseif mark == "'>" then
          return 1
        end
        return 1
      end

      vim.fn.visualmode = function()
        return "V"
      end

      local start_line = vim.fn.line("'<")
      local end_line = vim.fn.line("'>")
      local mode = vim.fn.visualmode()
      operators.toggle_visual_range(start_line, end_line, mode)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.are.equal("local x = 1", lines[1])
    end)
  end)

  describe("setup_operators", function()
    it("should register default keymaps", function()
      operators.setup_operators()

      local gc_map = vim.fn.maparg("gc", "n", false, true)
      local gcc_map = vim.fn.maparg("gcc", "n", false, true)
      local gc_visual_map = vim.fn.maparg("gc", "x", false, true)

      assert.truthy(gc_map)
      assert.truthy(gcc_map)
      assert.truthy(gc_visual_map)

      assert.are.equal("Toggle comment (operator)", gc_map.desc)
      assert.are.equal("Toggle comment on line(s)", gcc_map.desc)
      assert.are.equal("Toggle comment on selection", gc_visual_map.desc)
    end)

    it("should respect config for mapping names", function()
      config.setup({
        operators = {
          toggle = "cm",
        },
      })

      operators.setup_operators()

      local cm_map = vim.fn.maparg("cm", "n", false, true)
      local cmm_map = vim.fn.maparg("cmm", "n", false, true)
      local cm_visual_map = vim.fn.maparg("cm", "x", false, true)

      assert.truthy(cm_map)
      assert.truthy(cmm_map)
      assert.truthy(cm_visual_map)
    end)

    it("should allow override via opts parameter", function()
      operators.setup_operators({
        toggle = "gx",
      })

      local gx_map = vim.fn.maparg("gx", "n", false, true)
      local gxx_map = vim.fn.maparg("gxx", "n", false, true)
      local gx_visual = vim.fn.maparg("gx", "x", false, true)

      assert.truthy(gx_map)
      assert.truthy(gxx_map)
      assert.truthy(gx_visual)
    end)

    it("should allow explicit toggle_line override", function()
      operators.setup_operators({
        toggle = "gc",
        toggle_line = "<leader>cc",
      })

      local gc_map = vim.fn.maparg("gc", "n", false, true)
      local cc_map = vim.fn.maparg("<leader>cc", "n", false, true)

      assert.truthy(gc_map)
      assert.truthy(cc_map)
      assert.are.equal("Toggle comment on line(s)", cc_map.desc)
    end)
  end)

  describe("integration with toggle module", function()
    local test_bufnr

    before_each(function()
      test_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(test_bufnr)
      vim.bo[test_bufnr].filetype = "lua"
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(test_bufnr) then
        vim.api.nvim_buf_delete(test_bufnr, { force = true })
      end
    end)

    it("should use toggle_line for single line", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "local x = 1",
        "local y = 2",
      })

      vim.fn.line = function(arg)
        if arg == "." then
          return 1
        end
        return 1
      end

      operators.toggle_lines_with_count(1)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.are.equal("-- local x = 1", lines[1])
      assert.are.equal("local y = 2", lines[2])
    end)

    it("should use toggle_lines for multiple lines", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "local x = 1",
        "local y = 2",
      })

      vim.fn.line = function(arg)
        if arg == "." then
          return 1
        end
        return 1
      end

      operators.toggle_lines_with_count(2)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.are.equal("-- local x = 1", lines[1])
      assert.are.equal("-- local y = 2", lines[2])
    end)

    it("should use toggle_visual for visual mode with block comments for multiple lines", function()
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "local x = 1",
        "local y = 2",
      })

      vim.fn.line = function(mark)
        if mark == "'<" then
          return 1
        elseif mark == "'>" then
          return 2
        end
        return 1
      end

      vim.fn.visualmode = function()
        return "V"
      end

      local start_line = vim.fn.line("'<")
      local end_line = vim.fn.line("'>")
      local mode = vim.fn.visualmode()
      operators.toggle_visual_range(start_line, end_line, mode)

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.are.equal("--[[", lines[1])
      assert.are.equal("local x = 1", lines[2])
      assert.are.equal("local y = 2", lines[3])
      assert.are.equal("]]", lines[4])
    end)
  end)
end)
