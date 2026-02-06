local languages = require("quill.detection.languages")

describe("quill.detection.languages", function()
  describe("get_style", function()
    it("returns lua comment style", function()
      local style = languages.get_style("lua")
      assert.is_not_nil(style)
      assert.equals("--", style.line)
      assert.is_table(style.block)
      assert.equals("--[[", style.block[1])
      assert.equals("]]", style.block[2])
      assert.is_false(style.supports_nesting)
      assert.is_false(style.jsx)
    end)

    it("returns python comment style with docstrings", function()
      local style = languages.get_style("python")
      assert.is_not_nil(style)
      assert.equals("#", style.line)
      assert.is_table(style.block)
      assert.equals('"""', style.block[1])
      assert.equals('"""', style.block[2])
      assert.is_false(style.supports_nesting)
      assert.is_false(style.jsx)
    end)

    it("returns javascript comment style", function()
      local style = languages.get_style("javascript")
      assert.is_not_nil(style)
      assert.equals("//", style.line)
      assert.is_table(style.block)
      assert.equals("/*", style.block[1])
      assert.equals("*/", style.block[2])
      assert.is_false(style.supports_nesting)
      assert.is_false(style.jsx)
    end)

    it("returns jsx comment style with jsx flag", function()
      local style = languages.get_style("javascriptreact")
      assert.is_not_nil(style)
      assert.equals("//", style.line)
      assert.is_table(style.block)
      assert.equals("/*", style.block[1])
      assert.equals("*/", style.block[2])
      assert.is_false(style.supports_nesting)
      assert.is_true(style.jsx)
    end)

    it("returns tsx comment style with jsx flag", function()
      local style = languages.get_style("typescriptreact")
      assert.is_not_nil(style)
      assert.equals("//", style.line)
      assert.is_true(style.jsx)
    end)

    it("returns css comment style with no line comments", function()
      local style = languages.get_style("css")
      assert.is_not_nil(style)
      assert.is_nil(style.line)
      assert.is_table(style.block)
      assert.equals("/*", style.block[1])
      assert.equals("*/", style.block[2])
      assert.is_false(style.supports_nesting)
      assert.is_false(style.jsx)
    end)

    it("returns html comment style", function()
      local style = languages.get_style("html")
      assert.is_not_nil(style)
      assert.is_nil(style.line)
      assert.is_table(style.block)
      assert.equals("<!--", style.block[1])
      assert.equals("-->", style.block[2])
      assert.is_false(style.supports_nesting)
      assert.is_false(style.jsx)
    end)

    it("returns rust comment style with nesting support", function()
      local style = languages.get_style("rust")
      assert.is_not_nil(style)
      assert.equals("//", style.line)
      assert.is_table(style.block)
      assert.equals("/*", style.block[1])
      assert.equals("*/", style.block[2])
      assert.is_true(style.supports_nesting)
      assert.is_false(style.jsx)
    end)

    it("returns go comment style", function()
      local style = languages.get_style("go")
      assert.is_not_nil(style)
      assert.equals("//", style.line)
      assert.is_table(style.block)
      assert.equals("/*", style.block[1])
      assert.equals("*/", style.block[2])
      assert.is_false(style.supports_nesting)
    end)

    it("returns c comment style", function()
      local style = languages.get_style("c")
      assert.is_not_nil(style)
      assert.equals("//", style.line)
      assert.is_table(style.block)
    end)

    it("returns cpp comment style", function()
      local style = languages.get_style("cpp")
      assert.is_not_nil(style)
      assert.equals("//", style.line)
      assert.is_table(style.block)
    end)

    it("returns ruby comment style", function()
      local style = languages.get_style("ruby")
      assert.is_not_nil(style)
      assert.equals("#", style.line)
      assert.is_table(style.block)
      assert.equals("=begin", style.block[1])
      assert.equals("=end", style.block[2])
      assert.is_false(style.supports_nesting)
    end)

    it("returns bash comment style with no block comments", function()
      local style = languages.get_style("bash")
      assert.is_not_nil(style)
      assert.equals("#", style.line)
      assert.is_nil(style.block)
      assert.is_false(style.supports_nesting)
    end)

    it("returns sh comment style", function()
      local style = languages.get_style("sh")
      assert.is_not_nil(style)
      assert.equals("#", style.line)
      assert.is_nil(style.block)
    end)

    it("returns zsh comment style", function()
      local style = languages.get_style("zsh")
      assert.is_not_nil(style)
      assert.equals("#", style.line)
      assert.is_nil(style.block)
    end)

    it("returns sql comment style", function()
      local style = languages.get_style("sql")
      assert.is_not_nil(style)
      assert.equals("--", style.line)
      assert.is_table(style.block)
      assert.equals("/*", style.block[1])
      assert.equals("*/", style.block[2])
    end)

    it("returns vim comment style", function()
      local style = languages.get_style("vim")
      assert.is_not_nil(style)
      assert.equals('"', style.line)
      assert.is_nil(style.block)
    end)

    it("returns yaml comment style", function()
      local style = languages.get_style("yaml")
      assert.is_not_nil(style)
      assert.equals("#", style.line)
      assert.is_nil(style.block)
    end)

    it("returns toml comment style", function()
      local style = languages.get_style("toml")
      assert.is_not_nil(style)
      assert.equals("#", style.line)
      assert.is_nil(style.block)
    end)

    it("returns json comment style (no comments)", function()
      local style = languages.get_style("json")
      assert.is_not_nil(style)
      assert.is_nil(style.line)
      assert.is_nil(style.block)
    end)

    it("returns jsonc comment style", function()
      local style = languages.get_style("jsonc")
      assert.is_not_nil(style)
      assert.equals("//", style.line)
      assert.is_table(style.block)
    end)

    it("returns markdown comment style", function()
      local style = languages.get_style("markdown")
      assert.is_not_nil(style)
      assert.is_nil(style.line)
      assert.is_table(style.block)
      assert.equals("<!--", style.block[1])
      assert.equals("-->", style.block[2])
    end)

    it("returns haskell comment style with nesting support", function()
      local style = languages.get_style("haskell")
      assert.is_not_nil(style)
      assert.equals("--", style.line)
      assert.is_table(style.block)
      assert.equals("{-", style.block[1])
      assert.equals("-}", style.block[2])
      assert.is_true(style.supports_nesting)
    end)

    it("returns swift comment style with nesting support", function()
      local style = languages.get_style("swift")
      assert.is_not_nil(style)
      assert.equals("//", style.line)
      assert.is_table(style.block)
      assert.is_true(style.supports_nesting)
    end)

    it("returns nim comment style with nesting support", function()
      local style = languages.get_style("nim")
      assert.is_not_nil(style)
      assert.equals("#", style.line)
      assert.is_table(style.block)
      assert.equals("#[", style.block[1])
      assert.equals("]#", style.block[2])
      assert.is_true(style.supports_nesting)
    end)

    it("returns scheme comment style with nesting support", function()
      local style = languages.get_style("scheme")
      assert.is_not_nil(style)
      assert.equals(";", style.line)
      assert.is_table(style.block)
      assert.equals("#|", style.block[1])
      assert.equals("|#", style.block[2])
      assert.is_true(style.supports_nesting)
    end)

    it("returns nil for unknown filetype", function()
      local style = languages.get_style("unknownlang")
      assert.is_nil(style)
    end)

    it("returns nil for empty filetype", function()
      local style = languages.get_style("")
      assert.is_nil(style)
    end)
  end)

  describe("get_default", function()
    it("parses line comment from commentstring", function()
      -- Create a scratch buffer with custom commentstring
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].commentstring = "# %s"

      local style = languages.get_default(bufnr)

      assert.is_not_nil(style)
      assert.equals("#", style.line)
      assert.is_nil(style.block)
      assert.is_false(style.supports_nesting)
      assert.is_false(style.jsx)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("parses line comment with leading whitespace", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].commentstring = "  // %s"

      local style = languages.get_default(bufnr)

      assert.is_not_nil(style)
      assert.equals("//", style.line)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("parses line comment with trailing whitespace", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].commentstring = "-- %s  "

      local style = languages.get_default(bufnr)

      assert.is_not_nil(style)
      assert.equals("--", style.line)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("detects block comment from /*%s*/ pattern", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].commentstring = "/*%s*/"

      local style = languages.get_default(bufnr)

      assert.is_not_nil(style)
      assert.is_nil(style.line)
      assert.is_table(style.block)
      assert.equals("/*", style.block[1])
      assert.equals("*/", style.block[2])

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("detects block comment from <!--%s--> pattern", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].commentstring = "<!--%s-->"

      local style = languages.get_default(bufnr)

      assert.is_not_nil(style)
      assert.is_nil(style.line)
      assert.is_table(style.block)
      assert.equals("<!--", style.block[1])
      assert.equals("-->", style.block[2])

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("detects block comment from space-separated pair", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].commentstring = "{- %s -}"

      local style = languages.get_default(bufnr)

      assert.is_not_nil(style)
      assert.is_nil(style.line)
      assert.is_table(style.block)
      assert.equals("{-", style.block[1])
      assert.equals("-}", style.block[2])

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns nil for empty commentstring", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].commentstring = ""

      local style = languages.get_default(bufnr)

      assert.is_nil(style)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns nil for whitespace-only commentstring", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].commentstring = "   %s   "

      local style = languages.get_default(bufnr)

      assert.is_nil(style)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("uses current buffer when bufnr not provided", function()
      -- Set commentstring for current buffer
      vim.bo.commentstring = "// %s"

      local style = languages.get_default()

      assert.is_not_nil(style)
      assert.equals("//", style.line)
    end)
  end)

  describe("language coverage", function()
    it("has all required languages from spec", function()
      local required = {
        "lua",
        "python",
        "javascript",
        "typescript",
        "javascriptreact",
        "typescriptreact",
        "css",
        "html",
        "rust",
        "go",
        "c",
        "cpp",
        "ruby",
        "bash",
        "sh",
        "zsh",
        "sql",
        "vim",
        "yaml",
        "toml",
        "json",
        "markdown",
      }

      for _, ft in ipairs(required) do
        local style = languages.get_style(ft)
        assert.is_not_nil(style, "Missing required filetype: " .. ft)
      end
    end)

    it("jsx filetypes have jsx flag set correctly", function()
      local jsx_languages = { "javascriptreact", "typescriptreact" }

      for _, ft in ipairs(jsx_languages) do
        local style = languages.get_style(ft)
        assert.is_true(style.jsx, ft .. " should have jsx=true")
      end

      -- Non-JSX languages should have jsx=false
      local non_jsx = { "javascript", "typescript", "lua", "python" }

      for _, ft in ipairs(non_jsx) do
        local style = languages.get_style(ft)
        assert.is_false(style.jsx, ft .. " should have jsx=false")
      end
    end)

    it("nesting support is correctly set", function()
      local nesting_languages = {
        "rust",
        "haskell",
        "swift",
        "nim",
        "scheme",
        "racket",
        "lisp",
        "ocaml",
      }

      for _, ft in ipairs(nesting_languages) do
        local style = languages.get_style(ft)
        assert.is_not_nil(style, "Missing filetype: " .. ft)
        assert.is_true(style.supports_nesting, ft .. " should support nesting")
      end

      local no_nesting = { "javascript", "c", "cpp", "lua", "python" }

      for _, ft in ipairs(no_nesting) do
        local style = languages.get_style(ft)
        assert.is_false(style.supports_nesting, ft .. " should not support nesting")
      end
    end)
  end)

  describe("filetype aliases", function()
    it("resolves jsx alias to javascriptreact", function()
      local style = languages.get_style("jsx")
      assert.is_not_nil(style)
      assert.equals("//", style.line)
      assert.is_true(style.jsx)
    end)

    it("resolves tsx alias to typescriptreact", function()
      local style = languages.get_style("tsx")
      assert.is_not_nil(style)
      assert.equals("//", style.line)
      assert.is_true(style.jsx)
    end)

    it("resolves javascript.jsx alias to javascriptreact", function()
      local style = languages.get_style("javascript.jsx")
      assert.is_not_nil(style)
      assert.is_true(style.jsx)
    end)

    it("resolves typescript.tsx alias to typescriptreact", function()
      local style = languages.get_style("typescript.tsx")
      assert.is_not_nil(style)
      assert.is_true(style.jsx)
    end)

    it("returns same result for alias and canonical name", function()
      local jsx_style = languages.get_style("jsx")
      local react_style = languages.get_style("javascriptreact")

      assert.equals(jsx_style.line, react_style.line)
      assert.equals(jsx_style.jsx, react_style.jsx)
    end)
  end)

  describe("block comment validation", function()
    it("validates block comments have exactly 2 elements", function()
      local style = languages.get_style("lua")
      assert.is_table(style.block)
      assert.equals(2, #style.block)
    end)

    it("validates all languages with block comments", function()
      local all_filetypes = {
        "lua",
        "python",
        "javascript",
        "typescript",
        "javascriptreact",
        "typescriptreact",
        "css",
        "html",
        "rust",
        "go",
        "c",
        "cpp",
        "ruby",
        "bash",
        "sh",
        "zsh",
        "sql",
        "vim",
        "yaml",
        "toml",
        "json",
        "jsonc",
        "markdown",
        "java",
        "php",
        "haskell",
        "swift",
        "kotlin",
        "scala",
        "r",
        "perl",
        "elixir",
        "erlang",
        "clojure",
        "nim",
        "zig",
        "dart",
        "vue",
        "svelte",
        "graphql",
        "dockerfile",
        "makefile",
        "cmake",
        "terraform",
        "yaml.ansible",
        "scheme",
        "racket",
        "lisp",
        "ocaml",
        "fsharp",
      }

      for _, ft in ipairs(all_filetypes) do
        local style = languages.get_style(ft)
        if style and style.block then
          assert.equals(
            2,
            #style.block,
            string.format("%s block comments must have exactly 2 elements", ft)
          )
        end
      end
    end)
  end)
end)
