local normalize = require("quill.features.normalize")
local languages = require("quill.detection.languages")

describe("quill.features.normalize", function()
  describe("normalize_line", function()
    describe("line comments", function()
      local js_style = languages.get_style("javascript")
      local lua_style = languages.get_style("lua")
      local python_style = languages.get_style("python")

      it("normalizes line comment with no space", function()
        local normalized, changed = normalize.normalize_line("//foo", js_style)
        assert.equals("// foo", normalized)
        assert.is_true(changed)
      end)

      it("normalizes line comment with multiple spaces", function()
        local normalized, changed = normalize.normalize_line("//  foo", js_style)
        assert.equals("// foo", normalized)
        assert.is_true(changed)
      end)

      it("normalizes line comment with tabs", function()
        local normalized, changed = normalize.normalize_line("//\tfoo", js_style)
        assert.equals("// foo", normalized)
        assert.is_true(changed)
      end)

      it("preserves already normalized line comment", function()
        local normalized, changed = normalize.normalize_line("// foo", js_style)
        assert.equals("// foo", normalized)
        assert.is_false(changed)
      end)

      it("preserves empty line comment", function()
        local normalized, changed = normalize.normalize_line("//", js_style)
        assert.equals("//", normalized)
        assert.is_false(changed)
      end)

      it("normalizes empty line comment with spaces", function()
        local normalized, changed = normalize.normalize_line("//  ", js_style)
        assert.equals("//", normalized)
        assert.is_true(changed)
      end)

      it("preserves indentation while normalizing", function()
        local normalized, changed = normalize.normalize_line("  //foo", js_style)
        assert.equals("  // foo", normalized)
        assert.is_true(changed)
      end)

      it("handles different comment markers", function()
        local norm1, changed1 = normalize.normalize_line("--foo", lua_style)
        assert.equals("-- foo", norm1)
        assert.is_true(changed1)

        local norm2, changed2 = normalize.normalize_line("#foo", python_style)
        assert.equals("# foo", norm2)
        assert.is_true(changed2)
      end)

      it("does not modify uncommented lines", function()
        local normalized, changed = normalize.normalize_line("const x = 1;", js_style)
        assert.equals("const x = 1;", normalized)
        assert.is_false(changed)
      end)

      it("handles tab indentation", function()
        local normalized, changed = normalize.normalize_line("\t//foo", js_style)
        assert.equals("\t// foo", normalized)
        assert.is_true(changed)
      end)
    end)

    describe("single-line block comments", function()
      local js_style = languages.get_style("javascript")
      local lua_style = languages.get_style("lua")
      local html_style = languages.get_style("html")

      it("normalizes block comment with no spaces", function()
        local normalized, changed = normalize.normalize_line("/*foo*/", js_style)
        assert.equals("/* foo */", normalized)
        assert.is_true(changed)
      end)

      it("normalizes block comment with space after start only", function()
        local normalized, changed = normalize.normalize_line("/* foo*/", js_style)
        assert.equals("/* foo */", normalized)
        assert.is_true(changed)
      end)

      it("normalizes block comment with space before end only", function()
        local normalized, changed = normalize.normalize_line("/*foo */", js_style)
        assert.equals("/* foo */", normalized)
        assert.is_true(changed)
      end)

      it("normalizes block comment with multiple spaces", function()
        local normalized, changed = normalize.normalize_line("/*  foo  */", js_style)
        assert.equals("/* foo */", normalized)
        assert.is_true(changed)
      end)

      it("preserves already normalized block comment", function()
        local normalized, changed = normalize.normalize_line("/* foo */", js_style)
        assert.equals("/* foo */", normalized)
        assert.is_false(changed)
      end)

      it("preserves empty block comment", function()
        local normalized, changed = normalize.normalize_line("/**/", js_style)
        assert.equals("/**/", normalized)
        assert.is_false(changed)
      end)

      it("normalizes empty block comment with spaces", function()
        local normalized, changed = normalize.normalize_line("/*  */", js_style)
        assert.equals("/**/", normalized)
        assert.is_true(changed)
      end)

      it("preserves indentation while normalizing block comments", function()
        local normalized, changed = normalize.normalize_line("  /*foo*/", js_style)
        assert.equals("  /* foo */", normalized)
        assert.is_true(changed)
      end)

      it("handles Lua block comments", function()
        local normalized, changed = normalize.normalize_line("--[[foo]]", lua_style)
        assert.equals("--[[ foo ]]", normalized)
        assert.is_true(changed)
      end)

      it("handles HTML comments", function()
        local normalized, changed = normalize.normalize_line("<!--foo-->", html_style)
        assert.equals("<!-- foo -->", normalized)
        assert.is_true(changed)
      end)

      it("handles block comment with special characters", function()
        local normalized, changed = normalize.normalize_line("/*foo = bar + baz*/", js_style)
        assert.equals("/* foo = bar + baz */", normalized)
        assert.is_true(changed)
      end)
    end)

    describe("multi-line block comment start", function()
      local js_style = languages.get_style("javascript")
      local lua_style = languages.get_style("lua")

      it("normalizes block start with no space", function()
        local normalized, changed = normalize.normalize_line("/*foo", js_style)
        assert.equals("/* foo", normalized)
        assert.is_true(changed)
      end)

      it("normalizes block start with multiple spaces", function()
        local normalized, changed = normalize.normalize_line("/*  foo", js_style)
        assert.equals("/* foo", normalized)
        assert.is_true(changed)
      end)

      it("preserves already normalized block start", function()
        local normalized, changed = normalize.normalize_line("/* foo", js_style)
        assert.equals("/* foo", normalized)
        assert.is_false(changed)
      end)

      it("preserves empty block start", function()
        local normalized, changed = normalize.normalize_line("/*", js_style)
        assert.equals("/*", normalized)
        assert.is_false(changed)
      end)

      it("preserves indentation for block start", function()
        local normalized, changed = normalize.normalize_line("  /*foo", js_style)
        assert.equals("  /* foo", normalized)
        assert.is_true(changed)
      end)

      it("handles Lua multi-line block start", function()
        local normalized, changed = normalize.normalize_line("--[[foo", lua_style)
        assert.equals("--[[ foo", normalized)
        assert.is_true(changed)
      end)
    end)

    describe("multi-line block comment end", function()
      local js_style = languages.get_style("javascript")
      local lua_style = languages.get_style("lua")

      it("normalizes block end with no space", function()
        local normalized, changed = normalize.normalize_line("foo*/", js_style)
        assert.equals("foo */", normalized)
        assert.is_true(changed)
      end)

      it("normalizes block end with multiple spaces", function()
        local normalized, changed = normalize.normalize_line("foo  */", js_style)
        assert.equals("foo */", normalized)
        assert.is_true(changed)
      end)

      it("preserves already normalized block end", function()
        local normalized, changed = normalize.normalize_line("foo */", js_style)
        assert.equals("foo */", normalized)
        assert.is_false(changed)
      end)

      it("preserves empty block end", function()
        local normalized, changed = normalize.normalize_line("*/", js_style)
        assert.equals("*/", normalized)
        assert.is_false(changed)
      end)

      it("handles Lua multi-line block end", function()
        local normalized, changed = normalize.normalize_line("foo]]", lua_style)
        assert.equals("foo ]]", normalized)
        assert.is_true(changed)
      end)

      it("preserves trailing whitespace after block end", function()
        local normalized, changed = normalize.normalize_line("foo*/  ", js_style)
        assert.equals("foo */  ", normalized)
        assert.is_true(changed)
      end)
    end)

    describe("edge cases", function()
      local js_style = languages.get_style("javascript")

      it("handles nil input", function()
        local normalized, changed = normalize.normalize_line(nil, js_style)
        assert.is_nil(normalized)
        assert.is_false(changed)
      end)

      it("handles empty string", function()
        local normalized, changed = normalize.normalize_line("", js_style)
        assert.equals("", normalized)
        assert.is_false(changed)
      end)

      it("handles whitespace-only lines", function()
        local normalized, changed = normalize.normalize_line("   ", js_style)
        assert.equals("   ", normalized)
        assert.is_false(changed)
      end)

      it("does not normalize incomplete block comments", function()
        -- Block start without end (but not at end of line)
        local normalized, changed = normalize.normalize_line("/* incomplete", js_style)
        assert.equals("/* incomplete", normalized)
        -- This should be treated as multi-line block start
        assert.is_false(changed) -- Already has space
      end)

      it("handles multiple comment markers on same line", function()
        -- Only first marker should be normalized
        local normalized, changed = normalize.normalize_line("// // foo", js_style)
        assert.equals("// // foo", normalized)
        assert.is_false(changed)
      end)

      it("preserves mixed indentation", function()
        local normalized, changed = normalize.normalize_line(" \t //foo", js_style)
        assert.equals(" \t // foo", normalized)
        assert.is_true(changed)
      end)
    end)
  end)

  describe("normalize_buffer", function()
    before_each(function()
      -- Create a test buffer
      vim.cmd("new")
    end)

    after_each(function()
      -- Close test buffer
      vim.cmd("bwipeout!")
    end)

    it("normalizes all commented lines in buffer", function()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.bo[bufnr].filetype = "javascript"

      -- Set buffer content with unnormalized comments
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "//foo",
        "const x = 1;",
        "//  bar",
        "/*baz*/",
      })

      local count = normalize.normalize_buffer(bufnr)

      -- Should normalize 3 lines
      assert.equals(3, count)

      -- Check normalized content
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// foo", lines[1])
      assert.equals("const x = 1;", lines[2])
      assert.equals("// bar", lines[3])
      assert.equals("/* baz */", lines[4])
    end)

    it("returns 0 when no comments need normalization", function()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.bo[bufnr].filetype = "javascript"

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// already normalized",
        "const x = 1;",
        "/* also good */",
      })

      local count = normalize.normalize_buffer(bufnr)
      assert.equals(0, count)
    end)

    it("returns 0 for invalid buffer", function()
      local count = normalize.normalize_buffer(99999)
      assert.equals(0, count)
    end)

    it("handles empty buffer", function()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.bo[bufnr].filetype = "javascript"

      local count = normalize.normalize_buffer(bufnr)
      assert.equals(0, count)
    end)

    it("preserves indentation", function()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.bo[bufnr].filetype = "lua"

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "  --foo",
        "    --bar",
        "\t--baz",
      })

      normalize.normalize_buffer(bufnr)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("  -- foo", lines[1])
      assert.equals("    -- bar", lines[2])
      assert.equals("\t-- baz", lines[3])
    end)

    it("handles multi-line block comments", function()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.bo[bufnr].filetype = "javascript"

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/*foo",
        " * middle line",
        "bar*/",
      })

      local count = normalize.normalize_buffer(bufnr)

      -- Should normalize first and last line
      assert.equals(2, count)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("/* foo", lines[1])
      assert.equals(" * middle line", lines[2]) -- Middle line unchanged
      assert.equals("bar */", lines[3])
    end)
  end)

  describe("normalize_range", function()
    before_each(function()
      vim.cmd("new")
    end)

    after_each(function()
      vim.cmd("bwipeout!")
    end)

    it("normalizes only lines in range", function()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.bo[bufnr].filetype = "javascript"

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "//foo",
        "//bar",
        "//baz",
        "//qux",
      })

      -- Normalize lines 2-3 only
      local count = normalize.normalize_range(bufnr, 2, 3)
      assert.equals(2, count)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("//foo", lines[1]) -- Unchanged
      assert.equals("// bar", lines[2]) -- Normalized
      assert.equals("// baz", lines[3]) -- Normalized
      assert.equals("//qux", lines[4]) -- Unchanged
    end)

    it("handles reversed range", function()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.bo[bufnr].filetype = "javascript"

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "//foo",
        "//bar",
        "//baz",
      })

      -- Range with end before start should be swapped
      local count = normalize.normalize_range(bufnr, 3, 1)
      assert.equals(3, count)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// foo", lines[1])
      assert.equals("// bar", lines[2])
      assert.equals("// baz", lines[3])
    end)

    it("returns 0 for invalid buffer", function()
      local count = normalize.normalize_range(99999, 1, 3)
      assert.equals(0, count)
    end)

    it("handles single-line range", function()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.bo[bufnr].filetype = "python"

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "#foo",
        "#bar",
      })

      local count = normalize.normalize_range(bufnr, 1, 1)
      assert.equals(1, count)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("# foo", lines[1])
      assert.equals("#bar", lines[2]) -- Unchanged
    end)

    it("skips non-commented lines in range", function()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.bo[bufnr].filetype = "javascript"

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "//foo",
        "const x = 1;",
        "//bar",
      })

      local count = normalize.normalize_range(bufnr, 1, 3)
      assert.equals(2, count) -- Only the 2 commented lines

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// foo", lines[1])
      assert.equals("const x = 1;", lines[2]) -- Unchanged
      assert.equals("// bar", lines[3])
    end)
  end)

  describe("integration with different languages", function()
    before_each(function()
      vim.cmd("new")
    end)

    after_each(function()
      vim.cmd("bwipeout!")
    end)

    it("normalizes Lua comments", function()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.bo[bufnr].filetype = "lua"

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "--foo", "--[[bar]]" })

      normalize.normalize_buffer(bufnr)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("-- foo", lines[1])
      assert.equals("--[[ bar ]]", lines[2])
    end)

    it("normalizes Python comments", function()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.bo[bufnr].filetype = "python"

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "#foo", "#  bar" })

      normalize.normalize_buffer(bufnr)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("# foo", lines[1])
      assert.equals("# bar", lines[2])
    end)

    it("normalizes HTML comments", function()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.bo[bufnr].filetype = "html"

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "<!--foo-->" })

      normalize.normalize_buffer(bufnr)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("<!-- foo -->", lines[1])
    end)

    it("normalizes Rust comments", function()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.bo[bufnr].filetype = "rust"

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "//foo", "/*bar*/" })

      normalize.normalize_buffer(bufnr)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// foo", lines[1])
      assert.equals("/* bar */", lines[2])
    end)
  end)
end)
