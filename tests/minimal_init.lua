local root = vim.fn.getcwd()

package.path = table.concat({
  root .. "/lua/?.lua",
  root .. "/lua/?/init.lua",
  package.path,
}, ";")

vim.opt.runtimepath:append(root)
vim.opt.swapfile = false
vim.opt.loadplugins = false

