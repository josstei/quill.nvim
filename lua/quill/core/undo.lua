---Undo grouping for multi-line operations
---Ensures all changes in a comment operation can be undone with single 'u' press
---@module quill.core.undo

local M = {}

---Internal state tracking for manual undo groups
local undo_state = {
  in_group = false,
  level = 0,
}

---Execute a function within a single undo group
---All buffer modifications made by the function will be grouped as one undo operation
---Handles errors gracefully without breaking undo state
---@param fn function Function to execute within undo group
---@return any Result of fn() or nil if error occurred
---@return string|nil Error message if fn() failed
function M.with_undo_group(fn)
  if type(fn) ~= "function" then
    error("with_undo_group: argument must be a function")
  end

  -- Track state for consistency with manual API
  undo_state.level = undo_state.level + 1
  if undo_state.level == 1 then
    undo_state.in_group = true
  end

  -- Execute the function, capturing any errors
  local success, result = pcall(fn)

  -- Clean up state (always, even on error)
  undo_state.level = undo_state.level - 1
  if undo_state.level == 0 then
    undo_state.in_group = false
  end

  if not success then
    -- Function failed, return error
    -- Note: we don't need to "close" the undo group as it will be
    -- managed by Vim's normal undo system
    return nil, result
  end

  -- Return the result of the function
  return result, nil
end

---Begin an undo group manually
---Use this when callback style (with_undo_group) doesn't fit the use case
---IMPORTANT: Must be paired with end_undo_group() to maintain correct state
---Supports nesting - tracks depth internally
function M.start_undo_group()
  -- Increment nesting level
  undo_state.level = undo_state.level + 1

  -- Only join undo on the first level (outermost group)
  -- Nested groups are automatically part of the parent group
  if undo_state.level == 1 then
    undo_state.in_group = true
  end
end

---End an undo group manually
---Must be paired with start_undo_group()
---Handles mismatched calls gracefully
function M.end_undo_group()
  if undo_state.level <= 0 then
    -- Mismatched end_undo_group call (more ends than starts)
    -- Log warning but don't error
    vim.notify(
      "quill.undo: end_undo_group called without matching start_undo_group",
      vim.log.levels.WARN
    )
    return
  end

  -- Decrement nesting level
  undo_state.level = undo_state.level - 1

  -- Clear in_group flag when we exit all nesting levels
  if undo_state.level == 0 then
    undo_state.in_group = false
  end

  -- Note: No explicit "end" action needed for Vim's undo system
  -- The undo block automatically closes when the next non-joined change occurs
end

---Check if currently within a manual undo group
---Useful for debugging or conditional logic
---@return boolean True if in manual undo group
function M.is_in_group()
  return undo_state.in_group
end

---Reset undo group state
---For testing purposes or error recovery
---Should not be needed in normal operation
function M.reset_state()
  undo_state.in_group = false
  undo_state.level = 0
end

---Get current nesting level
---For debugging purposes
---@return number Current nesting depth
function M.get_level()
  return undo_state.level
end

return M
