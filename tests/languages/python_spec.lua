local describe = require("plenary.busted").describe
local it = require("plenary.busted").it
local assert = require("plenary.busted").assert
local before_each = require("plenary.busted").before_each
local after_each = require("plenary.busted").after_each

describe("Python language support", function()
  local toggle = require("quill.core.toggle")
  local detect = require("quill.core.detect")
  local semantic = require("quill.features.semantic")
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, "filetype", "python")
    vim.api.nvim_set_current_buf(bufnr)
  end)

  after_each(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  describe("comment detection", function()
    it("uses # for line comments", function()
      local style = detect.get_comment_style(bufnr, 1, 0)
      assert.equals("#", style.line)
    end)

    it("has no block comment style", function()
      local style = detect.get_comment_style(bufnr, 1, 0)
      assert.is_nil(style.block)
    end)

    it("recognizes commented line", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "# x = 1",
      })

      local is_commented = detect.is_commented(bufnr, 1)
      assert.is_true(is_commented)
    end)
  end)

  describe("line comment toggle", function()
    it("comments single line", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "x = 1",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("# x = 1", lines[1])
    end)

    it("uncomments single line", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "# x = 1",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("x = 1", lines[1])
    end)

    it("comments multiple lines", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "x = 1",
        "y = 2",
        "z = 3",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("# x = 1", lines[1])
      assert.equals("# y = 2", lines[2])
      assert.equals("# z = 3", lines[3])
    end)
  end)

  describe("decorator handling", function()
    it("finds attached decorators", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@dataclass",
        "@frozen",
        "class MyClass:",
        "    pass",
      })

      local decorators = semantic.find_attached_decorators(bufnr, 3)
      assert.equals(2, #decorators)
      assert.equals(1, decorators[1])
      assert.equals(2, decorators[2])
    end)

    it("finds function decorators", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@staticmethod",
        "def my_function():",
        "    pass",
      })

      local decorators = semantic.find_attached_decorators(bufnr, 2)
      assert.equals(1, #decorators)
      assert.equals(1, decorators[1])
    end)

    it("finds multiple decorators with arguments", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@app.route('/api/users')",
        "@login_required",
        "@cache(timeout=300)",
        "def get_users():",
        "    pass",
      })

      local decorators = semantic.find_attached_decorators(bufnr, 4)
      assert.equals(3, #decorators)
    end)

    it("excludes decorators separated by blank line", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@decorator",
        "",
        "def my_function():",
        "    pass",
      })

      local decorators = semantic.find_attached_decorators(bufnr, 3)
      assert.equals(0, #decorators)
    end)

    it("excludes decorators separated by comments", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@decorator",
        "# Some comment",
        "def my_function():",
        "    pass",
      })

      local decorators = semantic.find_attached_decorators(bufnr, 3)
      assert.equals(0, #decorators)
    end)
  end)

  describe("docstrings", function()
    it("finds single-line docstring", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "def foo():",
        '    """This is a docstring."""',
        "    pass",
      })

      local doc = semantic.find_doc_comment(bufnr, 1)
      assert.is_not_nil(doc)
      assert.equals(2, doc.start_line)
      assert.equals(2, doc.end_line)
    end)

    it("finds multi-line docstring", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "def foo():",
        '    """',
        "    Multi-line docstring.",
        "    With multiple lines.",
        '    """',
        "    pass",
      })

      local doc = semantic.find_doc_comment(bufnr, 1)
      assert.is_not_nil(doc)
      assert.equals(2, doc.start_line)
      assert.equals(5, doc.end_line)
    end)

    it("finds class docstring", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "class MyClass:",
        '    """Class documentation."""',
        "    pass",
      })

      local doc = semantic.find_doc_comment(bufnr, 1)
      assert.is_not_nil(doc)
      assert.equals(2, doc.start_line)
    end)

    it("handles single quotes docstrings", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "def foo():",
        "    '''Single quote docstring.'''",
        "    pass",
      })

      local doc = semantic.find_doc_comment(bufnr, 1)
      assert.is_not_nil(doc)
      assert.equals(2, doc.start_line)
    end)

    it("returns nil when no docstring present", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "def foo():",
        "    pass",
      })

      local doc = semantic.find_doc_comment(bufnr, 1)
      assert.is_nil(doc)
    end)
  end)

  describe("indentation", function()
    it("preserves indentation when commenting", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "    x = 1",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("    # x = 1", lines[1])
    end)

    it("handles PEP 8 indentation", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "def function():",
        "    if condition:",
        "        nested_call()",
        "        another_call()",
      })

      toggle.toggle_lines(bufnr, 2, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("    # if condition:", lines[2])
      assert.equals("        # nested_call()", lines[3])
      assert.equals("        # another_call()", lines[4])
    end)
  end)

  describe("Python-specific syntax", function()
    it("comments function definitions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "def my_function(arg1, arg2):",
        "    return arg1 + arg2",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("# def my_function(arg1, arg2):", lines[1])
      assert.equals("#     return arg1 + arg2", lines[2])
    end)

    it("comments class definitions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "class MyClass(BaseClass):",
        "    def __init__(self):",
        "        pass",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("# class MyClass(BaseClass):", lines[1])
    end)

    it("comments import statements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "import os",
        "from pathlib import Path",
        "from typing import List, Dict",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("# import os", lines[1])
      assert.equals("# from pathlib import Path", lines[2])
      assert.equals("# from typing import List, Dict", lines[3])
    end)

    it("comments type hints", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "def process(items: List[str]) -> Dict[str, int]:",
        "    return {}",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^# def process", lines[1])
    end)

    it("comments list comprehensions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "result = [x * 2 for x in range(10) if x % 2 == 0]",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("# result = [x * 2 for x in range(10) if x % 2 == 0]", lines[1])
    end)
  end)

  describe("edge cases", function()
    it("handles strings containing # symbol", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'text = "This is #hashtag"',
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('# text = "This is #hashtag"', lines[1])
    end)

    it("handles f-strings", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'message = f"Hello {name}, you are {age} years old"',
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^# message = f", lines[1])
    end)

    it("handles multiline strings that aren't docstrings", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'text = """',
        "This is just a string,",
        "not a docstring",
        '"""',
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('# text = """', lines[1])
    end)

    it("handles lambda functions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "square = lambda x: x ** 2",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("# square = lambda x: x ** 2", lines[1])
    end)
  end)

  describe("Python frameworks", function()
    it("comments Django views", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@login_required",
        "def my_view(request):",
        "    return render(request, 'template.html')",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("# @login_required", lines[1])
    end)

    it("comments Flask routes", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@app.route('/users/<int:user_id>')",
        "def get_user(user_id):",
        "    return jsonify({'user_id': user_id})",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^# @app%.route", lines[1])
    end)
  end)
end)
