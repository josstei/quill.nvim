---Unit tests for quill.keymaps
---Tests keymap registration, conflict detection, and warning system

describe("quill.keymaps", function()
  local keymaps
  local config

  before_each(function()
    -- Reset modules
    package.loaded["quill.keymaps"] = nil
    package.loaded["quill.config"] = nil
    package.loaded["quill.operators"] = nil

    config = require("quill.config")
    keymaps = require("quill.keymaps")

    -- Reset config to defaults
    config.setup({})

    -- Clear all existing keymaps that might conflict
    pcall(vim.keymap.del, "n", "gc")
    pcall(vim.keymap.del, "n", "gcc")
    pcall(vim.keymap.del, "x", "gc")
    pcall(vim.keymap.del, "o", "ic")
    pcall(vim.keymap.del, "x", "ic")
    pcall(vim.keymap.del, "o", "ac")
    pcall(vim.keymap.del, "x", "ac")
    pcall(vim.keymap.del, "o", "iC")
    pcall(vim.keymap.del, "x", "iC")
    pcall(vim.keymap.del, "o", "aC")
    pcall(vim.keymap.del, "x", "aC")
    pcall(vim.keymap.del, "n", "<leader>cd")
    pcall(vim.keymap.del, "n", "<leader>cD")
    pcall(vim.keymap.del, "n", "<leader>cn")
    pcall(vim.keymap.del, "n", "<leader>ca")
  end)

  describe("conflict detection", function()
    it("should not warn when no mapping exists", function()
      local warnings = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(warnings, { msg = msg, level = level })
      end

      config.setup({ warn_on_override = true })
      keymaps.register("n", "gz", ":echo 'test'<CR>", {})

      vim.notify = original_notify

      assert.are.equal(0, #warnings)
    end)

    it("should warn when mapping exists and warn_on_override is true", function()
      vim.keymap.set("n", "gz", ":echo 'test'<CR>", {})

      local warnings = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(warnings, { msg = msg, level = level })
      end

      config.setup({ warn_on_override = true })
      keymaps.register("n", "gz", ":echo 'new'<CR>", {})

      vim.notify = original_notify

      assert.are.equal(1, #warnings)
      assert.are.equal(vim.log.levels.WARN, warnings[1].level)
    end)

    it("should distinguish between different modes", function()
      vim.keymap.set("n", "gz", ":echo 'normal'<CR>", {})

      local warnings = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(warnings, { msg = msg, level = level })
      end

      config.setup({ warn_on_override = true })
      keymaps.register("n", "gz", ":echo 'new'<CR>", {})
      keymaps.register("x", "gz", ":echo 'visual'<CR>", {})

      vim.notify = original_notify

      assert.are.equal(1, #warnings)
    end)
  end)

  describe("override warnings", function()
    it("should include mode and lhs in warning", function()
      vim.keymap.set("n", "gz", ":echo 'test'<CR>", {})

      local warnings = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(warnings, { msg = msg, level = level })
      end

      config.setup({ warn_on_override = true })
      keymaps.register("n", "gz", ":echo 'new'<CR>", {})

      vim.notify = original_notify

      assert.are.equal(1, #warnings)
      assert.is_true(warnings[1].msg:match("Overriding") ~= nil)
      assert.is_true(warnings[1].msg:match("n%-mode") ~= nil)
      assert.is_true(warnings[1].msg:match("gz") ~= nil)
      assert.are.equal(vim.log.levels.WARN, warnings[1].level)
    end)

    it("should include rhs in warning when available", function()
      vim.keymap.set("n", "gz", ":echo 'test'<CR>", {})

      local warnings = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(warnings, { msg = msg, level = level })
      end

      config.setup({ warn_on_override = true })
      keymaps.register("n", "gz", ":echo 'new'<CR>", {})

      vim.notify = original_notify

      assert.are.equal(1, #warnings)
      assert.is_true(warnings[1].msg:match("was:") ~= nil)
    end)

    it("should handle callback-based mappings", function()
      vim.keymap.set("n", "gz", function() end, {})

      local warnings = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(warnings, { msg = msg, level = level })
      end

      config.setup({ warn_on_override = true })
      keymaps.register("n", "gz", ":echo 'new'<CR>", {})

      vim.notify = original_notify

      assert.are.equal(1, #warnings)
      assert.is_true(warnings[1].msg:match("Lua function") ~= nil)
    end)
  end)

  describe("register", function()
    it("should register keymap in specified mode", function()
      keymaps.register("n", "gz", ":echo 'test'<CR>", {})

      local mapping = vim.fn.maparg("gz", "n", false, true)
      assert.is_not_nil(mapping.lhs)
    end)

    it("should not warn when warn_on_override is false", function()
      config.setup({ warn_on_override = false })

      vim.keymap.set("n", "gz", ":echo 'existing'<CR>", {})

      local warnings = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(warnings, { msg = msg, level = level })
      end

      keymaps.register("n", "gz", ":echo 'new'<CR>", {})

      vim.notify = original_notify

      assert.are.equal(0, #warnings)
    end)

    it("should warn when warn_on_override is true and conflict exists", function()
      config.setup({ warn_on_override = true })

      vim.keymap.set("n", "gz", ":echo 'existing'<CR>", {})

      local warnings = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(warnings, { msg = msg, level = level })
      end

      keymaps.register("n", "gz", ":echo 'new'<CR>", {})

      vim.notify = original_notify

      assert.are.equal(1, #warnings)
      assert.are.equal(vim.log.levels.WARN, warnings[1].level)
    end)

    it("should register keymap in multiple modes", function()
      keymaps.register({ "o", "x" }, "ix", function() end, {})

      local o_mapping = vim.fn.maparg("ix", "o", false, true)
      local x_mapping = vim.fn.maparg("ix", "x", false, true)

      assert.is_not_nil(o_mapping.lhs)
      assert.is_not_nil(x_mapping.lhs)
    end)

    it("should warn for conflicts in all specified modes", function()
      config.setup({ warn_on_override = true })

      vim.keymap.set("o", "ix", function() end, {})
      vim.keymap.set("x", "ix", function() end, {})

      local warnings = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(warnings, { msg = msg, level = level })
      end

      keymaps.register({ "o", "x" }, "ix", function() end, {})

      vim.notify = original_notify

      assert.are.equal(2, #warnings)
      assert.are.equal(vim.log.levels.WARN, warnings[1].level)
      assert.are.equal(vim.log.levels.WARN, warnings[2].level)
    end)
  end)


  describe("setup", function()
    it("should register operator keymaps when enabled", function()
      config.setup({ keymaps = { operators = true } })
      keymaps.setup()

      local gc_mapping = vim.fn.maparg("gc", "n", false, true)
      local gcc_mapping = vim.fn.maparg("gcc", "n", false, true)
      local gc_visual = vim.fn.maparg("gc", "x", false, true)

      assert.is_not_nil(gc_mapping.lhs)
      assert.is_not_nil(gcc_mapping.lhs)
      assert.is_not_nil(gc_visual.lhs)
    end)

    it("should not register operator keymaps when disabled", function()
      config.setup({ keymaps = { operators = false } })
      keymaps.setup()

      local gc_mapping = vim.fn.maparg("gc", "n", false, true)
      local gcc_mapping = vim.fn.maparg("gcc", "n", false, true)
      local gc_visual = vim.fn.maparg("gc", "x", false, true)

      assert.is_nil(gc_mapping.lhs)
      assert.is_nil(gcc_mapping.lhs)
      assert.is_nil(gc_visual.lhs)
    end)

    it("should register textobject keymaps when enabled", function()
      config.setup({ keymaps = { textobjects = true, operators = false } })
      keymaps.setup()

      local ic_o = vim.fn.maparg("ic", "o", false, true)
      local ac_o = vim.fn.maparg("ac", "o", false, true)
      local iC_o = vim.fn.maparg("iC", "o", false, true)
      local aC_o = vim.fn.maparg("aC", "o", false, true)

      assert.is_not_nil(ic_o.lhs)
      assert.is_not_nil(ac_o.lhs)
      assert.is_not_nil(iC_o.lhs)
      assert.is_not_nil(aC_o.lhs)
    end)

    it("should not register textobject keymaps when disabled", function()
      config.setup({ keymaps = { textobjects = false, operators = false } })
      keymaps.setup()

      local ic_o = vim.fn.maparg("ic", "o", false, true)
      local ac_o = vim.fn.maparg("ac", "o", false, true)

      assert.is_nil(ic_o.lhs)
      assert.is_nil(ac_o.lhs)
    end)

    it("should register leader keymaps when enabled", function()
      config.setup({ keymaps = { leader = true, operators = false } })
      keymaps.setup()

      local cd_mapping = vim.fn.maparg("<leader>cd", "n", false, true)
      local cD_mapping = vim.fn.maparg("<leader>cD", "n", false, true)
      local cn_mapping = vim.fn.maparg("<leader>cn", "n", false, true)
      local ca_mapping = vim.fn.maparg("<leader>ca", "n", false, true)

      assert.is_not_nil(cd_mapping.lhs)
      assert.is_not_nil(cD_mapping.lhs)
      assert.is_not_nil(cn_mapping.lhs)
      assert.is_not_nil(ca_mapping.lhs)
    end)

    it("should not register leader keymaps when disabled", function()
      config.setup({ keymaps = { leader = false, operators = false } })
      keymaps.setup()

      local cd_mapping = vim.fn.maparg("<leader>cd", "n", false, true)
      local cD_mapping = vim.fn.maparg("<leader>cD", "n", false, true)

      assert.is_nil(cd_mapping.lhs)
      assert.is_nil(cD_mapping.lhs)
    end)

    it("should use custom operator mappings from config", function()
      config.setup({
        keymaps = { operators = true },
        operators = {
          toggle = "cm",
        },
      })
      keymaps.setup()

      local cm_mapping = vim.fn.maparg("cm", "n", false, true)
      local cmm_mapping = vim.fn.maparg("cmm", "n", false, true)
      local cm_visual = vim.fn.maparg("cm", "x", false, true)

      assert.is_not_nil(cm_mapping.lhs)
      assert.is_not_nil(cmm_mapping.lhs)
      assert.is_not_nil(cm_visual.lhs)
    end)

    it("should use custom textobject mappings from config", function()
      config.setup({
        keymaps = { textobjects = true, operators = false },
        textobjects = {
          inner_block = "ib",
          around_block = "ab",
          inner_line = "il",
          around_line = "al",
        },
      })
      keymaps.setup()

      local ib_o = vim.fn.maparg("ib", "o", false, true)
      local ab_o = vim.fn.maparg("ab", "o", false, true)
      local il_o = vim.fn.maparg("il", "o", false, true)
      local al_o = vim.fn.maparg("al", "o", false, true)

      assert.is_not_nil(ib_o.lhs)
      assert.is_not_nil(ab_o.lhs)
      assert.is_not_nil(il_o.lhs)
      assert.is_not_nil(al_o.lhs)
    end)

    it("should use custom leader mappings from config", function()
      config.setup({
        keymaps = { leader = true, operators = false },
        mappings = {
          debug_buffer = "<leader>db",
          debug_project = "<leader>dp",
          normalize = "<leader>nm",
          align = "<leader>al",
        },
      })
      keymaps.setup()

      local db_mapping = vim.fn.maparg("<leader>db", "n", false, true)
      local dp_mapping = vim.fn.maparg("<leader>dp", "n", false, true)
      local nm_mapping = vim.fn.maparg("<leader>nm", "n", false, true)
      local al_mapping = vim.fn.maparg("<leader>al", "n", false, true)

      assert.is_not_nil(db_mapping.lhs)
      assert.is_not_nil(dp_mapping.lhs)
      assert.is_not_nil(nm_mapping.lhs)
      assert.is_not_nil(al_mapping.lhs)
    end)

    it("should register all keymaps when all enabled", function()
      config.setup({
        keymaps = {
          operators = true,
          textobjects = true,
          leader = true,
        },
      })
      keymaps.setup()

      -- Operators
      assert.is_not_nil(vim.fn.maparg("gc", "n", false, true).lhs)
      assert.is_not_nil(vim.fn.maparg("gcc", "n", false, true).lhs)
      assert.is_not_nil(vim.fn.maparg("gc", "x", false, true).lhs)

      -- Text objects
      assert.is_not_nil(vim.fn.maparg("ic", "o", false, true).lhs)
      assert.is_not_nil(vim.fn.maparg("ac", "o", false, true).lhs)

      -- Leader mappings
      assert.is_not_nil(vim.fn.maparg("<leader>cd", "n", false, true).lhs)
      assert.is_not_nil(vim.fn.maparg("<leader>ca", "n", false, true).lhs)
    end)

    it("should not register any keymaps when all disabled", function()
      config.setup({
        keymaps = {
          operators = false,
          textobjects = false,
          leader = false,
        },
      })
      keymaps.setup()

      -- Operators
      assert.is_nil(vim.fn.maparg("gc", "n", false, true).lhs)
      assert.is_nil(vim.fn.maparg("gcc", "n", false, true).lhs)
      assert.is_nil(vim.fn.maparg("gc", "x", false, true).lhs)

      -- Text objects
      assert.is_nil(vim.fn.maparg("ic", "o", false, true).lhs)
      assert.is_nil(vim.fn.maparg("ac", "o", false, true).lhs)

      -- Leader mappings
      assert.is_nil(vim.fn.maparg("<leader>cd", "n", false, true).lhs)
      assert.is_nil(vim.fn.maparg("<leader>ca", "n", false, true).lhs)
    end)
  end)

  describe("leader keymaps", function()
    it("should register leader mappings with real implementations", function()
      config.setup({ keymaps = { leader = true, operators = false } })
      keymaps.setup()

      local cd_mapping = vim.fn.maparg("<leader>cd", "n", false, true)
      assert.is_not_nil(cd_mapping.lhs)
      assert.is_not_nil(cd_mapping.callback)
    end)
  end)
end)
