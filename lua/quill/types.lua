---Centralized type definitions for quill.nvim
---@module quill.types

---@class CommentStyle
---@field line string|nil Line comment marker (e.g., "//", "#", "--")
---@field block string[]|nil Block comment markers [start, end] (e.g., {"/*", "*/"})
---@field supports_nesting boolean|nil Whether block comments can nest
---@field jsx boolean|nil Whether this is JSX context

---@class CommentMarkers
---@field start_pos number Start position of comment marker (1-indexed)
---@field end_pos number End position of comment marker (1-indexed)
---@field marker_type "line"|"block" Type of comment marker

---@class DebugRegion
---@field start_line number Line of start marker (1-indexed)
---@field end_line number Line of end marker (1-indexed)
---@field is_commented boolean Whether content is currently commented

---@class FeatureResult
---@field success boolean Whether the operation succeeded
---@field count number Number of items affected
---@field error_msg string|nil Error message if failed

---@class BufferContext
---@field bufnr number Buffer number
---@field filetype string Buffer filetype
---@field line_count number Total lines in buffer
---@field is_valid boolean Whether buffer is valid

return {}
