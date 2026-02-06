local describe = require("plenary.busted").describe
local it = require("plenary.busted").it
local assert = require("plenary.busted").assert
local before_each = require("plenary.busted").before_each
local after_each = require("plenary.busted").after_each

describe("Go language support", function()
  local toggle = require("quill.core.toggle")
  local detect = require("quill.core.detect")
  local semantic = require("quill.features.semantic")
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, "filetype", "go")
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
        "// x := 5",
      })

      local is_commented = detect.is_commented(bufnr, 1)
      assert.is_true(is_commented)
    end)

    it("recognizes block comment", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/* x := 5 */",
      })

      local is_commented = detect.is_commented(bufnr, 1)
      assert.is_true(is_commented)
    end)
  end)

  describe("line comment toggle", function()
    it("comments single line", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "x := 5",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// x := 5", lines[1])
    end)

    it("uncomments single line", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// x := 5",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("x := 5", lines[1])
    end)

    it("comments multiple lines", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "x := 5",
        "y := 10",
        "z := 15",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// x := 5", lines[1])
      assert.equals("// y := 10", lines[2])
      assert.equals("// z := 15", lines[3])
    end)
  end)

  describe("doc comments", function()
    it("finds godoc comment", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// Add returns the sum of two integers.",
        "// The function panics if overflow occurs.",
        "func Add(a, b int) int {",
        "    return a + b",
        "}",
      })

      local doc = semantic.find_doc_comment(bufnr, 3)
      assert.is_not_nil(doc)
      assert.equals(1, doc.start_line)
      assert.equals(2, doc.end_line)
    end)

    it("finds package-level doc comment", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// Package math provides basic arithmetic operations.",
        "package math",
      })

      local doc = semantic.find_doc_comment(bufnr, 2)
      assert.is_not_nil(doc)
      assert.equals(1, doc.start_line)
    end)

    it("distinguishes doc comments from regular comments", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// TODO: implement this",
        "",
        "func todo() {}",
      })

      local doc = semantic.find_doc_comment(bufnr, 3)
      assert.is_nil(doc)
    end)
  end)

  describe("Go-specific syntax", function()
    it("comments function declarations", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "func main() {",
        '    fmt.Println("Hello, World!")',
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// func main() {", lines[1])
      assert.equals('//     fmt.Println("Hello, World!")', lines[2])
      assert.equals("// }", lines[3])
    end)

    it("comments method declarations", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "func (p *Point) Distance() float64 {",
        "    return math.Sqrt(p.X*p.X + p.Y*p.Y)",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// func (p *Point) Distance() float64 {", lines[1])
    end)

    it("comments struct definitions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "type Point struct {",
        "    X, Y int",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// type Point struct {", lines[1])
      assert.equals("//     X, Y int", lines[2])
      assert.equals("// }", lines[3])
    end)

    it("comments interface definitions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "type Reader interface {",
        "    Read(p []byte) (n int, err error)",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// type Reader interface {", lines[1])
      assert.equals("//     Read(p []byte) (n int, err error)", lines[2])
      assert.equals("// }", lines[3])
    end)

    it("comments type aliases", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "type ID = string",
        "type Handler func(http.ResponseWriter, *http.Request)",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// type ID = string", lines[1])
      assert.equals("// type Handler func(http.ResponseWriter, *http.Request)", lines[2])
    end)

    it("comments const declarations", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const (",
        "    StatusOK = 200",
        "    StatusNotFound = 404",
        ")",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// const (", lines[1])
      assert.equals("//     StatusOK = 200", lines[2])
      assert.equals("//     StatusNotFound = 404", lines[3])
      assert.equals("// )", lines[4])
    end)

    it("comments var declarations", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "var (",
        "    name string",
        "    age  int",
        ")",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// var (", lines[1])
      assert.equals("//     name string", lines[2])
    end)

    it("comments import statements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "import (",
        '    "fmt"',
        '    "net/http"',
        '    _ "github.com/lib/pq"',
        ")",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// import (", lines[1])
      assert.equals('//     "fmt"', lines[2])
    end)

    it("comments defer statements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "defer file.Close()",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// defer file.Close()", lines[1])
    end)

    it("comments go routines", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "go func() {",
        '    fmt.Println("goroutine")',
        "}()",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// go func() {", lines[1])
    end)

    it("comments channel operations", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "ch := make(chan int, 10)",
        "ch <- 42",
        "value := <-ch",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// ch := make(chan int, 10)", lines[1])
      assert.equals("// ch <- 42", lines[2])
      assert.equals("// value := <-ch", lines[3])
    end)

    it("comments select statements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "select {",
        "case msg := <-ch1:",
        '    fmt.Println(msg)',
        "case ch2 <- value:",
        '    fmt.Println("sent")',
        "default:",
        '    fmt.Println("nothing")',
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 8)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// select {", lines[1])
    end)
  end)

  describe("error handling patterns", function()
    it("comments error checks", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "if err != nil {",
        "    return err",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// if err != nil {", lines[1])
      assert.equals("//     return err", lines[2])
      assert.equals("// }", lines[3])
    end)

    it("comments multiple return values", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "func divide(a, b int) (int, error) {",
        "    if b == 0 {",
        '        return 0, errors.New("division by zero")',
        "    }",
        "    return a / b, nil",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 6)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// func divide(a, b int) (int, error) {", lines[1])
    end)
  end)

  describe("advanced features", function()
    it("comments generic functions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "func Map[T any, U any](slice []T, fn func(T) U) []U {",
        "    result := make([]U, len(slice))",
        "    for i, v := range slice {",
        "        result[i] = fn(v)",
        "    }",
        "    return result",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 7)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^// func Map", lines[1])
    end)

    it("comments type constraints", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "type Ordered interface {",
        "    ~int | ~float64 | ~string",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// type Ordered interface {", lines[1])
    end)

    it("comments embedding", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "type ReadWriter struct {",
        "    Reader",
        "    Writer",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// type ReadWriter struct {", lines[1])
      assert.equals("//     Reader", lines[2])
      assert.equals("//     Writer", lines[3])
    end)

    it("comments struct tags", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "type User struct {",
        '    Name string `json:"name" db:"user_name"`',
        '    Age  int    `json:"age" db:"user_age"`',
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// type User struct {", lines[1])
      assert.matches('//     Name string `json:"name"', lines[2])
    end)
  end)

  describe("indentation", function()
    it("preserves indentation when commenting", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "    x := 5",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("    // x := 5", lines[1])
    end)

    it("handles Go formatting conventions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "func main() {",
        "\tif true {",
        "\t\tx := 5",
        "\t}",
        "}",
      })

      toggle.toggle_lines(bufnr, 2, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("\t// if true {", lines[2])
      assert.equals("\t\t// x := 5", lines[3])
      assert.equals("\t// }", lines[4])
    end)
  end)

  describe("edge cases", function()
    it("handles strings containing comment markers", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'comment := "// not a comment"',
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('// comment := "// not a comment"', lines[1])
    end)

    it("handles raw string literals", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "pattern := `\\d+\\.\\d+`",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^// pattern :=", lines[1])
    end)

    it("handles multiline raw strings", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "query := `",
        "    SELECT * FROM users",
        "    WHERE active = true",
        "`",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// query := `", lines[1])
    end)

    it("handles blank identifier", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "_ = expensive_function()",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// _ = expensive_function()", lines[1])
    end)

    it("handles build tags", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "//go:build linux && amd64",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// //go:build linux && amd64", lines[1])
    end)

    it("handles compiler directives", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "//go:generate mockgen -source=interface.go",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^// //go:generate", lines[1])
    end)
  end)

  describe("testing patterns", function()
    it("comments test functions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "func TestAdd(t *testing.T) {",
        "    result := Add(2, 3)",
        "    if result != 5 {",
        '        t.Errorf("expected 5, got %d", result)',
        "    }",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 6)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// func TestAdd(t *testing.T) {", lines[1])
    end)

    it("comments benchmark functions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "func BenchmarkAdd(b *testing.B) {",
        "    for i := 0; i < b.N; i++ {",
        "        Add(2, 3)",
        "    }",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// func BenchmarkAdd(b *testing.B) {", lines[1])
    end)
  end)
end)
