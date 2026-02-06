local semantic = require("quill.features.semantic")

describe("semantic module", function()
  local test_bufnr

  before_each(function()
    test_bufnr = vim.api.nvim_create_buf(false, true)
  end)

  after_each(function()
    if vim.api.nvim_buf_is_valid(test_bufnr) then
      vim.api.nvim_buf_delete(test_bufnr, { force = true })
    end
  end)

  describe("find_attached_decorators", function()
    it("should find single decorator in Python", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "@dataclass",
        "def my_function():",
        "    pass",
      })

      local decorators = semantic.find_attached_decorators(test_bufnr, 2)
      assert.are.same({ 1 }, decorators)
    end)

    it("should find multiple decorators in Python", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "@dataclass",
        "@frozen",
        "@validate",
        "def my_function():",
        "    pass",
      })

      local decorators = semantic.find_attached_decorators(test_bufnr, 4)
      assert.are.same({ 1, 2, 3 }, decorators)
    end)

    it("should find decorators with arguments", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "@decorator(arg1, arg2)",
        "@another_decorator(foo='bar')",
        "def my_function():",
        "    pass",
      })

      local decorators = semantic.find_attached_decorators(test_bufnr, 3)
      assert.are.same({ 1, 2 }, decorators)
    end)

    it("should stop at blank line before decorator", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "@old_decorator",
        "",
        "@new_decorator",
        "def my_function():",
        "    pass",
      })

      local decorators = semantic.find_attached_decorators(test_bufnr, 4)
      assert.are.same({ 3 }, decorators)
    end)

    it("should stop at non-decorator line", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "# This is a comment",
        "@decorator",
        "def my_function():",
        "    pass",
      })

      local decorators = semantic.find_attached_decorators(test_bufnr, 3)
      assert.are.same({ 2 }, decorators)
    end)

    it("should return empty table for unsupported filetype", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "txt")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "@decorator",
        "def my_function():",
        "    pass",
      })

      local decorators = semantic.find_attached_decorators(test_bufnr, 2)
      assert.are.same({}, decorators)
    end)

    it("should handle indented decorators", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "class MyClass:",
        "    @property",
        "    @cached",
        "    def my_method(self):",
        "        pass",
      })

      local decorators = semantic.find_attached_decorators(test_bufnr, 4)
      assert.are.same({ 2, 3 }, decorators)
    end)

    it("should work with TypeScript decorators", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "typescript")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "@Component",
        "@Injectable()",
        "class MyClass {",
        "}",
      })

      local decorators = semantic.find_attached_decorators(test_bufnr, 3)
      assert.are.same({ 1, 2 }, decorators)
    end)

    it("should work with Java annotations", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "java")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "@Override",
        "@Deprecated",
        "public void myMethod() {",
        "}",
      })

      local decorators = semantic.find_attached_decorators(test_bufnr, 3)
      assert.are.same({ 1, 2 }, decorators)
    end)
  end)

  describe("find_function_with_decorators", function()
    it("should find function bounds without decorators", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "def my_function():",
        "    pass",
        "",
        "def another_function():",
      })

      local bounds = semantic.find_function_with_decorators(test_bufnr, 1)
      assert.is_not_nil(bounds)
      assert.equals(1, bounds.start_line)
      assert.equals(2, bounds.end_line)
    end)

    it("should include decorators when configured", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "@dataclass",
        "@frozen",
        "def my_function():",
        "    pass",
      })

      semantic.setup({ semantic = { include_decorators = true } })

      local bounds = semantic.find_function_with_decorators(test_bufnr, 3)
      assert.is_not_nil(bounds)
      assert.equals(1, bounds.start_line)
      assert.equals(4, bounds.end_line)
    end)

    it("should exclude decorators when configured", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "@dataclass",
        "@frozen",
        "def my_function():",
        "    pass",
      })

      semantic.setup({ semantic = { include_decorators = false } })

      local bounds = semantic.find_function_with_decorators(test_bufnr, 3)
      assert.is_not_nil(bounds)
      assert.equals(3, bounds.start_line)
      assert.equals(4, bounds.end_line)

      -- Reset config
      semantic.setup({ semantic = { include_decorators = true } })
    end)

    it("should return nil for non-function line", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "# This is a comment",
        "x = 42",
      })

      local bounds = semantic.find_function_with_decorators(test_bufnr, 2)
      assert.is_nil(bounds)
    end)

    it("should handle nested functions", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "def outer():",
        "    @decorator",
        "    def inner():",
        "        pass",
        "    return inner",
      })

      local bounds = semantic.find_function_with_decorators(test_bufnr, 3)
      assert.is_not_nil(bounds)
      assert.equals(2, bounds.start_line)
      assert.equals(4, bounds.end_line)
    end)
  end)

  describe("find_doc_comment", function()
    describe("Python docstrings", function()
      it("should find single-line docstring", function()
        vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
        vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
          "def my_function():",
          '    """Single line docstring."""',
          "    pass",
        })

        local doc_bounds = semantic.find_doc_comment(test_bufnr, 1)
        assert.is_not_nil(doc_bounds)
        assert.equals(2, doc_bounds.start_line)
        assert.equals(2, doc_bounds.end_line)
      end)

      it("should find multi-line docstring with double quotes", function()
        vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
        vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
          "def my_function():",        -- line 1
          '    """',                   -- line 2
          "    Multi-line docstring.", -- line 3
          "    Second line.",          -- line 4
          '    """',                   -- line 5
          "    pass",                  -- line 6
        })

        local doc_bounds = semantic.find_doc_comment(test_bufnr, 1)
        assert.is_not_nil(doc_bounds)
        assert.equals(2, doc_bounds.start_line)
        assert.equals(5, doc_bounds.end_line)
      end)

      it("should find multi-line docstring with single quotes", function()
        vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
        vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
          "def my_function():",
          "    '''",
          "    Multi-line docstring.",
          "    '''",
          "    pass",
        })

        local doc_bounds = semantic.find_doc_comment(test_bufnr, 1)
        assert.is_not_nil(doc_bounds)
        assert.equals(2, doc_bounds.start_line)
        assert.equals(4, doc_bounds.end_line)
      end)

      it("should skip blank lines before docstring", function()
        vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
        vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
          "def my_function():",
          "",
          '    """Docstring after blank line."""',
          "    pass",
        })

        local doc_bounds = semantic.find_doc_comment(test_bufnr, 1)
        assert.is_not_nil(doc_bounds)
        assert.equals(3, doc_bounds.start_line)
        assert.equals(3, doc_bounds.end_line)
      end)

      it("should return nil if no docstring", function()
        vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
        vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
          "def my_function():",
          "    pass",
        })

        local doc_bounds = semantic.find_doc_comment(test_bufnr, 1)
        assert.is_nil(doc_bounds)
      end)

      it("should return nil if docstring is not first statement", function()
        vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
        vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
          "def my_function():",
          "    x = 42",
          '    """This is not a docstring."""',
          "    pass",
        })

        local doc_bounds = semantic.find_doc_comment(test_bufnr, 1)
        assert.is_nil(doc_bounds)
      end)
    end)

    describe("JSDoc comments", function()
      it("should find single-line JSDoc", function()
        vim.api.nvim_buf_set_option(test_bufnr, "filetype", "javascript")
        vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
          "/** Single line JSDoc */",
          "function myFunction() {",
          "}",
        })

        local doc_bounds = semantic.find_doc_comment(test_bufnr, 2)
        assert.is_not_nil(doc_bounds)
        assert.equals(1, doc_bounds.start_line)
        assert.equals(1, doc_bounds.end_line)
      end)

      it("should find multi-line JSDoc", function()
        vim.api.nvim_buf_set_option(test_bufnr, "filetype", "javascript")
        vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
          "/**",
          " * Multi-line JSDoc.",
          " * Second line.",
          " */",
          "function myFunction() {",
          "}",
        })

        local doc_bounds = semantic.find_doc_comment(test_bufnr, 5)
        assert.is_not_nil(doc_bounds)
        assert.equals(1, doc_bounds.start_line)
        assert.equals(4, doc_bounds.end_line)
      end)

      it("should handle JSDoc with blank line separation", function()
        vim.api.nvim_buf_set_option(test_bufnr, "filetype", "javascript")
        vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
          "/**",
          " * JSDoc comment.",
          " */",
          "",
          "function myFunction() {",
          "}",
        })

        local doc_bounds = semantic.find_doc_comment(test_bufnr, 5)
        assert.is_not_nil(doc_bounds)
        assert.equals(1, doc_bounds.start_line)
        assert.equals(3, doc_bounds.end_line)
      end)

      it("should work with TypeScript", function()
        vim.api.nvim_buf_set_option(test_bufnr, "filetype", "typescript")
        vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
          "/**",
          " * TypeScript function.",
          " */",
          "function myFunction(): void {",
          "}",
        })

        local doc_bounds = semantic.find_doc_comment(test_bufnr, 4)
        assert.is_not_nil(doc_bounds)
        assert.equals(1, doc_bounds.start_line)
        assert.equals(3, doc_bounds.end_line)
      end)

      it("should return nil if no JSDoc", function()
        vim.api.nvim_buf_set_option(test_bufnr, "filetype", "javascript")
        vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
          "// Regular comment",
          "function myFunction() {",
          "}",
        })

        local doc_bounds = semantic.find_doc_comment(test_bufnr, 2)
        assert.is_nil(doc_bounds)
      end)

      it("should return nil for regular block comment", function()
        vim.api.nvim_buf_set_option(test_bufnr, "filetype", "javascript")
        vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
          "/*",
          " * Regular block comment (not JSDoc).",
          " */",
          "function myFunction() {",
          "}",
        })

        local doc_bounds = semantic.find_doc_comment(test_bufnr, 4)
        assert.is_nil(doc_bounds)
      end)
    end)

    it("should return nil for unsupported filetype", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "function my_function()",
        "  -- comment",
        "end",
      })

      local doc_bounds = semantic.find_doc_comment(test_bufnr, 1)
      assert.is_nil(doc_bounds)
    end)
  end)

  describe("expand_selection_semantic", function()
    it("should expand to include decorators", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "@dataclass",
        "@frozen",
        "def my_function():",
        "    pass",
      })

      local new_start, new_end = semantic.expand_selection_semantic(
        test_bufnr,
        3,
        4,
        { include_decorators = true }
      )

      assert.equals(1, new_start)
      assert.equals(4, new_end)
    end)

    it("should expand to include Python docstring", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "def my_function():",
        '    """Docstring."""',
        "    pass",
      })

      local new_start, new_end = semantic.expand_selection_semantic(
        test_bufnr,
        1,
        1,  -- Only function definition selected
        { include_doc_comments = true }
      )

      assert.equals(1, new_start)
      assert.equals(2, new_end)  -- Expands to include docstring on line 2
    end)

    it("should expand to include JSDoc", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "javascript")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "/**",
        " * JSDoc comment.",
        " */",
        "function myFunction() {",
        "}",
      })

      local new_start, new_end = semantic.expand_selection_semantic(
        test_bufnr,
        4,
        5,
        { include_doc_comments = true }
      )

      assert.equals(1, new_start)
      assert.equals(5, new_end)
    end)

    it("should expand to include both decorators and docstrings", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "@dataclass",        -- line 1
        "def my_function():", -- line 2
        '    """Docstring."""',  -- line 3
        "    pass",          -- line 4
      })

      local new_start, new_end = semantic.expand_selection_semantic(
        test_bufnr,
        2,
        2,  -- Only function definition selected
        { include_decorators = true, include_doc_comments = true }
      )

      assert.equals(1, new_start)  -- Expands up to include decorator
      assert.equals(3, new_end)    -- Expands down to include docstring
    end)

    it("should respect include_decorators = false", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "@dataclass",
        "def my_function():",
        "    pass",
      })

      local new_start, new_end = semantic.expand_selection_semantic(
        test_bufnr,
        2,
        3,
        { include_decorators = false }
      )

      assert.equals(2, new_start)
      assert.equals(3, new_end)
    end)

    it("should respect include_doc_comments = false", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "def my_function():",
        '    """Docstring."""',
        "    pass",
      })

      local new_start, new_end = semantic.expand_selection_semantic(
        test_bufnr,
        1,
        3,
        { include_doc_comments = false }
      )

      assert.equals(1, new_start)
      assert.equals(3, new_end)
    end)

    it("should use config defaults when opts not provided", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "@dataclass",         -- line 1
        "def my_function():", -- line 2
        '    """Docstring."""',  -- line 3
        "    pass",           -- line 4
      })

      semantic.setup({
        semantic = {
          include_decorators = true,
          include_doc_comments = true,
        },
      })

      local new_start, new_end = semantic.expand_selection_semantic(test_bufnr, 2, 2)

      assert.equals(1, new_start)  -- Expands up to decorator
      assert.equals(3, new_end)    -- Expands down to docstring
    end)

    it("should handle selection without decorators or docstrings", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "def my_function():",
        "    pass",
      })

      local new_start, new_end = semantic.expand_selection_semantic(
        test_bufnr,
        1,
        2,
        { include_decorators = true, include_doc_comments = true }
      )

      assert.equals(1, new_start)
      assert.equals(2, new_end)
    end)
  end)

  describe("setup", function()
    it("should update include_decorators config", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "@dataclass",
        "def my_function():",
        "    pass",
      })

      semantic.setup({ semantic = { include_decorators = false } })

      local new_start, new_end = semantic.expand_selection_semantic(test_bufnr, 2, 3)

      assert.equals(2, new_start)
      assert.equals(3, new_end)

      -- Reset
      semantic.setup({ semantic = { include_decorators = true } })
    end)

    it("should update include_doc_comments config", function()
      vim.api.nvim_buf_set_option(test_bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        "def my_function():",
        '    """Docstring."""',
        "    pass",
      })

      semantic.setup({ semantic = { include_doc_comments = false } })

      local new_start, new_end = semantic.expand_selection_semantic(test_bufnr, 1, 3)

      assert.equals(1, new_start)
      assert.equals(3, new_end)

      -- Reset
      semantic.setup({ semantic = { include_doc_comments = true } })
    end)

    it("should handle nil config", function()
      assert.has_no.errors(function()
        semantic.setup(nil)
      end)
    end)

    it("should handle empty config", function()
      assert.has_no.errors(function()
        semantic.setup({})
      end)
    end)
  end)
end)
