local describe = require("plenary.busted").describe
local it = require("plenary.busted").it
local assert = require("plenary.busted").assert
local before_each = require("plenary.busted").before_each
local after_each = require("plenary.busted").after_each

describe("TypeScript language support", function()
  local toggle = require("quill.core.toggle")
  local detect = require("quill.core.detect")
  local semantic = require("quill.features.semantic")
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, "filetype", "typescript")
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
  end)

  describe("line comment toggle", function()
    it("comments TypeScript code", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const x: number = 1;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// const x: number = 1;", lines[1])
    end)

    it("uncomments TypeScript code", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "// const x: number = 1;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("const x: number = 1;", lines[1])
    end)
  end)

  describe("TSDoc comments", function()
    it("finds TSDoc comment block", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/**",
        " * Calculate sum of two numbers",
        " * @param a - First number",
        " * @param b - Second number",
        " * @returns Sum of a and b",
        " */",
        "function sum(a: number, b: number): number {",
        "  return a + b;",
        "}",
      })

      local doc = semantic.find_doc_comment(bufnr, 7)
      assert.is_not_nil(doc)
      assert.equals(1, doc.start_line)
      assert.equals(6, doc.end_line)
    end)

    it("recognizes TypeScript-specific tags", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "/**",
        " * @template T - Generic type parameter",
        " * @typeParam K - Key type",
        " */",
        "function getValue<T, K extends keyof T>(obj: T, key: K): T[K] {",
        "  return obj[key];",
        "}",
      })

      local doc = semantic.find_doc_comment(bufnr, 5)
      assert.is_not_nil(doc)
    end)
  end)

  describe("TypeScript-specific syntax", function()
    it("comments type annotations", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const name: string = 'John';",
        "const age: number = 30;",
        "const isActive: boolean = true;",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// const name: string = 'John';", lines[1])
      assert.equals("// const age: number = 30;", lines[2])
      assert.equals("// const isActive: boolean = true;", lines[3])
    end)

    it("comments interface definitions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "interface User {",
        "  id: number;",
        "  name: string;",
        "  email?: string;",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// interface User {", lines[1])
      assert.equals("//   id: number;", lines[2])
      assert.equals("//   name: string;", lines[3])
      assert.equals("//   email?: string;", lines[4])
      assert.equals("// }", lines[5])
    end)

    it("comments type aliases", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "type ID = string | number;",
        "type UserRole = 'admin' | 'user' | 'guest';",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// type ID = string | number;", lines[1])
      assert.equals("// type UserRole = 'admin' | 'user' | 'guest';", lines[2])
    end)

    it("comments generics", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "function identity<T>(arg: T): T {",
        "  return arg;",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// function identity<T>(arg: T): T {", lines[1])
      assert.equals("//   return arg;", lines[2])
      assert.equals("// }", lines[3])
    end)

    it("comments enum definitions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "enum Direction {",
        "  Up = 'UP',",
        "  Down = 'DOWN',",
        "  Left = 'LEFT',",
        "  Right = 'RIGHT'",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 6)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// enum Direction {", lines[1])
      assert.equals("//   Up = 'UP',", lines[2])
    end)

    it("comments namespace declarations", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "namespace Utils {",
        "  export function parse(input: string): number {",
        "    return parseInt(input);",
        "  }",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// namespace Utils {", lines[1])
    end)

    it("comments decorators", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@Component({",
        "  selector: 'app-root',",
        "  templateUrl: './app.component.html'",
        "})",
        "export class AppComponent {}",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// @Component({", lines[1])
      assert.equals("//   selector: 'app-root',", lines[2])
    end)

    it("finds attached decorators", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@Injectable()",
        "@Component({",
        "  selector: 'app-root'",
        "})",
        "export class AppComponent {",
        "  constructor() {}",
        "}",
      })

      local decorators = semantic.find_attached_decorators(bufnr, 5)
      assert.is_true(#decorators > 0)
    end)

    it("comments utility types", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "type Partial<T> = { [P in keyof T]?: T[P] };",
        "type ReadonlyUser = Readonly<User>;",
        "type UserKeys = keyof User;",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^// type Partial", lines[1])
      assert.matches("^// type ReadonlyUser", lines[2])
      assert.matches("^// type UserKeys", lines[3])
    end)

    it("comments conditional types", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "type NonNullable<T> = T extends null | undefined ? never : T;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^// type NonNullable", lines[1])
    end)

    it("comments mapped types", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "type Optional<T> = {",
        "  [K in keyof T]?: T[K]",
        "};",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// type Optional<T> = {", lines[1])
      assert.equals("//   [K in keyof T]?: T[K]", lines[2])
      assert.equals("// };", lines[3])
    end)
  end)

  describe("advanced features", function()
    it("comments type guards", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "function isString(value: unknown): value is string {",
        "  return typeof value === 'string';",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^// function isString", lines[1])
    end)

    it("comments assertion functions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "function assert(condition: unknown): asserts condition {",
        "  if (!condition) throw new Error('Assertion failed');",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^// function assert", lines[1])
    end)

    it("comments module augmentation", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "declare module 'express' {",
        "  interface Request {",
        "    user?: User;",
        "  }",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// declare module 'express' {", lines[1])
      assert.equals("//   interface Request {", lines[2])
    end)

    it("comments ambient declarations", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "declare global {",
        "  interface Window {",
        "    myApp: MyApp;",
        "  }",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// declare global {", lines[1])
    end)
  end)

  describe("edge cases", function()
    it("handles complex generic constraints", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "function merge<T extends object, U extends object>(a: T, b: U): T & U {",
        "  return { ...a, ...b };",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 3)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^// function merge", lines[1])
    end)

    it("handles tuple types", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "type Point = [number, number];",
        "type RGB = [number, number, number];",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// type Point = [number, number];", lines[1])
      assert.equals("// type RGB = [number, number, number];", lines[2])
    end)

    it("handles intersection and union types", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "type Admin = User & { role: 'admin' };",
        "type StringOrNumber = string | number;",
      })

      toggle.toggle_lines(bufnr, 1, 2)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^// type Admin", lines[1])
      assert.matches("^// type StringOrNumber", lines[2])
    end)

    it("handles template literal types", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "type EventName = `on${Capitalize<string>}`;",
      })

      toggle.toggle_lines(bufnr, 1, 1)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.matches("^// type EventName", lines[1])
    end)
  end)

  describe("framework patterns", function()
    it("comments Angular components", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "@Component({",
        "  selector: 'app-user',",
        "  templateUrl: './user.component.html'",
        "})",
        "export class UserComponent implements OnInit {",
        "  ngOnInit(): void {}",
        "}",
      })

      toggle.toggle_lines(bufnr, 1, 7)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// @Component({", lines[1])
    end)

    it("comments React type definitions", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "interface Props {",
        "  name: string;",
        "  onClick: (e: MouseEvent) => void;",
        "}",
        "",
        "const MyComponent: React.FC<Props> = ({ name, onClick }) => {",
        "  return <div onClick={onClick}>{name}</div>;",
        "};",
      })

      toggle.toggle_lines(bufnr, 1, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("// interface Props {", lines[1])
      assert.equals("//   name: string;", lines[2])
    end)
  end)

  describe("indentation", function()
    it("preserves indentation with complex types", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "  interface Config {",
        "    options: {",
        "      nested: boolean;",
        "    };",
        "  }",
      })

      toggle.toggle_lines(bufnr, 1, 5)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("  // interface Config {", lines[1])
      assert.equals("    // options: {", lines[2])
      assert.equals("      // nested: boolean;", lines[3])
      assert.equals("    // };", lines[4])
      assert.equals("  // }", lines[5])
    end)
  end)
end)
