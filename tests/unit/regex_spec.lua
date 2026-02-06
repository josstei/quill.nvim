local regex = require("quill.detection.regex")
local languages = require("quill.detection.languages")

describe("quill.detection.regex", function()
  describe("is_commented", function()
    describe("line comments", function()
      local lua_style = languages.get_style("lua")
      local js_style = languages.get_style("javascript")
      local python_style = languages.get_style("python")

      it("detects basic line comment", function()
        assert.is_true(regex.is_commented("-- This is a comment", lua_style))
        assert.is_true(regex.is_commented("// This is a comment", js_style))
        assert.is_true(regex.is_commented("# This is a comment", python_style))
      end)

      it("detects line comment with leading whitespace", function()
        assert.is_true(regex.is_commented("  -- Indented comment", lua_style))
        assert.is_true(regex.is_commented("\t// Tab indented", js_style))
        assert.is_true(regex.is_commented("    # Four spaces", python_style))
      end)

      it("detects line comment without space after marker", function()
        assert.is_true(regex.is_commented("--No space", lua_style))
        assert.is_true(regex.is_commented("//No space", js_style))
        assert.is_true(regex.is_commented("#No space", python_style))
      end)

      it("detects line comment with multiple spaces after marker", function()
        assert.is_true(regex.is_commented("--  Multiple spaces", lua_style))
        assert.is_true(regex.is_commented("//   Three spaces", js_style))
      end)

      it("does not detect uncommented line", function()
        assert.is_false(regex.is_commented("local x = 1", lua_style))
        assert.is_false(regex.is_commented("const x = 1;", js_style))
        assert.is_false(regex.is_commented("x = 1", python_style))
      end)

      it("does not detect comment marker inside string", function()
        assert.is_false(regex.is_commented('local x = "-- not a comment"', lua_style))
        assert.is_false(regex.is_commented("const x = '// not a comment';", js_style))
        assert.is_false(regex.is_commented('x = "# not a comment"', python_style))
      end)

      it("handles empty lines", function()
        assert.is_false(regex.is_commented("", lua_style))
        assert.is_false(regex.is_commented("", js_style))
      end)

      it("handles whitespace-only lines", function()
        assert.is_false(regex.is_commented("   ", lua_style))
        assert.is_false(regex.is_commented("\t\t", js_style))
      end)

      it("detects comment on line with code after marker", function()
        assert.is_true(regex.is_commented("-- comment = value", lua_style))
        assert.is_true(regex.is_commented("// x = y", js_style))
      end)

      it("handles comment marker at start with escaped quotes in content", function()
        assert.is_true(regex.is_commented('-- This has \\" escaped quotes', lua_style))
        assert.is_true(regex.is_commented("// This has \\' escaped quotes", js_style))
      end)
    end)

    describe("block comments", function()
      local js_style = languages.get_style("javascript")
      local lua_style = languages.get_style("lua")
      local html_style = languages.get_style("html")

      it("detects basic block comment", function()
        assert.is_true(regex.is_commented("/* This is a comment */", js_style))
        assert.is_true(regex.is_commented("--[[ This is a comment ]]", lua_style))
        assert.is_true(regex.is_commented("<!-- This is a comment -->", html_style))
      end)

      it("detects block comment with leading whitespace", function()
        assert.is_true(regex.is_commented("  /* Indented comment */", js_style))
        assert.is_true(regex.is_commented("\t--[[ Tab indented ]]", lua_style))
      end)

      it("detects block comment with trailing whitespace", function()
        assert.is_true(regex.is_commented("/* Comment */  ", js_style))
        assert.is_true(regex.is_commented("--[[ Comment ]]  ", lua_style))
      end)

      it("detects block comment with content containing special chars", function()
        assert.is_true(regex.is_commented("/* foo = bar; x + y */", js_style))
        assert.is_true(regex.is_commented("--[[ local x = { a, b } ]]", lua_style))
      end)

      it("does not detect incomplete block comment", function()
        assert.is_false(regex.is_commented("/* Missing end marker", js_style))
        assert.is_false(regex.is_commented("Missing start marker */", js_style))
      end)

      it("does not detect block markers inside strings", function()
        assert.is_false(regex.is_commented('x = "/* not a comment */"', js_style))
        assert.is_false(regex.is_commented("x = '<!-- not a comment -->'", html_style))
      end)

      it("detects empty block comment", function()
        assert.is_true(regex.is_commented("/**/", js_style))
        assert.is_true(regex.is_commented("--[[]]", lua_style))
        assert.is_true(regex.is_commented("<!---->", html_style))
      end)

      it("handles multiline-style block comment on single line", function()
        assert.is_true(regex.is_commented("/* Line 1\nLine 2 */", js_style))
      end)
    end)

    describe("mixed markers", function()
      local js_style = languages.get_style("javascript")

      it("prefers line comment over block comment", function()
        -- If line starts with line comment, it's commented
        assert.is_true(regex.is_commented("// /* not block */", js_style))
      end)

      it("detects block comment when no line comment at start", function()
        -- Block comment must be complete and at start/end of line
        assert.is_true(regex.is_commented("/* block comment */", js_style))
        -- With other content after block end, it's not considered a commented line
        assert.is_false(regex.is_commented("/* block */ // line", js_style))
      end)
    end)

    describe("edge cases", function()
      local js_style = languages.get_style("javascript")
      local vim_style = languages.get_style("vim")

      it("handles special quote character as comment marker (Vim)", function()
        assert.is_true(regex.is_commented('" This is a Vim comment', vim_style))
      end)

      it("handles escaped backslashes before quotes", function()
        assert.is_false(regex.is_commented('x = "\\\\" // comment', js_style))
      end)

      it("handles alternating quotes", function()
        assert.is_false(regex.is_commented([[x = "'" + "// not comment" + '"']], js_style))
      end)

      it("handles comment marker immediately after quote close", function()
        assert.is_false(regex.is_commented('x = ""// not at start', js_style))
      end)
    end)
  end)

  describe("get_comment_markers", function()
    describe("line comments", function()
      local lua_style = languages.get_style("lua")
      local js_style = languages.get_style("javascript")

      it("returns correct position for line comment", function()
        local markers = regex.get_comment_markers("-- comment", lua_style)
        assert.is_not_nil(markers)
        assert.equals(1, markers.start_pos)
        assert.equals(2, markers.end_pos)
        assert.equals("line", markers.marker_type)
      end)

      it("returns correct position for indented line comment", function()
        local markers = regex.get_comment_markers("  // comment", js_style)
        assert.is_not_nil(markers)
        assert.equals(3, markers.start_pos)
        assert.equals(4, markers.end_pos)
        assert.equals("line", markers.marker_type)
      end)

      it("handles tab indentation", function()
        local markers = regex.get_comment_markers("\t-- comment", lua_style)
        assert.is_not_nil(markers)
        assert.equals(2, markers.start_pos)
        assert.equals(3, markers.end_pos)
        assert.equals("line", markers.marker_type)
      end)

      it("returns nil for non-commented line", function()
        local markers = regex.get_comment_markers("local x = 1", lua_style)
        assert.is_nil(markers)
      end)

      it("returns nil when marker is inside string", function()
        local markers = regex.get_comment_markers('x = "-- comment"', lua_style)
        assert.is_nil(markers)
      end)
    end)

    describe("block comments", function()
      local js_style = languages.get_style("javascript")
      local lua_style = languages.get_style("lua")

      it("returns correct positions for block comment", function()
        local markers = regex.get_comment_markers("/* comment */", js_style)
        assert.is_not_nil(markers)
        assert.equals(1, markers.start_pos)
        assert.equals(13, markers.end_pos) -- End of "*/" at position 13
        assert.equals("block", markers.marker_type)
      end)

      it("returns correct positions for indented block comment", function()
        local line = "  --[[ comment ]]"
        local markers = regex.get_comment_markers(line, lua_style)
        assert.is_not_nil(markers)
        assert.equals(3, markers.start_pos) -- Start of "--[["
        assert.equals(#line, markers.end_pos) -- End of "]]"
        assert.equals("block", markers.marker_type)
      end)

      it("returns nil for incomplete block comment", function()
        local markers = regex.get_comment_markers("/* missing end", js_style)
        assert.is_nil(markers)
      end)

      it("returns nil when block markers inside string", function()
        local markers = regex.get_comment_markers('x = "/* comment */"', js_style)
        assert.is_nil(markers)
      end)
    end)

    describe("priority", function()
      local js_style = languages.get_style("javascript")

      it("prefers line comment when both present", function()
        local markers = regex.get_comment_markers("// /* block */", js_style)
        assert.is_not_nil(markers)
        assert.equals("line", markers.marker_type)
      end)
    end)
  end)

  describe("strip_comment", function()
    describe("line comments", function()
      local lua_style = languages.get_style("lua")
      local js_style = languages.get_style("javascript")
      local python_style = languages.get_style("python")

      it("removes basic line comment", function()
        assert.equals("This is content", regex.strip_comment("-- This is content", lua_style))
        assert.equals("This is content", regex.strip_comment("// This is content", js_style))
        assert.equals("This is content", regex.strip_comment("# This is content", python_style))
      end)

      it("preserves indentation when removing comment", function()
        assert.equals("  This is content", regex.strip_comment("  -- This is content", lua_style))
        assert.equals("    This is content", regex.strip_comment("    // This is content", js_style))
        assert.equals("\tThis is content", regex.strip_comment("\t# This is content", python_style))
      end)

      it("removes comment without space after marker", function()
        assert.equals("No space", regex.strip_comment("--No space", lua_style))
        assert.equals("No space", regex.strip_comment("//No space", js_style))
      end)

      it("handles comment with multiple spaces after marker", function()
        assert.equals(" Multiple spaces", regex.strip_comment("--  Multiple spaces", lua_style))
        assert.equals("  Three spaces", regex.strip_comment("//   Three spaces", js_style))
      end)

      it("returns original line if not commented", function()
        assert.equals("local x = 1", regex.strip_comment("local x = 1", lua_style))
        assert.equals("const x = 1;", regex.strip_comment("const x = 1;", js_style))
      end)

      it("preserves empty line", function()
        assert.equals("", regex.strip_comment("", lua_style))
      end)

      it("preserves indentation for whitespace-only lines", function()
        assert.equals("  ", regex.strip_comment("  ", lua_style))
      end)

      it("handles marker inside string", function()
        local line = 'x = "-- not a comment"'
        assert.equals(line, regex.strip_comment(line, lua_style))
      end)

      it("removes comment from line with empty content", function()
        assert.equals("", regex.strip_comment("--", lua_style))
        assert.equals("  ", regex.strip_comment("  //", js_style))
      end)
    end)

    describe("block comments", function()
      local js_style = languages.get_style("javascript")
      local lua_style = languages.get_style("lua")
      local html_style = languages.get_style("html")

      it("removes basic block comment", function()
        assert.equals("This is content", regex.strip_comment("/* This is content */", js_style))
        assert.equals("This is content", regex.strip_comment("--[[ This is content ]]", lua_style))
        assert.equals(
          "This is content",
          regex.strip_comment("<!-- This is content -->", html_style)
        )
      end)

      it("preserves indentation when removing block comment", function()
        assert.equals("  This is content", regex.strip_comment("  /* This is content */", js_style))
        assert.equals(
          "\tThis is content",
          regex.strip_comment("\t--[[ This is content ]]", lua_style)
        )
      end)

      it("removes empty block comment", function()
        assert.equals("", regex.strip_comment("/**/", js_style))
        assert.equals("", regex.strip_comment("--[[]]", lua_style))
        assert.equals("", regex.strip_comment("<!---->", html_style))
      end)

      it("preserves indentation for empty block comment", function()
        assert.equals("  ", regex.strip_comment("  /**/", js_style))
      end)

      it("handles block comment with special chars in content", function()
        assert.equals(
          "foo = bar; x + y",
          regex.strip_comment("/* foo = bar; x + y */", js_style)
        )
      end)

      it("returns original for incomplete block comment", function()
        local line = "/* Missing end"
        assert.equals(line, regex.strip_comment(line, js_style))
      end)

      it("handles block markers inside string", function()
        local line = 'x = "/* not a comment */"'
        assert.equals(line, regex.strip_comment(line, js_style))
      end)
    end)

    describe("edge cases", function()
      local js_style = languages.get_style("javascript")

      it("handles nil line", function()
        assert.is_nil(regex.strip_comment(nil, js_style))
      end)

      it("strips single space after line marker only", function()
        assert.equals("content", regex.strip_comment("// content", js_style))
        assert.equals(" content", regex.strip_comment("//  content", js_style))
      end)

      it("strips single space around block markers only", function()
        assert.equals("content", regex.strip_comment("/* content */", js_style))
        assert.equals(" content ", regex.strip_comment("/*  content  */", js_style))
      end)
    end)
  end)

  describe("add_comment", function()
    describe("line comments", function()
      local lua_style = languages.get_style("lua")
      local js_style = languages.get_style("javascript")

      it("adds line comment to basic line", function()
        assert.equals("-- This is content", regex.add_comment("This is content", lua_style))
        assert.equals("// This is content", regex.add_comment("This is content", js_style))
      end)

      it("preserves indentation when adding comment", function()
        assert.equals("  -- This is content", regex.add_comment("  This is content", lua_style))
        assert.equals("    // This is content", regex.add_comment("    This is content", js_style))
        assert.equals("\t-- This is content", regex.add_comment("\tThis is content", lua_style))
      end)

      it("adds comment to empty line", function()
        assert.equals("--", regex.add_comment("", lua_style))
        assert.equals("//", regex.add_comment("", js_style))
      end)

      it("preserves indentation for whitespace-only line", function()
        assert.equals("  --", regex.add_comment("  ", lua_style))
        assert.equals("    //", regex.add_comment("    ", js_style))
      end)

      it("handles nil line", function()
        assert.is_nil(regex.add_comment(nil, lua_style))
      end)

      it("adds space after line marker", function()
        local result = regex.add_comment("content", js_style)
        assert.equals("// content", result)
      end)
    end)

    describe("block comments", function()
      local js_style = languages.get_style("javascript")
      local html_style = languages.get_style("html")

      it("adds block comment when use_block is true", function()
        assert.equals("/* This is content */", regex.add_comment("This is content", js_style, true))
        assert.equals(
          "<!-- This is content -->",
          regex.add_comment("This is content", html_style, true)
        )
      end)

      it("preserves indentation with block comment", function()
        assert.equals(
          "  /* This is content */",
          regex.add_comment("  This is content", js_style, true)
        )
        assert.equals(
          "\t<!-- This is content -->",
          regex.add_comment("\tThis is content", html_style, true)
        )
      end)

      it("adds empty block comment to empty line", function()
        assert.equals("/* */", regex.add_comment("", js_style, true))
        assert.equals("<!-- -->", regex.add_comment("", html_style, true))
      end)

      it("adds space around block markers", function()
        local result = regex.add_comment("content", js_style, true)
        assert.equals("/* content */", result)
      end)
    end)

    describe("fallback behavior", function()
      local html_style = languages.get_style("html")
      local bash_style = languages.get_style("bash")

      it("uses block comment when line comment not available", function()
        -- HTML has no line comment, should use block
        assert.equals("<!-- content -->", regex.add_comment("content", html_style))
      end)

      it("returns original when no comment style available", function()
        local no_comment_style = {
          line = nil,
          block = nil,
          supports_nesting = false,
          jsx = false,
        }
        assert.equals("content", regex.add_comment("content", no_comment_style))
      end)

      it("prefers line comment over block by default", function()
        -- JavaScript has both, should prefer line
        local js_style = languages.get_style("javascript")
        local result = regex.add_comment("content", js_style)
        assert.equals("// content", result)
      end)

      it("uses line comment when use_block is false and block not available", function()
        assert.equals("# content", regex.add_comment("content", bash_style, false))
      end)
    end)

    describe("roundtrip", function()
      local js_style = languages.get_style("javascript")
      local lua_style = languages.get_style("lua")

      it("add_comment and strip_comment are inverses for line comments", function()
        local original = "  local x = 1"
        local commented = regex.add_comment(original, lua_style)
        local stripped = regex.strip_comment(commented, lua_style)
        assert.equals(original, stripped)
      end)

      it("add_comment and strip_comment are inverses for block comments", function()
        local original = "  const x = 1;"
        local commented = regex.add_comment(original, js_style, true)
        local stripped = regex.strip_comment(commented, js_style)
        assert.equals(original, stripped)
      end)

      it("handles multiple roundtrips", function()
        local original = "content"
        local step1 = regex.add_comment(original, js_style)
        local step2 = regex.strip_comment(step1, js_style)
        local step3 = regex.add_comment(step2, js_style)
        local step4 = regex.strip_comment(step3, js_style)
        assert.equals(original, step4)
      end)
    end)
  end)

  describe("integration with languages", function()
    it("works with all language styles", function()
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

        if style and (style.line or style.block) then
          local test_line = "test content"

          local commented = regex.add_comment(test_line, style)
          assert.is_string(commented)
          assert.is_true(#commented > #test_line, ft .. " should add comment marker")

          assert.is_true(regex.is_commented(commented, style), ft .. " should detect comment")

          local stripped = regex.strip_comment(commented, style)
          assert.equals(test_line, stripped, ft .. " should strip comment correctly")
        end
      end
    end)

    it("handles indented content for all languages", function()
      local test_cases = {
        { ft = "lua", content = "  local x = 1" },
        { ft = "javascript", content = "    const x = 1;" },
        { ft = "python", content = "\tx = 1" },
        { ft = "rust", content = "  let x = 1;" },
        { ft = "html", content = "  <div></div>" },
      }

      for _, tc in ipairs(test_cases) do
        local style = languages.get_style(tc.ft)
        local commented = regex.add_comment(tc.content, style)
        local stripped = regex.strip_comment(commented, style)
        assert.equals(tc.content, stripped, tc.ft .. " should preserve indentation")
      end
    end)
  end)
end)
