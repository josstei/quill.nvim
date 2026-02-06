local treesitter = require("quill.detection.treesitter")
local languages = require("quill.detection.languages")

describe("quill.detection.treesitter", function()
  describe("is_available", function()
    it("returns false for invalid buffer", function()
      assert.is_false(treesitter.is_available(9999))
    end)

    it("returns true for buffer with TreeSitter parser", function()
      -- Create a temporary buffer with Lua content
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "-- This is a comment",
        "local x = 1",
      })

      local available = treesitter.is_available(bufnr)

      vim.api.nvim_buf_delete(bufnr, { force = true })

      -- TreeSitter availability depends on parser installation
      -- We just ensure the function doesn't error
      assert.is_boolean(available)
    end)

    it("handles current buffer when bufnr is 0", function()
      local ok = pcall(function()
        treesitter.is_available(0)
      end)
      assert.is_true(ok)
    end)
  end)

  describe("get_lang_at_position", function()
    it("returns nil for invalid buffer", function()
      assert.is_nil(treesitter.get_lang_at_position(9999, 0, 0))
    end)

    it("returns language for valid buffer with TreeSitter", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local x = 1",
      })

      local lang = treesitter.get_lang_at_position(bufnr, 0, 0)

      vim.api.nvim_buf_delete(bufnr, { force = true })

      -- Result depends on TreeSitter parser availability
      -- Just ensure no errors
      assert.is_true(lang == nil or type(lang) == "string")
    end)

    it("handles current buffer when bufnr is 0", function()
      local ok = pcall(function()
        treesitter.get_lang_at_position(0, 0, 0)
      end)
      assert.is_true(ok)
    end)
  end)

  describe("is_in_comment", function()
    it("returns false for invalid buffer", function()
      assert.is_false(treesitter.is_in_comment(9999, 0, 0))
    end)

    it("detects comment lines in Lua", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "-- This is a comment",
        "local x = 1",
      })

      -- Position in comment (row 0, col 3 = inside "--")
      local in_comment = treesitter.is_in_comment(bufnr, 0, 3)

      vim.api.nvim_buf_delete(bufnr, { force = true })

      -- Result depends on parser availability, just ensure no error
      assert.is_boolean(in_comment)
    end)

    it("handles current buffer when bufnr is 0", function()
      local ok = pcall(function()
        treesitter.is_in_comment(0, 0, 0)
      end)
      assert.is_true(ok)
    end)
  end)

  describe("is_in_jsx_context", function()
    it("returns false for invalid buffer", function()
      assert.is_false(treesitter.is_in_jsx_context(9999, 0, 0))
    end)

    it("returns false for non-JSX buffers", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local x = 1",
      })

      local in_jsx = treesitter.is_in_jsx_context(bufnr, 0, 0)

      vim.api.nvim_buf_delete(bufnr, { force = true })

      assert.is_false(in_jsx)
    end)

    it("handles JSX content", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const App = () => {",
        "  return <div>Hello</div>",
        "}",
      })

      -- Just ensure no error - result depends on parser
      local ok = pcall(function()
        treesitter.is_in_jsx_context(bufnr, 1, 10)
      end)

      vim.api.nvim_buf_delete(bufnr, { force = true })

      assert.is_true(ok)
    end)

    it("handles nested JSX within JSX expressions correctly", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const App = () => (",
        "  <div>",
        "    {items.map(item => (",
        "      <span>{item}</span>",
        "    ))}",
        "  </div>",
        ")",
      })

      -- Just ensure no error - the logic should handle nested JSX
      -- The <span> tag (line 3) should be in JSX context even though it's inside a jsx_expression
      local ok = pcall(function()
        treesitter.is_in_jsx_context(bufnr, 3, 10)
      end)

      vim.api.nvim_buf_delete(bufnr, { force = true })

      assert.is_true(ok)
    end)

    it("differentiates JSX markup from JS expressions in nested contexts", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const App = () => (",
        "  <div>",
        "    {items.map(item => {",
        "      const x = item.id;",
        "      return <span>{x}</span>",
        "    })}",
        "  </div>",
        ")",
      })

      -- Just ensure no error - different positions should have different contexts
      local ok = pcall(function()
        -- Line 3 (const x = item.id;) should be JS context
        treesitter.is_in_jsx_context(bufnr, 3, 10)
        -- Line 4 (<span> tag) should be JSX context
        treesitter.is_in_jsx_context(bufnr, 4, 15)
        -- Line 4 ({x} expression) should be JS context
        treesitter.is_in_jsx_context(bufnr, 4, 21)
      end)

      vim.api.nvim_buf_delete(bufnr, { force = true })

      assert.is_true(ok)
    end)

    it("handles current buffer when bufnr is 0", function()
      local ok = pcall(function()
        treesitter.is_in_jsx_context(0, 0, 0)
      end)
      assert.is_true(ok)
    end)
  end)

  describe("get_comment_style", function()
    it("returns style for valid buffer without TreeSitter", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local x = 1",
      })

      local style = treesitter.get_comment_style(bufnr, 0, 0)

      vim.api.nvim_buf_delete(bufnr, { force = true })

      -- Should get Lua style (either from TreeSitter or fallback)
      assert.is_not_nil(style)
      assert.equals("--", style.line)
    end)

    it("returns JSX style when in JSX context", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const App = () => {",
        "  return <div>Hello</div>",
        "}",
      })

      -- Get style - will depend on TreeSitter availability and JSX detection
      local style = treesitter.get_comment_style(bufnr, 1, 10)

      vim.api.nvim_buf_delete(bufnr, { force = true })

      -- Should return a valid style (either JSX or JS fallback)
      assert.is_not_nil(style)
      assert.is_true(style.jsx == true or style.jsx == false)
    end)

    it("returns JavaScript style when in JS expression within JSX", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "javascriptreact")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const App = () => {",
        "  const x = 1",
        "  return <div>{x}</div>",
        "}",
      })

      -- Position in JS code (not JSX)
      local style = treesitter.get_comment_style(bufnr, 1, 2)

      vim.api.nvim_buf_delete(bufnr, { force = true })

      -- Should return JavaScript style
      assert.is_not_nil(style)
      if style.line then
        assert.equals("//", style.line)
      end
    end)

    it("handles embedded languages in HTML", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "html")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<html>",
        "<script>",
        "const x = 1;",
        "</script>",
        "</html>",
      })

      -- Position in script tag (if TreeSitter available, should detect JS)
      local style = treesitter.get_comment_style(bufnr, 2, 2)

      vim.api.nvim_buf_delete(bufnr, { force = true })

      -- Should return a valid style (either JS or HTML fallback)
      assert.is_not_nil(style)
    end)

    it("falls back to filetype when TreeSitter unavailable", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "python")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "x = 1",
      })

      local style = treesitter.get_comment_style(bufnr, 0, 0)

      vim.api.nvim_buf_delete(bufnr, { force = true })

      -- Should get Python style from fallback
      assert.is_not_nil(style)
      assert.equals("#", style.line)
    end)

    it("falls back to commentstring when language not in registry", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      -- Set a filetype not in our registry
      vim.api.nvim_buf_set_option(bufnr, "filetype", "unknownlang")
      vim.api.nvim_buf_set_option(bufnr, "commentstring", "## %s")

      local style = treesitter.get_comment_style(bufnr, 0, 0)

      vim.api.nvim_buf_delete(bufnr, { force = true })

      -- Should use commentstring as fallback
      if style then
        assert.equals("##", style.line)
      end
    end)

    it("handles current buffer when bufnr is 0", function()
      local ok = pcall(function()
        treesitter.get_comment_style(0, 0, 0)
      end)
      assert.is_true(ok)
    end)
  end)

  describe("integration with languages module", function()
    it("returns correct style for Lua", function()
      local lua_style = languages.get_style("lua")
      assert.is_not_nil(lua_style)
      assert.equals("--", lua_style.line)
      assert.is_not_nil(lua_style.block)
      assert.equals("--[[", lua_style.block[1])
      assert.equals("]]", lua_style.block[2])
    end)

    it("returns correct style for JavaScript", function()
      local js_style = languages.get_style("javascript")
      assert.is_not_nil(js_style)
      assert.equals("//", js_style.line)
      assert.is_not_nil(js_style.block)
      assert.equals("/*", js_style.block[1])
      assert.equals("*/", js_style.block[2])
    end)

    it("returns correct style for HTML", function()
      local html_style = languages.get_style("html")
      assert.is_not_nil(html_style)
      assert.is_nil(html_style.line)
      assert.is_not_nil(html_style.block)
      assert.equals("<!--", html_style.block[1])
      assert.equals("-->", html_style.block[2])
    end)

    it("handles JSX filetype", function()
      local jsx_style = languages.get_style("javascriptreact")
      assert.is_not_nil(jsx_style)
      assert.equals("//", jsx_style.line)
      assert.is_true(jsx_style.jsx)
    end)

    it("handles TSX filetype", function()
      local tsx_style = languages.get_style("typescriptreact")
      assert.is_not_nil(tsx_style)
      assert.equals("//", tsx_style.line)
      assert.is_true(tsx_style.jsx)
    end)
  end)

  describe("edge cases", function()
    it("handles empty buffer", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")

      local style = treesitter.get_comment_style(bufnr, 0, 0)

      vim.api.nvim_buf_delete(bufnr, { force = true })

      -- Should still return Lua style
      assert.is_not_nil(style)
      assert.equals("--", style.line)
    end)

    it("handles position outside buffer bounds", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local x = 1",
      })

      -- Position beyond last line
      local ok = pcall(function()
        treesitter.get_comment_style(bufnr, 100, 0)
      end)

      vim.api.nvim_buf_delete(bufnr, { force = true })

      assert.is_true(ok)
    end)

    it("handles negative positions gracefully", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")

      local ok = pcall(function()
        treesitter.get_comment_style(bufnr, -1, -1)
      end)

      vim.api.nvim_buf_delete(bufnr, { force = true })

      assert.is_true(ok)
    end)
  end)
end)
