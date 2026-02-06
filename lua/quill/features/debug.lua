---Debug region handling for toggling #region debug blocks
---Finds and toggles debug regions across buffers and projects
---@module quill.features.debug

local toggle = require("quill.core.toggle")
local detect = require("quill.core.detect")
local undo = require("quill.core.undo")
local utils = require("quill.utils")

local M = {}

---Configuration for debug region markers
---@class DebugConfig
---@field start_marker string Pattern for region start (default: "#region debug")
---@field end_marker string Pattern for region end (default: "#endregion")

---Default configuration
---@type DebugConfig
local config = {
  start_marker = "#region debug",
  end_marker = "#endregion",
}

---Debug region structure
---@class DebugRegion
---@field start_line number Line of start marker (1-indexed)
---@field end_line number Line of end marker (1-indexed)
---@field is_commented boolean Whether content is currently commented

---Find all debug regions in buffer
---@param bufnr number Buffer number (0 for current)
---@return DebugRegion[] regions List of debug regions
function M.find_debug_regions(bufnr)
  local ctx = utils.get_buffer_context(bufnr)
  if not ctx then
    return {}
  end
  bufnr = ctx.bufnr

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local regions = {}

  local i = 1
  while i <= #lines do
    local line = lines[i]

    if line:find(config.start_marker, 1, true) then
      local start_line = i

      local j = i + 1
      while j <= #lines do
        local end_line_content = lines[j]
        if end_line_content:find(config.end_marker, 1, true) then
          -- Found end marker, check if content is commented
          local is_commented = M.is_region_commented(bufnr, start_line, j)

          table.insert(regions, {
            start_line = start_line,
            end_line = j,
            is_commented = is_commented,
          })

          -- Move past this region
          i = j
          break
        end
        j = j + 1
      end

      -- If we didn't find an end marker, region is malformed
      -- Skip this start marker and continue
    end

    i = i + 1
  end

  return regions
end

---Check if a debug region's content is commented
---Analyzes lines between markers (exclusive) to determine state
---@param bufnr number Buffer number
---@param start_line number Start marker line (1-indexed)
---@param end_line number End marker line (1-indexed)
---@return boolean True if majority of content lines are commented
function M.is_region_commented(bufnr, start_line, end_line)
  -- Check content lines between markers (exclusive)
  if end_line - start_line <= 1 then
    -- Empty region (no content between markers)
    return false
  end

  local content_start = start_line + 1
  local content_end = end_line - 1

  -- Use toggle.analyze_lines to determine state
  local state, err = toggle.analyze_lines(bufnr, content_start, content_end)

  if err or not state then
    return false
  end

  -- Consider region commented if all or most lines are commented
  return state == "all_commented" or state == "mixed"
end

---Toggle a single debug region
---Comments or uncomments content lines between markers
---@param bufnr number Buffer number
---@param region DebugRegion Region to toggle
---@return boolean success Whether toggle was successful
function M.toggle_region(bufnr, region)
  bufnr = bufnr or 0

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  -- Calculate content range (exclude marker lines)
  local content_start = region.start_line + 1
  local content_end = region.end_line - 1

  -- Empty region (no content to toggle)
  if content_end < content_start then
    return true
  end

  -- Determine operation: if currently commented, uncomment; otherwise, comment
  local should_uncomment = region.is_commented

  -- Toggle the content lines
  local success, err = toggle.toggle_lines(bufnr, content_start, content_end, {
    force_comment = not should_uncomment,
    force_uncomment = should_uncomment,
  })

  return success and not err
end

---Toggle all debug regions in current buffer
---Determines majority state and toggles all regions uniformly
---@return number count Number of regions toggled
function M.toggle_buffer()
  local bufnr = 0
  local regions = M.find_debug_regions(bufnr)

  if #regions == 0 then
    vim.notify("No debug regions found in buffer", vim.log.levels.INFO)
    return 0
  end

  -- Determine majority state
  local commented_count = 0
  for _, region in ipairs(regions) do
    if region.is_commented then
      commented_count = commented_count + 1
    end
  end

  -- If most regions are commented, uncomment all; otherwise, comment all
  local should_uncomment = commented_count >= (#regions / 2)

  -- Toggle all regions in a single undo group
  local count = 0
  local result, err = undo.with_undo_group(function()
    for _, region in ipairs(regions) do
      -- Update region state to match desired operation
      local region_for_toggle = {
        start_line = region.start_line,
        end_line = region.end_line,
        is_commented = should_uncomment, -- Set to desired operation
      }

      if M.toggle_region(bufnr, region_for_toggle) then
        count = count + 1
      end
    end
    return count
  end)

  if err then
    vim.notify("Error toggling regions: " .. err, vim.log.levels.ERROR)
    return 0
  end

  local action = should_uncomment and "Uncommented" or "Commented"
  vim.notify(string.format("%s %d debug region(s)", action, count), vim.log.levels.INFO)

  return result or count
end

local MAX_GLOB_FILES = 10000
local MAX_FILE_SIZE_BYTES = 1048576

local EXCLUDED_DIRS = {
  [".git"] = true,
  ["node_modules"] = true,
  ["vendor"] = true,
  ["build"] = true,
  ["dist"] = true,
  [".next"] = true,
  ["__pycache__"] = true,
  [".venv"] = true,
  ["target"] = true,
}

---Check if a filepath should be excluded from glob search
---@param filepath string
---@return boolean
local function is_excluded_path(filepath)
  for segment in filepath:gmatch("[^/\\]+") do
    if EXCLUDED_DIRS[segment] then
      return true
    end
  end
  return false
end

---Search for files containing debug regions
---Uses ripgrep if available, falls back to vim.fn.glob
---@return table[] files List of {filename, line_number, line_text} entries
local function search_project_files()
  local start_pattern = config.start_marker
  local results = {}

  local rg_available = vim.fn.executable("rg") == 1

  if rg_available then
    local cmd = {
      "rg",
      "--line-number",
      "--no-heading",
      "--fixed-strings",
      start_pattern,
      ".",
    }

    local output = vim.fn.systemlist(cmd)

    if vim.v.shell_error == 0 then
      for _, line in ipairs(output) do
        local filename, line_num, line_text = line:match("^([^:]+):(%d+):(.*)$")
        if filename and line_num and line_text then
          table.insert(results, {
            filename = vim.fn.fnamemodify(filename, ":p"),
            line_number = tonumber(line_num),
            line_text = line_text,
          })
        end
      end
    end
  else
    local files = vim.fn.glob("**/*", false, true)

    if #files > MAX_GLOB_FILES then
      vim.notify(
        string.format("[quill] Glob returned %d files (limit: %d). Use ripgrep for large projects.", #files, MAX_GLOB_FILES),
        vim.log.levels.WARN
      )
      return results
    end

    for _, filepath in ipairs(files) do
      if vim.fn.isdirectory(filepath) == 1 then
        goto continue
      end

      if is_excluded_path(filepath) then
        goto continue
      end

      if vim.fn.filereadable(filepath) ~= 1 then
        goto continue
      end

      local file_size = vim.fn.getfsize(filepath)
      if file_size < 0 or file_size > MAX_FILE_SIZE_BYTES then
        goto continue
      end

      local file_lines = vim.fn.readfile(filepath)

      for i, line in ipairs(file_lines) do
        if line:find(start_pattern, 1, true) then
          table.insert(results, {
            filename = vim.fn.fnamemodify(filepath, ":p"),
            line_number = i,
            line_text = line,
          })
        end
      end

      ::continue::
    end
  end

  return results
end

---Toggle all debug regions in project
---@param opts? { confirm: boolean, preview: boolean } Options
---@return number count Number of regions toggled
function M.toggle_project(opts)
  opts = opts or {}

  -- Search for files with debug regions
  local file_matches = search_project_files()

  if #file_matches == 0 then
    vim.notify("No debug regions found in project", vim.log.levels.INFO)
    return 0
  end

  -- Preview mode: show quickfix list and return
  if opts.preview then
    M.list_regions("project")
    return 0
  end

  -- Confirmation prompt
  if opts.confirm then
    local response = vim.fn.confirm(
      string.format("Toggle debug regions in %d file(s)?", #file_matches),
      "&Yes\n&No",
      2
    )

    if response ~= 1 then
      vim.notify("Operation cancelled", vim.log.levels.INFO)
      return 0
    end
  end

  local total_count = 0
  local skipped_files = {}

  for _, match in ipairs(file_matches) do
    local filepath = match.filename

    local bufnr = vim.fn.bufnr(filepath)
    local was_loaded = bufnr ~= -1

    if not was_loaded then
      bufnr = vim.fn.bufadd(filepath)
      vim.fn.bufload(bufnr)
    end

    if not vim.api.nvim_buf_is_valid(bufnr) then
      goto continue
    end

    if was_loaded and vim.bo[bufnr].modified then
      table.insert(skipped_files, filepath)
      goto continue
    end

    local regions = M.find_debug_regions(bufnr)

    if #regions > 0 then
      local commented_count = 0
      for _, region in ipairs(regions) do
        if region.is_commented then
          commented_count = commented_count + 1
        end
      end

      local should_uncomment = commented_count >= (#regions / 2)

      undo.with_undo_group(function()
        for _, region in ipairs(regions) do
          local region_for_toggle = {
            start_line = region.start_line,
            end_line = region.end_line,
            is_commented = should_uncomment,
          }

          if M.toggle_region(bufnr, region_for_toggle) then
            total_count = total_count + 1
          end
        end
      end)

      if vim.bo[bufnr].modified then
        local write_ok, write_err = pcall(function()
          vim.api.nvim_buf_call(bufnr, function()
            vim.cmd("write")
          end)
        end)

        if not write_ok then
          vim.notify(
            string.format("[quill] Failed to write %s: %s", filepath, write_err),
            vim.log.levels.WARN
          )
        end
      end
    end

    ::continue::
  end

  if #skipped_files > 0 then
    vim.notify(
      string.format("[quill] Skipped %d file(s) with unsaved changes", #skipped_files),
      vim.log.levels.WARN
    )
  end

  vim.notify(
    string.format("Toggled %d debug region(s) across project", total_count),
    vim.log.levels.INFO
  )

  return total_count
end

---List debug regions in quickfix
---@param scope "buffer"|"project" Scope of search
function M.list_regions(scope)
  local qf_entries = {}

  if scope == "buffer" then
    -- List regions in current buffer
    local bufnr = 0
    local regions = M.find_debug_regions(bufnr)

    for _, region in ipairs(regions) do
      local state = region.is_commented and "[commented]" or "[active]"
      table.insert(qf_entries, {
        bufnr = bufnr,
        lnum = region.start_line,
        col = 1,
        text = string.format("Debug region %s (lines %d-%d)", state, region.start_line, region.end_line),
      })
    end

    if #qf_entries == 0 then
      vim.notify("No debug regions found in buffer", vim.log.levels.INFO)
      return
    end
  elseif scope == "project" then
    -- Search project files
    local file_matches = search_project_files()

    for _, match in ipairs(file_matches) do
      table.insert(qf_entries, {
        filename = match.filename,
        lnum = match.line_number,
        col = 1,
        text = "Debug region start",
      })
    end

    if #qf_entries == 0 then
      vim.notify("No debug regions found in project", vim.log.levels.INFO)
      return
    end
  else
    vim.notify("Invalid scope: must be 'buffer' or 'project'", vim.log.levels.ERROR)
    return
  end

  -- Populate quickfix list
  vim.fn.setqflist(qf_entries, "r")
  vim.cmd("copen")

  vim.notify(
    string.format("Found %d debug region(s) in %s", #qf_entries, scope),
    vim.log.levels.INFO
  )
end

---Setup with configuration
---@param cfg table Configuration from main setup
function M.setup(cfg)
  if cfg and cfg.debug then
    if cfg.debug.start_marker then
      config.start_marker = cfg.debug.start_marker
    end
    if cfg.debug.end_marker then
      config.end_marker = cfg.debug.end_marker
    end
  end
end

return M
