vim.pack.add({
    'https://github.com/stevearc/oil.nvim',
})


require('oil').setup {
  default_file_explorer = false,
  columns = {
      "icon",
      "permissions",
      "size",
      "mtime",
    },
    view_options = {
    -- Show files and directories that start with "."
    show_hidden = true,
  },
}

vim.keymap.set('n', 'e', '<cmd>Oil<cr>', { desc = 'Open parent directory with Oil' })
