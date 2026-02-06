local describe = require("plenary.busted").describe
local it = require("plenary.busted").it
local assert = require("plenary.busted").assert
local before_each = require("plenary.busted").before_each
local after_each = require("plenary.busted").after_each

describe("CSS language support", function()
  local toggle = require("quill.core.toggle")
  local detect = require("quill.core.detect")
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, "filetype", "css")
    vim.api.nvim_set_current_buf(bufnr)
  end)

  after_each(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  describe("comment detection", function()
    it("has no line comment style", function()
      local style = detect.get_comment_style(bufnr, 1, 0)
      assert.is_nil(style.line)
    end)

    it("uses /* */ for block comments", function()
      local style = detect.get_comment_style(bufnr, 1, 0)
      assert.are.same({ "/*", "*/" }, style.block)
    end)

    it("recognizes block comment", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/* .container { width: 100%; } */",
      })

      local is_commented = detect.is_commented(bufnr, 1)
      assert.is_true(is_commented)
    end)
  end)

  describe("block comment toggle", function()
    it("comments single line with block comment", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        ".container { width: 100%; }",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("/* .container { width: 100%; } */", lines[1])
    end)

    it("uncomments block comment", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/* .container { width: 100%; } */",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals(".container { width: 100%; }", lines[1])
    end)

    it("comments multiple lines with block comments", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        ".container {",
        "  width: 100%;",
        "  margin: 0 auto;",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[4])
    end)
  end)

  describe("CSS-specific syntax", function()
    it("comments selectors", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        ".button:hover { background: blue; }",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("/* .button:hover { background: blue; } */", lines[1])
    end)

    it("comments media queries", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@media (min-width: 768px) {",
        "  .container { width: 750px; }",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[3])
    end)

    it("comments keyframe animations", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@keyframes fadeIn {",
        "  from { opacity: 0; }",
        "  to { opacity: 1; }",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[4])
    end)

    it("comments CSS variables", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        ":root {",
        "  --primary-color: #007bff;",
        "  --secondary-color: #6c757d;",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[4])
    end)

    it("comments import statements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@import url('https://fonts.googleapis.com/css2?family=Roboto');",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[1])
    end)

    it("comments font-face declarations", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@font-face {",
        "  font-family: 'CustomFont';",
        "  src: url('/fonts/custom.woff2');",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[4])
    end)
  end)

  describe("indentation", function()
    it("preserves indentation when commenting", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "  .nested {",
        "    color: red;",
        "  }",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^  /%*", lines[1])
      assert.matches("%*/$", lines[3])
    end)

    it("handles nested rules", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        ".parent {",
        "  color: blue;",
        "  .child {",
        "    color: red;",
        "  }",
        "}",
      })

      toggle.toggle_lines(bufnr, 3, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^  /%*", lines[3])
      assert.matches("%*/$", lines[5])
    end)
  end)

  describe("advanced CSS features", function()
    it("comments grid layouts", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        ".grid {",
        "  display: grid;",
        "  grid-template-columns: repeat(3, 1fr);",
        "  gap: 1rem;",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[5])
    end)

    it("comments flexbox layouts", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        ".flex {",
        "  display: flex;",
        "  justify-content: space-between;",
        "  align-items: center;",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[5])
    end)

    it("comments pseudo-elements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        ".element::before {",
        "  content: '';",
        "  display: block;",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[4])
    end)

    it("comments attribute selectors", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "input[type='text'] { border: 1px solid #ccc; }",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[1])
    end)

    it("comments calc() functions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        ".element {",
        "  width: calc(100% - 2rem);",
        "  height: calc(100vh - 60px);",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[4])
    end)
  end)

  describe("edge cases", function()
    it("handles nested block comments (not supported in CSS)", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/* outer /* inner */ */",
      })

      local is_commented = detect.is_commented(bufnr, 1)
      assert.is_true(is_commented)
    end)

    it("handles multiline property values", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        ".element {",
        "  background: linear-gradient(",
        "    to bottom,",
        "    #fff 0%,",
        "    #000 100%",
        "  );",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 7)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[7])
    end)

    it("handles empty rulesets", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        ".empty {}",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("/* .empty {} */", lines[1])
    end)

    it("handles URL values with special characters", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        ".bg { background: url('image.png?v=1'); }",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[1])
    end)
  end)

  describe("preprocessor compatibility", function()
    it("comments SCSS-like syntax when in CSS file", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "$primary: #007bff;",
        ".button { color: $primary; }",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[2])
    end)
  end)

  describe("modern CSS features", function()
    it("comments container queries", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@container (min-width: 400px) {",
        "  .card { padding: 2rem; }",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[3])
    end)

    it("comments layer statements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@layer utilities {",
        "  .text-center { text-align: center; }",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[3])
    end)

    it("comments supports queries", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@supports (display: grid) {",
        "  .layout { display: grid; }",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[3])
    end)
  end)

  describe("error handling", function()
    it("handles malformed CSS gracefully", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        ".broken {",
        "  color red",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^/%*", lines[1])
      assert.matches("%*/$", lines[3])
    end)
  end)
end)
