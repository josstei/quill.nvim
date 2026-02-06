local plenary_dir = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"

if vim.fn.isdirectory(plenary_dir) == 0 then
  vim.fn.system({
    "git",
    "clone",
    "--depth=1",
    "https://github.com/nvim-lua/plenary.nvim",
    plenary_dir,
  })
end

vim.opt.runtimepath:append(".")
vim.opt.runtimepath:append(plenary_dir)

package.path = package.path .. ";tests/?.lua"

vim.cmd("runtime plugin/plenary.vim")

require("plenary.busted")
