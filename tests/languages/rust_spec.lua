local describe = require("plenary.busted").describe
local it = require("plenary.busted").it
local assert = require("plenary.busted").assert
local before_each = require("plenary.busted").before_each
local after_each = require("plenary.busted").after_each

describe("Rust language support", function()
  local toggle = require("quill.core.toggle")
  local detect = require("quill.core.detect")
  local semantic = require("quill.features.semantic")
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, "filetype", "rust")
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

    it("recognizes line comment", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// let x = 5;",
      })

      local is_commented = detect.is_commented(bufnr, 1)
      assert.is_true(is_commented)
    end)

    it("recognizes block comment", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/* let x = 5; */",
      })

      local is_commented = detect.is_commented(bufnr, 1)
      assert.is_true(is_commented)
    end)
  end)

  describe("line comment toggle", function()
    it("comments single line", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "let x = 5;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// let x = 5;", lines[1])
    end)

    it("uncomments single line", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// let x = 5;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("let x = 5;", lines[1])
    end)

    it("comments multiple lines", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "let x = 5;",
        "let y = 10;",
        "let z = 15;",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// let x = 5;", lines[1])
      assert.equals("// let y = 10;", lines[2])
      assert.equals("// let z = 15;", lines[3])
    end)
  end)

  describe("doc comments", function()
    it("finds triple-slash doc comment", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/// Calculate the sum of two numbers",
        "/// # Arguments",
        "/// * `a` - First number",
        "/// * `b` - Second number",
        "fn add(a: i32, b: i32) -> i32 {",
        "    a + b",
        "}",
      })

      local doc = semantic.find_doc_comment(bufnr, 5)
      assert.is_not_nil(doc)
      assert.equals(1, doc.start_line)
      assert.equals(4, doc.end_line)
    end)

    it("finds block doc comment", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/**",
        " * Calculate sum",
        " */",
        "fn sum(x: i32) -> i32 { x }",
      })

      local doc = semantic.find_doc_comment(bufnr, 4)
      assert.is_not_nil(doc)
      assert.equals(1, doc.start_line)
      assert.equals(3, doc.end_line)
    end)

    it("distinguishes doc comments from regular comments", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// Regular comment",
        "fn test() {}",
      })

      local doc = semantic.find_doc_comment(bufnr, 2)
      assert.is_nil(doc)
    end)

    it("finds inner doc comments (//!)", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "mod tests {",
        "    //! Module-level documentation",
        "    //! More docs",
        "}",
      })

      local doc = semantic.find_doc_comment(bufnr, 1)
      assert.is_not_nil(doc)
    end)
  end)

  describe("Rust-specific syntax", function()
    it("comments function definitions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "fn main() {",
        "    println!(\"Hello, world!\");",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// fn main() {", lines[1])
      assert.equals("//     println!(\"Hello, world!\");", lines[2])
      assert.equals("// }", lines[3])
    end)

    it("comments struct definitions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "struct Point {",
        "    x: i32,",
        "    y: i32,",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// struct Point {", lines[1])
      assert.equals("//     x: i32,", lines[2])
      assert.equals("//     y: i32,", lines[3])
      assert.equals("// }", lines[4])
    end)

    it("comments impl blocks", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "impl Point {",
        "    fn new(x: i32, y: i32) -> Self {",
        "        Point { x, y }",
        "    }",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// impl Point {", lines[1])
    end)

    it("comments trait definitions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "trait Drawable {",
        "    fn draw(&self);",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// trait Drawable {", lines[1])
      assert.equals("//     fn draw(&self);", lines[2])
      assert.equals("// }", lines[3])
    end)

    it("comments enum definitions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "enum Message {",
        "    Quit,",
        "    Move { x: i32, y: i32 },",
        "    Write(String),",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// enum Message {", lines[1])
      assert.equals("//     Quit,", lines[2])
    end)

    it("comments match expressions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "match value {",
        "    Some(x) => println!(\"{}\", x),",
        "    None => println!(\"None\"),",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// match value {", lines[1])
    end)

    it("comments macro invocations", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "println!(\"x = {}\", x);",
        "vec![1, 2, 3];",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// println!(\"x = {}\", x);", lines[1])
      assert.equals("// vec![1, 2, 3];", lines[2])
    end)

    it("comments attributes", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "#[derive(Debug, Clone)]",
        "#[allow(dead_code)]",
        "struct MyStruct {",
        "    field: i32,",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// #[derive(Debug, Clone)]", lines[1])
      assert.equals("// #[allow(dead_code)]", lines[2])
    end)

    it("finds attached attributes", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "#[derive(Debug)]",
        "#[serde(rename_all = \"camelCase\")]",
        "struct Config {",
        "    value: String,",
        "}",
      })

      local decorators = semantic.find_attached_decorators(bufnr, 3)
      assert.equals(2, #decorators)
    end)
  end)

  describe("advanced Rust features", function()
    it("comments generic functions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "fn largest<T: PartialOrd>(list: &[T]) -> &T {",
        "    &list[0]",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^// fn largest", lines[1])
    end)

    it("comments lifetime annotations", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {",
        "    if x.len() > y.len() { x } else { y }",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^// fn longest", lines[1])
    end)

    it("comments closure expressions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "let add = |a, b| a + b;",
        "let multiply = |x: i32, y: i32| -> i32 { x * y };",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// let add = |a, b| a + b;", lines[1])
      assert.equals("// let multiply = |x: i32, y: i32| -> i32 { x * y };", lines[2])
    end)

    it("comments async functions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "async fn fetch_data() -> Result<String, Error> {",
        "    Ok(String::from(\"data\"))",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// async fn fetch_data() -> Result<String, Error> {", lines[1])
    end)

    it("comments unsafe blocks", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "unsafe {",
        "    let ptr = &value as *const i32;",
        "    *ptr",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// unsafe {", lines[1])
    end)
  end)

  describe("nested block comments", function()
    it("supports nested block comments", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/* outer /* inner */ still commented */",
      })

      local is_commented = detect.is_commented(bufnr, 1)
      assert.is_true(is_commented)
    end)

    it("handles deeply nested comments", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/* level 1",
        "   /* level 2",
        "      /* level 3 */",
        "   */",
        "*/",
      })

      local is_commented = detect.is_commented(bufnr, 3)
      assert.is_true(is_commented)
    end)
  end)

  describe("indentation", function()
    it("preserves indentation when commenting", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "    let x = 5;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("    // let x = 5;", lines[1])
    end)

    it("handles nested scope indentation", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "fn main() {",
        "    if true {",
        "        let x = 5;",
        "    }",
        "}",
      })

      toggle.toggle_lines(bufnr, 2, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("    // if true {", lines[2])
      assert.equals("        // let x = 5;", lines[3])
      assert.equals("    // }", lines[4])
    end)
  end)

  describe("edge cases", function()
    it("handles strings containing comment markers", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'let comment = "// not a comment";',
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('// let comment = "// not a comment";', lines[1])
    end)

    it("handles raw string literals", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'let path = r"C:\\Users\\name";',
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^// let path", lines[1])
    end)

    it("handles byte string literals", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'let bytes = b"hello";',
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('// let bytes = b"hello";', lines[1])
    end)

    it("handles format strings", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'println!("x = {}, y = {}", x, y);',
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^// println!", lines[1])
    end)
  end)

  describe("module system", function()
    it("comments use statements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "use std::collections::HashMap;",
        "use std::io::{self, Read, Write};",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// use std::collections::HashMap;", lines[1])
      assert.equals("// use std::io::{self, Read, Write};", lines[2])
    end)

    it("comments mod declarations", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "mod tests {",
        "    #[test]",
        "    fn it_works() {}",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// mod tests {", lines[1])
    end)

    it("comments pub visibility", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "pub fn public_function() {}",
        "pub(crate) fn crate_function() {}",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// pub fn public_function() {}", lines[1])
      assert.equals("// pub(crate) fn crate_function() {}", lines[2])
    end)
  end)
end)
