---Unit tests for core/undo.lua
---Tests undo grouping functionality for multi-line operations

describe("undo grouping", function()
  local undo

  before_each(function()
    -- Clear package cache to get fresh module
    package.loaded["quill.core.undo"] = nil

    undo = require("quill.core.undo")

    -- Reset undo state before each test
    undo.reset_state()
  end)

  describe("with_undo_group", function()
    it("should execute function successfully", function()
      local called = false
      local result = undo.with_undo_group(function()
        called = true
        return "success"
      end)

      assert.is_true(called)
      assert.equals("success", result)
    end)

    it("should return function result", function()
      local result = undo.with_undo_group(function()
        return { value = 42 }
      end)

      assert.is_table(result)
      assert.equals(42, result.value)
    end)

    it("should handle functions with no return value", function()
      local result = undo.with_undo_group(function()
        -- no return
      end)

      assert.is_nil(result)
    end)

    it("should catch errors in function", function()
      local result, err = undo.with_undo_group(function()
        error("test error")
      end)

      assert.is_nil(result)
      assert.is_not_nil(err)
      assert.matches("test error", err)
    end)

    it("should validate argument is a function", function()
      assert.has_error(function()
        undo.with_undo_group("not a function")
      end, "with_undo_group: argument must be a function")

      assert.has_error(function()
        undo.with_undo_group(123)
      end, "with_undo_group: argument must be a function")

      assert.has_error(function()
        undo.with_undo_group(nil)
      end, "with_undo_group: argument must be a function")
    end)

    it("should group buffer modifications", function()
      -- Create a test buffer
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line 1", "line 2", "line 3" })

      -- Make modifications within undo group
      undo.with_undo_group(function()
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "modified line 1" })
        vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "modified line 2" })
        vim.api.nvim_buf_set_lines(bufnr, 2, 3, false, { "modified line 3" })
      end)

      -- Verify all lines were modified
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("modified line 1", lines[1])
      assert.equals("modified line 2", lines[2])
      assert.equals("modified line 3", lines[3])

      -- Note: Testing actual undo behavior (that u undoes all changes) would require
      -- more complex integration test with actual Vim undo commands
      -- For unit tests, we verify the function executes correctly

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should handle nested with_undo_group calls", function()
      local outer_called = false
      local inner_called = false

      undo.with_undo_group(function()
        outer_called = true

        undo.with_undo_group(function()
          inner_called = true
        end)
      end)

      assert.is_true(outer_called)
      assert.is_true(inner_called)
    end)

    it("should preserve errors from inner function", function()
      local _, outer_err = undo.with_undo_group(function()
        local _, inner_err = undo.with_undo_group(function()
          error("inner error")
        end)
        if inner_err then
          error("wrapped: " .. inner_err)
        end
      end)

      assert.is_not_nil(outer_err)
      assert.matches("wrapped:.*inner error", outer_err)
    end)

    it("should track state during execution", function()
      local in_group_during = nil
      local level_during = nil

      undo.with_undo_group(function()
        in_group_during = undo.is_in_group()
        level_during = undo.get_level()
      end)

      assert.is_true(in_group_during)
      assert.equals(1, level_during)

      -- State should be cleaned up after execution
      assert.is_false(undo.is_in_group())
      assert.equals(0, undo.get_level())
    end)

    it("should track state correctly in nested with_undo_group calls", function()
      local outer_level = nil
      local inner_level = nil

      undo.with_undo_group(function()
        outer_level = undo.get_level()

        undo.with_undo_group(function()
          inner_level = undo.get_level()
        end)
      end)

      assert.equals(1, outer_level)
      assert.equals(2, inner_level)

      -- State should be fully cleaned up
      assert.equals(0, undo.get_level())
      assert.is_false(undo.is_in_group())
    end)

    it("should clean up state even on error", function()
      local _, err = undo.with_undo_group(function()
        error("test error")
      end)

      assert.is_not_nil(err)

      -- State should be cleaned up despite error
      assert.is_false(undo.is_in_group())
      assert.equals(0, undo.get_level())
    end)

    it("should clean up state correctly in nested error scenario", function()
      undo.with_undo_group(function()
        local _, err = undo.with_undo_group(function()
          error("inner error")
        end)

        -- After inner error, we should be back at level 1
        assert.equals(1, undo.get_level())
        assert.is_true(undo.is_in_group())
      end)

      -- After outer completes, state should be fully cleaned
      assert.equals(0, undo.get_level())
      assert.is_false(undo.is_in_group())
    end)
  end)

  describe("start_undo_group and end_undo_group", function()
    it("should track group state", function()
      assert.is_false(undo.is_in_group())
      assert.equals(0, undo.get_level())

      undo.start_undo_group()
      assert.is_true(undo.is_in_group())
      assert.equals(1, undo.get_level())

      undo.end_undo_group()
      assert.is_false(undo.is_in_group())
      assert.equals(0, undo.get_level())
    end)

    it("should support nesting", function()
      undo.start_undo_group()
      assert.equals(1, undo.get_level())
      assert.is_true(undo.is_in_group())

      undo.start_undo_group()
      assert.equals(2, undo.get_level())
      assert.is_true(undo.is_in_group())

      undo.start_undo_group()
      assert.equals(3, undo.get_level())
      assert.is_true(undo.is_in_group())

      undo.end_undo_group()
      assert.equals(2, undo.get_level())
      assert.is_true(undo.is_in_group())

      undo.end_undo_group()
      assert.equals(1, undo.get_level())
      assert.is_true(undo.is_in_group())

      undo.end_undo_group()
      assert.equals(0, undo.get_level())
      assert.is_false(undo.is_in_group())
    end)

    it("should handle mismatched end_undo_group gracefully", function()
      -- Call end without start
      undo.end_undo_group()
      assert.equals(0, undo.get_level())
      assert.is_false(undo.is_in_group())

      -- Multiple ends without starts
      undo.end_undo_group()
      undo.end_undo_group()
      assert.equals(0, undo.get_level())
    end)

    it("should warn on mismatched end_undo_group", function()
      -- Spy on vim.notify to check for warnings
      local notify_called = false
      local original_notify = vim.notify

      vim.notify = function(msg, level)
        if level == vim.log.levels.WARN and msg:match("end_undo_group called without matching") then
          notify_called = true
        end
      end

      undo.end_undo_group()

      vim.notify = original_notify
      assert.is_true(notify_called)
    end)

    it("should allow manual buffer modifications", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line 1", "line 2" })

      undo.start_undo_group()

      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "modified 1" })
      vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "modified 2" })

      undo.end_undo_group()

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("modified 1", lines[1])
      assert.equals("modified 2", lines[2])

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should handle exceptions between start and end", function()
      undo.start_undo_group()
      assert.equals(1, undo.get_level())

      -- Simulate an error occurring without proper cleanup
      -- In real code, this might happen if an exception is thrown

      -- Reset should restore clean state
      undo.reset_state()
      assert.equals(0, undo.get_level())
      assert.is_false(undo.is_in_group())
    end)
  end)

  describe("is_in_group", function()
    it("should return false by default", function()
      assert.is_false(undo.is_in_group())
    end)

    it("should return true when in manual group", function()
      undo.start_undo_group()
      assert.is_true(undo.is_in_group())
      undo.end_undo_group()
    end)

    it("should return false after exiting all nested groups", function()
      undo.start_undo_group()
      undo.start_undo_group()
      assert.is_true(undo.is_in_group())

      undo.end_undo_group()
      assert.is_true(undo.is_in_group())

      undo.end_undo_group()
      assert.is_false(undo.is_in_group())
    end)
  end)

  describe("get_level", function()
    it("should return 0 by default", function()
      assert.equals(0, undo.get_level())
    end)

    it("should track nesting depth", function()
      assert.equals(0, undo.get_level())

      undo.start_undo_group()
      assert.equals(1, undo.get_level())

      undo.start_undo_group()
      assert.equals(2, undo.get_level())

      undo.end_undo_group()
      assert.equals(1, undo.get_level())

      undo.end_undo_group()
      assert.equals(0, undo.get_level())
    end)
  end)

  describe("reset_state", function()
    it("should reset all state to defaults", function()
      undo.start_undo_group()
      undo.start_undo_group()
      undo.start_undo_group()

      assert.equals(3, undo.get_level())
      assert.is_true(undo.is_in_group())

      undo.reset_state()

      assert.equals(0, undo.get_level())
      assert.is_false(undo.is_in_group())
    end)

    it("should allow fresh start after reset", function()
      undo.start_undo_group()
      undo.reset_state()

      undo.start_undo_group()
      assert.equals(1, undo.get_level())
      assert.is_true(undo.is_in_group())

      undo.end_undo_group()
      assert.equals(0, undo.get_level())
    end)
  end)

  describe("integration scenarios", function()
    it("should handle mixed manual and callback styles", function()
      undo.start_undo_group()

      undo.with_undo_group(function()
        -- Inner callback style
      end)

      undo.end_undo_group()

      assert.equals(0, undo.get_level())
      assert.is_false(undo.is_in_group())
    end)

    it("should handle real comment operation pattern", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "line 1",
        "line 2",
        "line 3",
        "line 4",
        "line 5",
      })

      -- Simulate commenting multiple lines
      undo.with_undo_group(function()
        for i = 0, 4 do
          local line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
          vim.api.nvim_buf_set_lines(bufnr, i, i + 1, false, { "// " .. line })
        end
      end)

      -- Verify all lines were commented
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      for i, line in ipairs(lines) do
        assert.matches("^// line " .. i, line)
      end

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should handle error recovery in comment operations", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line 1", "line 2", "line 3" })

      -- Simulate a comment operation that fails partway
      local _, err = undo.with_undo_group(function()
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "// line 1" })
        vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "// line 2" })

        -- Simulate error on third line
        error("simulated error")
      end)

      assert.is_not_nil(err)

      -- State should be clean after error
      assert.equals(0, undo.get_level())
      assert.is_false(undo.is_in_group())

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)
end)
