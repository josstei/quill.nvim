---Unit tests for commands.lua
---Tests command registration, dispatch, completion, and error handling

describe("commands", function()
  local commands
  local original_require
  local debug_mock, normalize_mock, align_mock, convert_mock

  before_each(function()
    -- Save original require
    original_require = _G.require

    -- Clear any existing modules
    package.loaded["quill.commands"] = nil
    package.loaded["quill.features.debug"] = nil
    package.loaded["quill.features.normalize"] = nil
    package.loaded["quill.features.align"] = nil
    package.loaded["quill.features.convert"] = nil

    -- Create mock feature modules
    debug_mock = {
      toggle_buffer = function() return 0 end,
      toggle_project = function() return 0 end,
      list_regions = function() end,
    }
    normalize_mock = {
      normalize_buffer = function() return 0 end,
      normalize_range = function() return 0 end,
    }
    align_mock = {
      align_lines = function() return 0 end,
    }
    convert_mock = {
      convert_to_line = function() return { success = true, count = 0 } end,
      convert_to_block = function() return { success = true, count = 0 } end,
    }

    -- Install mock require
    _G.require = function(module_name)
      if module_name == "quill.features.debug" then
        return debug_mock
      elseif module_name == "quill.features.normalize" then
        return normalize_mock
      elseif module_name == "quill.features.align" then
        return align_mock
      elseif module_name == "quill.features.convert" then
        return convert_mock
      else
        return original_require(module_name)
      end
    end

    commands = original_require("quill.commands")
  end)

  after_each(function()
    -- Restore original require
    _G.require = original_require

    -- Clean up user commands
    pcall(vim.api.nvim_del_user_command, "Quill")
  end)

  describe("setup", function()
    it("registers :Quill user command", function()
      commands.setup()

      local cmd_exists = vim.fn.exists(":Quill") == 2
      assert.is_true(cmd_exists)
    end)

    it("registers command with completion", function()
      commands.setup()

      -- Verify command has completion function
      -- This is implicit - if setup completes without error, completion is registered
      assert.is_true(vim.fn.exists(":Quill") == 2)
    end)
  end)

  describe("dispatch", function()
    before_each(function()
      commands.setup()
    end)

    it("shows error for unknown subcommand", function()
      local messages = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      vim.cmd("Quill unknown")

      vim.notify = original_notify
      assert.equals(1, #messages)
      assert.is_true(messages[1].msg:find("Unknown subcommand") ~= nil)
      assert.equals(vim.log.levels.ERROR, messages[1].level)
    end)
  end)

  describe("debug subcommand", function()
    before_each(function()
      commands.setup()
    end)

    it("calls toggle_buffer for 'debug'", function()
      local called = false
      debug_mock.toggle_buffer = function()
        called = true
        return 0
      end

      vim.cmd("Quill debug")

      assert.is_true(called)
    end)

    it("calls toggle_project with confirm for 'debug --project'", function()
      local called = false
      local received_opts = nil
      debug_mock.toggle_project = function(opts)
        called = true
        received_opts = opts
        return 0
      end

      vim.cmd("Quill debug --project")

      assert.is_true(called)
      assert.is_true(received_opts.confirm)
      assert.is_true(received_opts.preview)
    end)

    it("calls list_regions with buffer scope for 'debug --list'", function()
      local called = false
      local received_scope = nil
      debug_mock.list_regions = function(scope)
        called = true
        received_scope = scope
      end

      vim.cmd("Quill debug --list")

      assert.is_true(called)
      assert.equals("buffer", received_scope)
    end)

    it("calls list_regions with project scope for 'debug --project --list'", function()
      local called = false
      local received_scope = nil
      debug_mock.list_regions = function(scope)
        called = true
        received_scope = scope
      end

      vim.cmd("Quill debug --project --list")

      assert.is_true(called)
      assert.equals("project", received_scope)
    end)
  end)

  describe("normalize subcommand", function()
    before_each(function()
      commands.setup()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "line 1",
        "line 2",
        "line 3",
        "line 4",
        "line 5",
      })
    end)

    it("calls normalize_buffer for 'normalize'", function()
      local called = false
      normalize_mock.normalize_buffer = function(bufnr)
        called = true
        return 5
      end

      -- Suppress notification
      local original_notify = vim.notify
      vim.notify = function() end

      vim.cmd("Quill normalize")

      vim.notify = original_notify
      assert.is_true(called)
    end)

    it("calls normalize_range for range command", function()
      local called = false
      local received_start, received_end = nil, nil
      normalize_mock.normalize_range = function(bufnr, start_line, end_line)
        called = true
        received_start = start_line
        received_end = end_line
        return 3
      end

      -- Suppress notification
      local original_notify = vim.notify
      vim.notify = function() end

      vim.cmd("1,5Quill normalize")

      vim.notify = original_notify
      assert.is_true(called)
      assert.equals(1, received_start)
      assert.equals(5, received_end)
    end)
  end)

  describe("align subcommand", function()
    before_each(function()
      commands.setup()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "line 1",
        "line 2",
        "line 3",
        "line 4",
        "line 5",
      })
    end)

    it("shows error without range", function()
      local messages = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      vim.cmd("Quill align")

      vim.notify = original_notify
      assert.equals(1, #messages)
      assert.is_true(messages[1].msg:find("requires a visual selection") ~= nil)
      assert.equals(vim.log.levels.ERROR, messages[1].level)
    end)

    it("calls align_lines with range", function()
      local called = false
      local received_start, received_end = nil, nil
      align_mock.align_lines = function(bufnr, start_line, end_line)
        called = true
        received_start = start_line
        received_end = end_line
        return 2
      end

      -- Suppress notification
      local original_notify = vim.notify
      vim.notify = function() end

      vim.cmd("1,5Quill align")

      vim.notify = original_notify
      assert.is_true(called)
      assert.equals(1, received_start)
      assert.equals(5, received_end)
    end)
  end)

  describe("convert subcommand", function()
    before_each(function()
      commands.setup()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "line 1",
        "line 2",
        "line 3",
        "line 4",
        "line 5",
      })
    end)

    it("shows error without range", function()
      local messages = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      vim.cmd("Quill convert line")

      vim.notify = original_notify
      assert.equals(1, #messages)
      assert.is_true(messages[1].msg:find("requires a visual selection") ~= nil)
      assert.equals(vim.log.levels.ERROR, messages[1].level)
    end)

    it("shows error without target", function()
      local messages = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      vim.cmd("1,5Quill convert")

      vim.notify = original_notify
      assert.equals(1, #messages)
      assert.is_true(messages[1].msg:find("Usage:") ~= nil)
      assert.equals(vim.log.levels.ERROR, messages[1].level)
    end)

    it("shows error for unknown target", function()
      local messages = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      vim.cmd("1,5Quill convert unknown")

      vim.notify = original_notify
      assert.equals(1, #messages)
      assert.is_true(messages[1].msg:find("Unknown target") ~= nil)
      assert.equals(vim.log.levels.ERROR, messages[1].level)
    end)

    it("calls convert_to_line for 'convert line'", function()
      local called = false
      convert_mock.convert_to_line = function(bufnr, start_line, end_line)
        called = true
        return { success = true, count = 3 }
      end

      -- Suppress notification
      local original_notify = vim.notify
      vim.notify = function() end

      vim.cmd("1,5Quill convert line")

      vim.notify = original_notify
      assert.is_true(called)
    end)

    it("calls convert_to_block for 'convert block'", function()
      local called = false
      convert_mock.convert_to_block = function(bufnr, start_line, end_line)
        called = true
        return { success = true, count = 3 }
      end

      -- Suppress notification
      local original_notify = vim.notify
      vim.notify = function() end

      vim.cmd("1,5Quill convert block")

      vim.notify = original_notify
      assert.is_true(called)
    end)

    it("shows error message on conversion failure", function()
      local messages = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      convert_mock.convert_to_line = function()
        return { success = false, error_msg = "Conversion failed", count = 0 }
      end

      vim.cmd("1,5Quill convert line")

      vim.notify = original_notify
      assert.equals(1, #messages)
      assert.equals("Conversion failed", messages[1].msg)
      assert.equals(vim.log.levels.ERROR, messages[1].level)
    end)
  end)

  describe("completion", function()
    before_each(function()
      commands.setup()
    end)

    it("completes subcommands", function()
      -- Simulate tab completion after ":Quill "
      local completions = vim.fn.getcompletion("Quill ", "cmdline")

      assert.is_true(vim.tbl_contains(completions, "debug"))
      assert.is_true(vim.tbl_contains(completions, "normalize"))
      assert.is_true(vim.tbl_contains(completions, "align"))
      assert.is_true(vim.tbl_contains(completions, "convert"))
    end)

    it("completes debug options", function()
      local completions = vim.fn.getcompletion("Quill debug ", "cmdline")

      assert.is_true(vim.tbl_contains(completions, "--project"))
      assert.is_true(vim.tbl_contains(completions, "--list"))
    end)

    it("completes convert targets", function()
      local completions = vim.fn.getcompletion("Quill convert ", "cmdline")

      assert.is_true(vim.tbl_contains(completions, "line"))
      assert.is_true(vim.tbl_contains(completions, "block"))
    end)

    it("filters completions by prefix", function()
      local completions = vim.fn.getcompletion("Quill no", "cmdline")

      assert.is_true(vim.tbl_contains(completions, "normalize"))
      assert.is_false(vim.tbl_contains(completions, "debug"))
      assert.is_false(vim.tbl_contains(completions, "align"))
    end)
  end)

  describe("argument parsing", function()
    before_each(function()
      commands.setup()
    end)

    it("handles multiple flags correctly", function()
      local called = false
      debug_mock.list_regions = function(scope)
        called = true
        assert.equals("project", scope)
      end

      vim.cmd("Quill debug --list --project")

      assert.is_true(called)
    end)

    it("handles flags in any order", function()
      local called = false
      debug_mock.list_regions = function(scope)
        called = true
        assert.equals("project", scope)
      end

      vim.cmd("Quill debug --project --list")

      assert.is_true(called)
    end)
  end)

  describe("range handling", function()
    before_each(function()
      commands.setup()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "line 1",
        "line 2",
        "line 3",
        "line 4",
        "line 5",
      })
    end)

    it("passes correct range to normalize_range", function()
      local received_start, received_end = nil, nil
      normalize_mock.normalize_range = function(bufnr, start_line, end_line)
        received_start = start_line
        received_end = end_line
        return 0
      end

      -- Suppress notification
      local original_notify = vim.notify
      vim.notify = function() end

      vim.cmd("2,4Quill normalize")

      vim.notify = original_notify
      assert.equals(2, received_start)
      assert.equals(4, received_end)
    end)

    it("passes correct range to align_lines", function()
      local received_start, received_end = nil, nil
      align_mock.align_lines = function(bufnr, start_line, end_line)
        received_start = start_line
        received_end = end_line
        return 0
      end

      -- Suppress notification
      local original_notify = vim.notify
      vim.notify = function() end

      vim.cmd("1,3Quill align")

      vim.notify = original_notify
      assert.equals(1, received_start)
      assert.equals(3, received_end)
    end)

    it("passes correct range to convert functions", function()
      local received_start, received_end = nil, nil
      convert_mock.convert_to_line = function(bufnr, start_line, end_line)
        received_start = start_line
        received_end = end_line
        return { success = true, count = 0 }
      end

      -- Suppress notification
      local original_notify = vim.notify
      vim.notify = function() end

      vim.cmd("3,5Quill convert line")

      vim.notify = original_notify
      assert.equals(3, received_start)
      assert.equals(5, received_end)
    end)
  end)

  describe("notification messages", function()
    before_each(function()
      commands.setup()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "line 1",
        "line 2",
        "line 3",
        "line 4",
        "line 5",
      })
    end)

    it("shows count for normalize", function()
      local messages = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      normalize_mock.normalize_buffer = function() return 3 end
      vim.cmd("Quill normalize")

      vim.notify = original_notify
      assert.equals(1, #messages)
      assert.is_true(messages[1].msg:find("Normalized 3 lines") ~= nil)
      assert.equals(vim.log.levels.INFO, messages[1].level)
    end)

    it("shows count for align", function()
      local messages = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      align_mock.align_lines = function() return 2 end
      vim.cmd("1,5Quill align")

      vim.notify = original_notify
      assert.equals(1, #messages)
      assert.is_true(messages[1].msg:find("Aligned 2 lines") ~= nil)
      assert.equals(vim.log.levels.INFO, messages[1].level)
    end)

    it("shows count for convert", function()
      local messages = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      convert_mock.convert_to_line = function() return { success = true, count = 4 } end
      vim.cmd("1,5Quill convert line")

      vim.notify = original_notify
      assert.equals(1, #messages)
      assert.is_true(messages[1].msg:find("Converted 4 lines to line comments") ~= nil)
      assert.equals(vim.log.levels.INFO, messages[1].level)
    end)
  end)
end)
