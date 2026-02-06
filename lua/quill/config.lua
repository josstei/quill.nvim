local M = {}

local DEFAULTS = {
  align = {
    column = 80,
    min_gap = 2,
  },

  debug = {
    start_marker = "#region debug",
    end_marker = "#endregion",
  },

  keymaps = {
    operators = true,
    textobjects = true,
    leader = true,
  },

  mappings = {
    debug_buffer = "<leader>cd",
    debug_project = "<leader>cD",
    normalize = "<leader>cn",
    align = "<leader>ca",
  },

  operators = {
    toggle = "gc",
    toggle_line = nil,
  },

  textobjects = {
    inner_block = "ic",
    around_block = "ac",
    inner_line = "iC",
    around_line = "aC",
  },

  warn_on_override = true,

  languages = {},

  jsx = {
    auto_detect = true,
  },

  semantic = {
    include_decorators = true,
    include_doc_comments = true,
  },
}

---@class ValidationRule
---@field type string Expected type ("string", "number", "boolean", "table")
---@field required boolean|nil Whether field is required
---@field fields table<string, ValidationRule>|nil Nested field rules (for tables)

local VALIDATION_SCHEMA = {
  align = {
    type = "table",
    fields = {
      column = { type = "number" },
      min_gap = { type = "number" },
    },
  },
  debug = {
    type = "table",
    fields = {
      start_marker = { type = "string" },
      end_marker = { type = "string" },
    },
  },
  keymaps = {
    type = "table",
    fields = {
      operators = { type = "boolean" },
      textobjects = { type = "boolean" },
      leader = { type = "boolean" },
    },
  },
  mappings = {
    type = "table",
    fields = {
      debug_buffer = { type = "string" },
      debug_project = { type = "string" },
      normalize = { type = "string" },
      align = { type = "string" },
    },
  },
  operators = {
    type = "table",
    fields = {
      toggle = { type = "string" },
      toggle_line = { type = "string" },
    },
  },
  textobjects = {
    type = "table",
    fields = {
      inner_block = { type = "string" },
      around_block = { type = "string" },
      inner_line = { type = "string" },
      around_line = { type = "string" },
    },
  },
  warn_on_override = { type = "boolean" },
  languages = { type = "table" },
  jsx = {
    type = "table",
    fields = {
      auto_detect = { type = "boolean" },
    },
  },
  semantic = {
    type = "table",
    fields = {
      include_decorators = { type = "boolean" },
      include_doc_comments = { type = "boolean" },
    },
  },
}

---Validate a value against a schema rule
---@param value any Value to validate
---@param rule ValidationRule Schema rule
---@param path string Current path for error messages
---@return boolean valid
---@return string|nil error_msg
local function validate_rule(value, rule, path)
  if value == nil then
    return true, nil
  end

  if type(value) ~= rule.type then
    return false, string.format("%s: expected %s, got %s", path, rule.type, type(value))
  end

  if rule.type == "table" and rule.fields then
    for key, field_rule in pairs(rule.fields) do
      local ok, err = validate_rule(value[key], field_rule, path .. "." .. key)
      if not ok then
        return false, err
      end
    end
  end

  return true, nil
end

---Validate a single language override entry
---@param entry any Language definition to validate
---@param filetype string Filetype name for error messages
---@return boolean valid
---@return string|nil error_msg
local function validate_language_entry(entry, filetype)
  local path = "languages." .. filetype

  if type(entry) ~= "table" then
    return false, string.format("%s: expected table, got %s", path, type(entry))
  end

  if entry.line ~= nil and type(entry.line) ~= "string" then
    return false, string.format("%s.line: expected string, got %s", path, type(entry.line))
  end

  if entry.block ~= nil then
    if type(entry.block) ~= "table" or #entry.block ~= 2 then
      return false, string.format("%s.block: expected table with exactly 2 string elements", path)
    end
    if type(entry.block[1]) ~= "string" or type(entry.block[2]) ~= "string" then
      return false, string.format("%s.block: elements must be strings", path)
    end
  end

  if entry.supports_nesting ~= nil and type(entry.supports_nesting) ~= "boolean" then
    return false, string.format("%s.supports_nesting: expected boolean, got %s", path, type(entry.supports_nesting))
  end

  if entry.jsx ~= nil and type(entry.jsx) ~= "boolean" then
    return false, string.format("%s.jsx: expected boolean, got %s", path, type(entry.jsx))
  end

  return true, nil
end

local config = vim.deepcopy(DEFAULTS)

function M.setup(user_opts)
  user_opts = user_opts or {}

  if not M.validate(user_opts) then
    vim.notify("[quill] Invalid configuration provided", vim.log.levels.ERROR)
    return false
  end

  config = vim.tbl_deep_extend("force", DEFAULTS, user_opts)
  return true
end

function M.get()
  return config
end

function M.validate(opts)
  if type(opts) ~= "table" then
    return false
  end

  for key, rule in pairs(VALIDATION_SCHEMA) do
    local ok, err = validate_rule(opts[key], rule, key)
    if not ok then
      vim.notify("[quill] Config error: " .. err, vim.log.levels.ERROR)
      return false
    end
  end

  if opts.languages and type(opts.languages) == "table" then
    for filetype, entry in pairs(opts.languages) do
      local ok, err = validate_language_entry(entry, tostring(filetype))
      if not ok then
        vim.notify("[quill] Config error: " .. err, vim.log.levels.ERROR)
        return false
      end
    end
  end

  return true
end

return M
