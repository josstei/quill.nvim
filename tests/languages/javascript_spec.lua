local describe = require("plenary.busted").describe
local it = require("plenary.busted").it
local assert = require("plenary.busted").assert
local before_each = require("plenary.busted").before_each
local after_each = require("plenary.busted").after_each

describe("JavaScript language support", function()
  local toggle = require("quill.core.toggle")
  local detect = require("quill.core.detect")
  local semantic = require("quill.features.semantic")
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, "filetype", "javascript")
    vim.api.nvim_set_current_buf(bufnr)
  end)

  after_each(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  describe("comment detection", function()
    it("uses // for line comments", function()
      local style = detect.get_comment_style(bufnr, 1, 0)
      assert.equals("//", style.line)
    end)

    it("uses /* */ for block comments", function()
      local style = detect.get_comment_style(bufnr, 1, 0)
      assert.are.same({ "/*", "*/" }, style.block)
    end)

    it("recognizes commented line", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// const x = 1;",
      })

      local is_commented = detect.is_commented(bufnr, 1)
      assert.is_true(is_commented)
    end)

    it("recognizes block comment", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/* const x = 1; */",
      })

      local is_commented = detect.is_commented(bufnr, 1)
      assert.is_true(is_commented)
    end)
  end)

  describe("line comment toggle", function()
    it("comments single line", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const x = 1;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// const x = 1;", lines[1])
    end)

    it("uncomments single line", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// const x = 1;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("const x = 1;", lines[1])
    end)

    it("comments multiple lines", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const x = 1;",
        "const y = 2;",
        "const z = 3;",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// const x = 1;", lines[1])
      assert.equals("// const y = 2;", lines[2])
      assert.equals("// const z = 3;", lines[3])
    end)
  end)

  describe("JSDoc comments", function()
    it("finds JSDoc comment block", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/**",
        " * Calculate sum of two numbers",
        " * @param {number} a - First number",
        " * @param {number} b - Second number",
        " * @returns {number} Sum of a and b",
        " */",
        "function sum(a, b) {",
        "  return a + b;",
        "}",
      })

      local doc = semantic.find_doc_comment(bufnr, 7)
      assert.is_not_nil(doc)
      assert.equals(1, doc.start_line)
      assert.equals(6, doc.end_line)
    end)

    it("distinguishes JSDoc from regular block comment", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/* Regular block comment */",
        "function foo() {}",
      })

      local doc = semantic.find_doc_comment(bufnr, 2)
      assert.is_nil(doc)
    end)

    it("finds single-line JSDoc", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/** Simple function */",
        "function simple() {}",
      })

      local doc = semantic.find_doc_comment(bufnr, 2)
      assert.is_not_nil(doc)
      assert.equals(1, doc.start_line)
      assert.equals(1, doc.end_line)
    end)
  end)

  describe("indentation", function()
    it("preserves indentation when commenting", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "  const x = 1;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("  // const x = 1;", lines[1])
    end)

    it("handles nested function indentation", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "function outer() {",
        "  function inner() {",
        "    return 42;",
        "  }",
        "}",
      })

      toggle.toggle_lines(bufnr, 2, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("  // function inner() {", lines[2])
      assert.equals("    // return 42;", lines[3])
      assert.equals("  // }", lines[4])
    end)
  end)

  describe("JavaScript-specific syntax", function()
    it("comments arrow functions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const square = (x) => x * x;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// const square = (x) => x * x;", lines[1])
    end)

    it("comments template literals", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const message = `Hello ${name}`;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// const message = `Hello ${name}`;", lines[1])
    end)

    it("comments destructuring assignments", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const { name, age } = person;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// const { name, age } = person;", lines[1])
    end)

    it("comments spread operator", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const newArray = [...oldArray, newItem];",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// const newArray = [...oldArray, newItem];", lines[1])
    end)

    it("comments async/await", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const data = await fetchData();",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// const data = await fetchData();", lines[1])
    end)

    it("comments class definitions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "class MyClass extends BaseClass {",
        "  constructor() {",
        "    super();",
        "  }",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// class MyClass extends BaseClass {", lines[1])
      assert.equals("//   constructor() {", lines[2])
    end)

    it("comments import statements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "import React from 'react';",
        "import { useState, useEffect } from 'react';",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// import React from 'react';", lines[1])
      assert.equals("// import { useState, useEffect } from 'react';", lines[2])
    end)

    it("comments export statements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "export default MyComponent;",
        "export { util1, util2 };",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// export default MyComponent;", lines[1])
      assert.equals("// export { util1, util2 };", lines[2])
    end)
  end)

  describe("edge cases", function()
    it("handles regex with // in it", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const urlRegex = /https?:\\/\\//;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^// const urlRegex", lines[1])
    end)

    it("handles strings containing //", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'const url = "https://example.com";',
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('// const url = "https://example.com";', lines[1])
    end)

    it("handles multiline template literals", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const html = `",
        "  <div>",
        "    <span>Hello</span>",
        "  </div>",
        "`;",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// const html = `", lines[1])
      assert.equals("//   <div>", lines[2])
    end)

    it("handles optional chaining", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const name = user?.profile?.name;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// const name = user?.profile?.name;", lines[1])
    end)

    it("handles nullish coalescing", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const value = input ?? defaultValue;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// const value = input ?? defaultValue;", lines[1])
    end)
  end)

  describe("framework patterns", function()
    it("comments React hooks", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const [count, setCount] = useState(0);",
        "useEffect(() => {",
        "  document.title = `Count: ${count}`;",
        "}, [count]);",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^// const %[count", lines[1])
      assert.equals("// useEffect(() => {", lines[2])
    end)

    it("comments Express middleware", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "app.use((req, res, next) => {",
        "  console.log(req.method, req.path);",
        "  next();",
        "});",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// app.use((req, res, next) => {", lines[1])
    end)
  end)

  describe("block comment behavior", function()
    it("detects multiline block comment", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/*",
        " * This is a",
        " * multiline comment",
        " */",
      })

      local is_commented = detect.is_commented(bufnr, 2)
      assert.is_true(is_commented)
    end)

    it("handles inline block comment", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const x = /* inline */ 42;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// const x = /* inline */ 42;", lines[1])
    end)
  end)
end)
