local describe = require("plenary.busted").describe
local it = require("plenary.busted").it
local assert = require("plenary.busted").assert
local before_each = require("plenary.busted").before_each
local after_each = require("plenary.busted").after_each

describe("HTML language support", function()
  local toggle = require("quill.core.toggle")
  local detect = require("quill.core.detect")
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, "filetype", "html")
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

    it("uses <!-- --> for block comments", function()
      local style = detect.get_comment_style(bufnr, 1, 0)
      assert.are.same({ "<!--", "-->" }, style.block)
    end)

    it("recognizes HTML comment", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<!-- <div>Hello</div> -->",
      })

      local is_commented = detect.is_commented(bufnr, 1)
      assert.is_true(is_commented)
    end)
  end)

  describe("block comment toggle", function()
    it("comments single HTML line", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<div>Hello World</div>",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("<!-- <div>Hello World</div> -->", lines[1])
    end)

    it("uncomments HTML comment", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<!-- <div>Hello World</div> -->",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("<div>Hello World</div>", lines[1])
    end)

    it("comments multiple HTML lines", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<div>",
        "  <p>Paragraph</p>",
        "</div>",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[3])
    end)
  end)

  describe("HTML-specific syntax", function()
    it("comments HTML elements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<button onclick='handleClick()'>Click me</button>",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("<!-- <button onclick='handleClick()'>Click me</button> -->", lines[1])
    end)

    it("comments self-closing tags", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<img src='image.png' alt='Description' />",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[1])
    end)

    it("comments DOCTYPE declarations", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<!DOCTYPE html>",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[1])
    end)

    it("comments meta tags", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<meta charset='UTF-8'>",
        "<meta name='viewport' content='width=device-width'>",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[2])
    end)

    it("comments link tags", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<link rel='stylesheet' href='styles.css'>",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[1])
    end)

    it("comments script tags", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<script src='app.js'></script>",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("<!-- <script src='app.js'></script> -->", lines[1])
    end)

    it("comments inline scripts", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<script>",
        "  console.log('Hello');",
        "</script>",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[3])
    end)

    it("comments style tags", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<style>",
        "  .container { width: 100%; }",
        "</style>",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[3])
    end)

    it("comments form elements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<form action='/submit' method='POST'>",
        "  <input type='text' name='username'>",
        "  <button type='submit'>Submit</button>",
        "</form>",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[4])
    end)
  end)

  describe("indentation", function()
    it("preserves indentation when commenting", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "  <div>",
        "    <p>Text</p>",
        "  </div>",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^  <!%-%-", lines[1])
      assert.matches("%-%->$", lines[3])
    end)

    it("handles deeply nested elements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<div>",
        "  <section>",
        "    <article>",
        "      <p>Deep content</p>",
        "    </article>",
        "  </section>",
        "</div>",
      })

      toggle.toggle_lines(bufnr, 3, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^    <!%-%-", lines[3])
      assert.matches("%-%->$", lines[5])
    end)
  end)

  describe("HTML5 semantic elements", function()
    it("comments semantic tags", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<header>",
        "  <nav>Navigation</nav>",
        "</header>",
        "<main>",
        "  <article>Content</article>",
        "</main>",
        "<footer>Footer</footer>",
      })

      toggle.toggle_lines(bufnr, 1, 7)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[7])
    end)

    it("comments custom elements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<my-component attr='value'>",
        "  <slot></slot>",
        "</my-component>",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[3])
    end)
  end)

  describe("data attributes", function()
    it("comments elements with data attributes", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<div data-id='123' data-role='container'>Content</div>",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[1])
    end)
  end)

  describe("edge cases", function()
    it("handles double dash in content", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<p>Text -- with -- dashes</p>",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[1])
    end)

    it("handles nested comments (invalid HTML but should handle)", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<!-- outer <!-- inner --> -->",
      })

      local is_commented = detect.is_commented(bufnr, 1)
      assert.is_true(is_commented)
    end)

    it("handles multiline attributes", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<button",
        "  class='btn btn-primary'",
        "  onclick='handleClick()'",
        ">",
        "  Click me",
        "</button>",
      })

      toggle.toggle_lines(bufnr, 1, 6)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[6])
    end)

    it("handles empty elements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<div></div>",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("<!-- <div></div> -->", lines[1])
    end)

    it("handles CDATA sections", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<script>",
        "<![CDATA[",
        "  function test() {}",
        "]]>",
        "</script>",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[5])
    end)
  end)

  describe("template syntax", function()
    it("comments template literals", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<template>",
        "  <div>Template content</div>",
        "</template>",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[3])
    end)

    it("comments slot elements", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<slot name='header'>Default header</slot>",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[1])
    end)
  end)

  describe("SVG content", function()
    it("comments inline SVG", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<svg width='100' height='100'>",
        "  <circle cx='50' cy='50' r='40' />",
        "</svg>",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[3])
    end)
  end)

  describe("accessibility attributes", function()
    it("comments ARIA attributes", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<button aria-label='Close' aria-pressed='false'>X</button>",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[1])
    end)

    it("comments role attributes", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<div role='navigation' aria-label='Main navigation'>",
        "  <ul>",
        "    <li>Item</li>",
        "  </ul>",
        "</div>",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^<!%-%-", lines[1])
      assert.matches("%-%->$", lines[5])
    end)
  end)
end)
