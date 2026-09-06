-- Auto-setup when loaded as startPlugin (non-lazy)
if vim.g.loaded_dendritic_leetcode == 1 then return end
vim.g.loaded_dendritic_leetcode = 1
pcall(function() require("dendritic-leetcode").setup({}) end)
