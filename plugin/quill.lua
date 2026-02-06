if vim.g.loaded_quill then
  return
end

local function lazy_setup()
  require("quill").setup()
end

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    lazy_setup()
  end,
  once = true,
})

vim.g.loaded_quill = 1
