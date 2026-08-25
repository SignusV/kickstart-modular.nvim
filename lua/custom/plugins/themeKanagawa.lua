vim.pack.add({
  {
    src = 'https://github.com/rebelot/kanagawa.nvim',
  },
})

require('kanagawa').setup({
  theme = 'dragon',
})

vim.cmd.colorscheme('kanagawa-dragon')
