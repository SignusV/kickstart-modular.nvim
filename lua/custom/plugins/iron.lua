---@param table table table of strings
---@param substring string
--- Checks in any sting in the table contains the substring
local contains = function(table, substring)
  for _, v in ipairs(table) do
    if string.find(v, substring) then
      return true
    end
  end
  return false
end

---@param lines table
-- Removes empty lines. On unix this includes lines only with whitespaces.
local function remove_empty_lines(lines)
  local newlines = {}

  for _, line in pairs(lines) do
    if string.len(line:gsub('[ \t]', '')) > 0 then
      table.insert(newlines, line)
    end
  end

  return newlines
end

---@param s string
--- A helper function using in bracked_paste_python.
-- Checks in a string starts with any of the exceptions.
local function python_close_indent_exceptions(s)
  local exceptions = { 'elif', 'else', 'except', 'finally', '#' }
  for _, exception in ipairs(exceptions) do
    local pattern0 = '^' .. exception .. '[%s:]'
    local pattern1 = '^' .. exception .. '$'
    if string.match(s, pattern0) or string.match(s, pattern1) then
      return true
    end
  end
  return false
end

return {
  {
    'Vigemus/iron.nvim',
    config = function()
      local iron = require 'iron.core'
      local view = require 'iron.view'
      local common = require 'iron.fts.common'
      local is_windows = require('iron.util.os').is_windows
      local extend = require('iron.util.tables').extend
      local open_code = '\27[200~'
      local close_code = '\27[201~'
      local cr = '\n'

      iron.setup {
        config = {
          -- Whether a repl should be discarded or not
          scratch_repl = true,
          -- Your repl definitions come here
          repl_definition = {
            sh = {
              -- Can be a table or a function that
              -- returns a table (see below)
              command = { 'zsh' },
            },
            python = {
              --command = { 'python3' }, -- or
              -- command = { 'ptpython' }, -- or
              -- command = { 'ipython', '--no-autoindent' },
              -- command = { 'jupyter-console', '--ZMQTerminalInteractiveShell.image_handler=None' },
              command = { 'jupyter-console' },
              format = function(lines, extras)
                local result = {}

                local cmd = extras['command']
                local pseudo_meta = { current_buffer = vim.api.nvim_get_current_buf() }
                if type(cmd) == 'function' then
                  cmd = cmd(pseudo_meta)
                end

                local windows = is_windows()
                local python = false
                local ipython = false
                local ptpython = false

                if contains(cmd, 'ipython') then
                  ipython = true
                elseif contains(cmd, 'ptpython') then
                  ptpython = true
                else
                  python = true
                end

                lines = remove_empty_lines(lines)

                -- remove comment only lines
                local out = {}
                for _, s in ipairs(lines) do
                  if not s:match '^%s*#' then
                    out[#out + 1] = s
                  end
                end
                lines = out

                local indent_open = false
                for i, line in ipairs(lines) do
                  if string.match(line, '^%s') ~= nil then
                    indent_open = true
                  end

                  table.insert(result, line)

                  if windows and python or not windows then
                    if i < #lines and indent_open and string.match(lines[i + 1], '^%s') == nil then
                      if not python_close_indent_exceptions(lines[i + 1]) then
                        indent_open = false
                        table.insert(result, cr)
                      end
                    end
                  end
                end

                local newline = windows and '\r\n' or cr
                if #result == 0 then -- handle sending blank lines
                  table.insert(result, cr)
                elseif #result > 0 and result[#result]:sub(1, 1) == ' ' then
                  -- Since the last line of code is indented, the Python REPL
                  -- requires and extra newline in order to execute the code
                  -- table.insert(result, cr)
                else
                  -- table.insert(result, '')
                end

                if ptpython then
                  table.insert(result, 1, open_code)
                  table.insert(result, close_code)
                  table.insert(result, '\n')
                end
                return table.concat(result, cr)
              end,
              -- format = common.bracketed_paste_python, -- for python

              -- format = function(lines, extras)
              --   local common = require 'iron.fts.common'
              --   local result = common.bracketed_paste_python(lines, extras)
              --
              --   -- 1) remove comments & blank lines (also strips the "" that causes empty prompts)
              --   local filtered = vim.tbl_filter(function(line)
              --     return not line:match '^%s*#' and not line:match '^%s*$'
              --   end, result)
              --
              --   if #filtered == 0 then
              --     return {}
              --   end
              --
              --   -- 2) normalize endings on each line (strip any trailing CR/LF we don't control)
              --   for i, line in ipairs(filtered) do
              --     filtered[i] = line:gsub('[\r\n]+$', '')
              --   end
              --
              --   -- 3) detect repl
              --   local cmd = extras and extras.command
              --   if type(cmd) == 'function' then
              --     cmd = cmd { current_buffer = vim.api.nvim_get_current_buf() }
              --   end
              --   -- turn {"ipython","--no-autoindent"} into "ipython --no-autoindent" for matching
              --   if type(cmd) == 'table' then
              --     cmd = table.concat(cmd, ' ')
              --   end
              --   cmd = tostring(cmd or '')
              --
              --   -- 4) build chunk
              --   if cmd:match 'ptpython' then
              --     -- Use bracketed paste for ptpython
              --     local chunk = table.concat(filtered, '\n') .. '\n'
              --     local open_code = '\27[200~'
              --     local close_code = '\27[201~'
              --     -- Per iron’s own impl, ptpython expects a newline after close
              --     return { open_code .. chunk .. close_code .. '\n' }
              --   else
              --     -- python/ipython: join with CR = simulate pressing Enter between lines
              --     local cr = '\r'
              --     local chunk = table.concat(filtered, cr) .. cr
              --     return { chunk }
              --   end
              -- end,
              -- format = common.bracketed_paste, -- for ipython
              block_dividers = { '# %%', '#%%' },
            },
          },
          -- set the file type of the newly created repl to ft
          -- bufnr is the buffer id of the REPL and ft is the filetype of the
          -- language being used for the REPL.
          repl_filetype = function(bufnr, ft)
            return ft
            -- or return a string name such as the following
            -- return "iron"
          end,
          -- How the repl window will be displayed
          -- See below for more information
          repl_open_cmd = view.split.vertical('40%', {
            number = true,
            relativenumber = true, -- optional
          }),

          -- repl_open_cmd can also be an array-style table so that multiple
          -- repl_open_commands can be given.
          -- When repl_open_cmd is given as a table, the first command given will
          -- be the command that `IronRepl` initially toggles.
          -- Moreover, when repl_open_cmd is a table, each key will automatically
          -- be available as a keymap (see `keymaps` below) with the names
          -- toggle_repl_with_cmd_1, ..., toggle_repl_with_cmd_k
          -- For example,
          --
          -- repl_open_cmd = {
          --   view.split.vertical.rightbelow("%40"), -- cmd_1: open a repl to the right
          --   view.split.rightbelow("%25")  -- cmd_2: open a repl below
          -- }
        },
        -- Iron doesn't set keymaps by default anymore.
        -- You can set them here or manually add keymaps to the functions in iron.core
        keymaps = {
          toggle_repl = '<leader>rt', -- toggles the repl open and closed.
          -- If repl_open_command is a table as above, then the following keymaps are
          -- available
          -- toggle_repl_with_cmd_1 = "<space>rv",
          -- toggle_repl_with_cmd_2 = "<space>rh",
          restart_repl = '<leader>rR', -- calls `IronRestart` to restart the repl
          send_motion = '<leader>rsm',
          visual_send = '<leader>rsv',
          send_file = '<leader>rsf',
          send_line = '<leader>rsl',
          send_paragraph = '<leader>rsp',
          send_until_cursor = '<leader>rsu',
          send_mark = '<leader>rsm',
          send_code_block = '<leader>rsb',
          send_code_block_and_move = '<leader>rsn',
          mark_motion = '<leader>rmm',
          mark_visual = '<leader>rmv',
          remove_mark = '<leader>rmr',
          cr = '<leader>r<cr>',
          interrupt = '<leader>r<leader>',
          exit = '<leader>rq',
          clear = '<leader>rc',
        },
        -- If the highlight is on, you can change how it looks
        -- For the available options, check nvim_set_hl
        highlight = {
          italic = true,
        },
        ignore_blank_lines = true, -- ignore blank lines when sending visual select lines
      }

      -- iron also has a list of commands, see :h iron-commands for all available commands
      vim.keymap.set('n', '<space>rf', '<cmd>IronFocus<cr>')
      vim.keymap.set('n', '<space>rh', '<cmd>IronHide<cr>')
    end,
  },
}
