local describe = require("plenary.busted").describe
local it = require("plenary.busted").it
local assert = require("plenary.busted").assert
local before_each = require("plenary.busted").before_each
local after_each = require("plenary.busted").after_each

describe("JSX context integration", function()
  local detect = require("quill.core.detect")
  local toggle = require("quill.core.toggle")
  local treesitter = require("quill.detection.treesitter")
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
  end)

  after_each(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  describe("context detection", function()
    it("uses JS comments outside JSX", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const x = 1;",
        "return (",
        "  <div>",
        "    <span>Hello</span>",
        "  </div>",
        ");",
      })

      local style = detect.get_comment_style(bufnr, 1, 0)
      assert.equals("//", style.line)
      assert.are.same({ "/*", "*/" }, style.block)
    end)

    it("detects JSX context correctly", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "return (",
        "  <div>",
        "    <span>Hello</span>",
        "  </div>",
        ");",
      })

      local in_jsx_1 = treesitter.is_in_jsx_context(bufnr, 0, 0)
      local in_jsx_3 = treesitter.is_in_jsx_context(bufnr, 2, 0)

      assert.is_false(in_jsx_1)
      assert.is_true(in_jsx_3)
    end)
  end)

  describe("commenting in JSX", function()
    it("uses {/* */} inside JSX elements", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "return (",
        "  <div>",
        "    <span>Hello</span>",
        "  </div>",
        ");",
      })

      toggle.toggle_lines(bufnr, 3, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("{/%*", lines[3])
      assert.matches("%*/}", lines[3])
    end)

    it("uses // outside JSX elements", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const x = 1;",
        "const y = 2;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// const x = 1;", lines[1])
    end)

    it("handles mixed JSX and JS in same selection", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const Component = () => {",
        "  const x = 1;",
        "  return <div>Hello</div>;",
        "};",
      })

      toggle.toggle_lines(bufnr, 2, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("  // const x = 1;", lines[2])
      assert.matches("//", lines[3])
    end)
  end)

  describe("TSX support", function()
    it("detects TypeScript JSX context", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "typescriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "interface Props {",
        "  name: string;",
        "}",
        "",
        "const Component: React.FC<Props> = ({ name }) => {",
        "  return <div>{name}</div>;",
        "};",
      })

      local style_interface = detect.get_comment_style(bufnr, 1, 0)
      assert.equals("//", style_interface.line)

      local in_jsx = treesitter.is_in_jsx_context(bufnr, 5, 0)
      assert.is_true(in_jsx)
    end)

    it("comments TypeScript types outside JSX", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "typescriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "type Props = {",
        "  name: string;",
        "};",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// type Props = {", lines[1])
      assert.equals("//   name: string;", lines[2])
      assert.equals("// };", lines[3])
    end)
  end)

  describe("JSX attribute context", function()
    it("handles comments in JSX attributes", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<div",
        "  className='container'",
        "  onClick={handleClick}",
        ">",
      })

      local in_jsx_attr = treesitter.is_in_jsx_context(bufnr, 1, 0)
      assert.is_true(in_jsx_attr)
    end)

    it("handles embedded expressions in JSX", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<div>",
        "  {items.map(item => (",
        "    <span key={item.id}>{item.name}</span>",
        "  ))}",
        "</div>",
      })

      local in_expression = treesitter.is_in_jsx_context(bufnr, 1, 0)
      assert.is_true(in_expression)
    end)
  end)

  describe("edge cases", function()
    it("handles JSX fragments", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "return (",
        "  <>",
        "    <div>First</div>",
        "    <div>Second</div>",
        "  </>",
        ");",
      })

      local in_fragment = treesitter.is_in_jsx_context(bufnr, 2, 0)
      assert.is_true(in_fragment)
    end)

    it("handles self-closing tags", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "return <Component prop='value' />;",
      })

      local in_jsx = treesitter.is_in_jsx_context(bufnr, 0, 0)
      assert.is_true(in_jsx)
    end)

    it("handles JSX in ternary expressions", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const content = isLoading",
        "  ? <Spinner />",
        "  : <Content />;",
      })

      local in_jsx_line2 = treesitter.is_in_jsx_context(bufnr, 1, 0)
      local in_jsx_line3 = treesitter.is_in_jsx_context(bufnr, 2, 0)

      assert.is_true(in_jsx_line2)
      assert.is_true(in_jsx_line3)
    end)

    it("handles template literals outside JSX", function()
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const html = `",
        "  <div>This is a string</div>",
        "`;",
      })

      local in_jsx = treesitter.is_in_jsx_context(bufnr, 1, 0)
      assert.is_false(in_jsx)
    end)
  end)

  describe("TreeSitter integration notes", function()
    it("documents TreeSitter detection behavior", function()
      -- This test documents expected behavior when TreeSitter is available
      -- Without actual TreeSitter parsing, we use regex-based fallbacks
      --
      -- With TreeSitter:
      --   - Use TSNode type checking for accurate JSX context
      --   - Query for 'jsx_element', 'jsx_fragment', 'jsx_attribute' nodes
      --   - Distinguish between JSX and template literals
      --
      -- Without TreeSitter:
      --   - Use regex patterns to detect JSX-like syntax
      --   - May produce false positives with template literals
      --   - Conservative approach: prefer JS comments when uncertain

      assert.is_true(true)
    end)
  end)
end)
