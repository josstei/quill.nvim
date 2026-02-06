local config = require("quill.config")

describe("config", function()
  before_each(function()
    config.setup()
  end)

  describe("get()", function()
    it("returns default configuration", function()
      local cfg = config.get()
      assert.is_not_nil(cfg)
      assert.is_table(cfg)
    end)

    it("includes all default sections", function()
      local cfg = config.get()
      assert.is_table(cfg.align)
      assert.is_table(cfg.debug)
      assert.is_table(cfg.keymaps)
      assert.is_table(cfg.mappings)
      assert.is_table(cfg.operators)
      assert.is_table(cfg.textobjects)
      assert.is_table(cfg.languages)
      assert.is_table(cfg.jsx)
      assert.is_table(cfg.semantic)
    end)

    it("has correct default values", function()
      local cfg = config.get()
      assert.equals(80, cfg.align.column)
      assert.equals(2, cfg.align.min_gap)
      assert.equals("#region debug", cfg.debug.start_marker)
      assert.equals("#endregion", cfg.debug.end_marker)
      assert.is_true(cfg.keymaps.operators)
      assert.is_true(cfg.keymaps.textobjects)
      assert.is_true(cfg.keymaps.leader)
      assert.equals("gc", cfg.operators.toggle)
      assert.equals("ic", cfg.textobjects.inner_block)
      assert.equals("ac", cfg.textobjects.around_block)
      assert.is_true(cfg.warn_on_override)
      assert.is_true(cfg.jsx.auto_detect)
      assert.is_true(cfg.semantic.include_decorators)
      assert.is_true(cfg.semantic.include_doc_comments)
    end)
  end)

  describe("setup()", function()
    it("merges user options with defaults", function()
      config.setup({
        align = {
          column = 100,
        },
      })
      local cfg = config.get()
      assert.equals(100, cfg.align.column)
      assert.equals(2, cfg.align.min_gap)
    end)

    it("deep merges nested tables", function()
      config.setup({
        keymaps = {
          operators = false,
        },
      })
      local cfg = config.get()
      assert.is_false(cfg.keymaps.operators)
      assert.is_true(cfg.keymaps.textobjects)
      assert.is_true(cfg.keymaps.leader)
    end)

    it("preserves defaults when no user options provided", function()
      config.setup()
      local cfg = config.get()
      assert.equals(80, cfg.align.column)
      assert.equals("gc", cfg.operators.toggle)
    end)
  end)

  describe("validate()", function()
    it("accepts valid configuration", function()
      assert.is_true(config.validate({}))
      assert.is_true(config.validate({
        align = { column = 100, min_gap = 3 },
      }))
    end)

    it("rejects invalid types", function()
      assert.is_false(config.validate("not a table"))
      assert.is_false(config.validate(123))
      assert.is_false(config.validate(true))
    end)

    it("rejects invalid align configuration", function()
      assert.is_false(config.validate({ align = "invalid" }))
      assert.is_false(config.validate({ align = { column = "not a number" } }))
      assert.is_false(config.validate({ align = { min_gap = "not a number" } }))
    end)

    it("rejects invalid debug configuration", function()
      assert.is_false(config.validate({ debug = "invalid" }))
      assert.is_false(config.validate({ debug = { start_marker = 123 } }))
      assert.is_false(config.validate({ debug = { end_marker = true } }))
    end)

    it("rejects invalid keymaps configuration", function()
      assert.is_false(config.validate({ keymaps = "invalid" }))
      assert.is_false(config.validate({ keymaps = { operators = "not a boolean" } }))
      -- Schema-based validation only validates known fields, unknown keys are ignored
      assert.is_true(config.validate({ keymaps = { invalid_key = true } }))
    end)

    it("rejects invalid mappings configuration", function()
      assert.is_false(config.validate({ mappings = "invalid" }))
      assert.is_false(config.validate({ mappings = { debug_buffer = 123 } }))
    end)

    it("rejects invalid operators configuration", function()
      assert.is_false(config.validate({ operators = "invalid" }))
      assert.is_false(config.validate({ operators = { toggle = 123 } }))
    end)

    it("rejects invalid textobjects configuration", function()
      assert.is_false(config.validate({ textobjects = "invalid" }))
      assert.is_false(config.validate({ textobjects = { inner_block = 123 } }))
    end)

    it("rejects invalid warn_on_override", function()
      assert.is_false(config.validate({ warn_on_override = "not a boolean" }))
      assert.is_false(config.validate({ warn_on_override = 1 }))
    end)

    it("rejects invalid languages configuration", function()
      assert.is_false(config.validate({ languages = "not a table" }))
    end)

    it("rejects invalid jsx configuration", function()
      assert.is_false(config.validate({ jsx = "invalid" }))
      assert.is_false(config.validate({ jsx = { auto_detect = "not a boolean" } }))
    end)

    it("rejects invalid semantic configuration", function()
      assert.is_false(config.validate({ semantic = "invalid" }))
      assert.is_false(config.validate({ semantic = { include_decorators = "not a boolean" } }))
      assert.is_false(config.validate({ semantic = { include_doc_comments = 123 } }))
    end)
  end)
end)
