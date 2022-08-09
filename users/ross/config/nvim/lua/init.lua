require('gitsigns').setup {
  current_line_blame = true,
  current_line_blame_opts = {
    virt_text = true,
    virt_text_pos = 'eol',
  },
  current_line_blame_formatter = '<author>, <author_time:%Y-%m-%d> - <summary>',
  signcolumn = true,
  numhl = true,
}
