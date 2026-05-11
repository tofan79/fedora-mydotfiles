-- ================================================================================================
-- TITLE: NeoVim keymaps
-- ABOUT: sets some quality-of-life keymaps
-- ================================================================================================

-- Center screen when jumping
vim.keymap.set('n', 'n', 'nzzzv', { desc = 'Next search result (centered)' })
vim.keymap.set('n', 'N', 'Nzzzv', { desc = 'Previous search result (centered)' })
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Half page down (centered)' })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Half page up (centered)' })

-- Buffer navigation
vim.keymap.set('n', '<leader>bn', '<Cmd>bnext<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', '<leader>bp', '<Cmd>bprevious<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', '<leader>bs', '<Cmd>set showtabline=2<CR>', { desc = 'Show tabline' })
vim.keymap.set('n', '<Tab>', '<Cmd>bnext<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', '<S-Tab>', '<Cmd>bprevious<CR>', { desc = 'Previous buffer' })

-- Better window navigation
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Move to left window' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Move to bottom window' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Move to top window' })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Move to right window' })

-- Splitting & Resizing
vim.keymap.set('n', '<leader>sv', '<Cmd>vsplit<CR>', { desc = 'Split window vertically' })
vim.keymap.set('n', '<leader>sh', '<Cmd>split<CR>', { desc = 'Split window horizontally' })
vim.keymap.set('n', '<C-Up>', '<Cmd>resize +2<CR>', { desc = 'Increase window height' })
vim.keymap.set('n', '<C-Down>', '<Cmd>resize -2<CR>', { desc = 'Decrease window height' })
vim.keymap.set('n', '<C-Left>', '<Cmd>vertical resize -2<CR>', { desc = 'Decrease window width' })
vim.keymap.set('n', '<C-Right>', '<Cmd>vertical resize +2<CR>', { desc = 'Increase window width' })

-- Better indenting in visual mode
vim.keymap.set('v', '<', '<gv', { desc = 'Indent left and reselect' })
vim.keymap.set('v', '>', '>gv', { desc = 'Indent right and reselect' })

-- Better J behavior
vim.keymap.set('n', 'J', 'mzJ`z', { desc = 'Join lines and keep cursor position' })

-- Keep last yanked when pasting
vim.keymap.set('v', 'p', '"_dP', { noremap = true, silent = true })

-- Save file with Ctrl+S
vim.keymap.set({ 'n', 'i' }, '<C-s>', '<Cmd>w<CR>', { desc = 'Save file' })

-- Quick config editing
vim.keymap.set('n', '<leader>rc', '<Cmd>e ~/.config/nvim/init.lua<CR>', { desc = 'Edit config' })

-- Reload nvim config and theme
vim.keymap.set('n', '<leader>rr', function()
  vim.cmd.source(vim.fn.stdpath 'config' .. '/init.lua')
  vim.notify('Config and theme reloaded!', vim.log.levels.INFO)
end, { desc = 'Reload config and theme' })

-- Reload current file (check for external changes)
vim.keymap.set('n', '<leader>fl', '<Cmd>checktime<CR>', { desc = 'Reload file (check for changes)' })

-- Markdown keymaps
vim.keymap.set('n', '<leader>mc', '<Cmd>MarkdownCheckbox<CR>', { desc = 'Toggle markdown checkbox' })
vim.keymap.set('n', '<leader>mp', '<Cmd>MarkdownPreview<CR>', { desc = 'Open markdown preview' })
vim.keymap.set('n', '<leader>mt', '<Cmd>MarkdownPreviewToggle<CR>', { desc = 'Toggle markdown preview' })
vim.keymap.set('n', '<leader>ms', '<Cmd>MarkdownPreviewStop<CR>', { desc = 'Stop markdown preview' })

-- "Normy" Clipboard Operations (mouse-friendly)
-- Copy operations
vim.keymap.set('n', '<leader>yy', 'yy', { desc = 'Copy line' })
vim.keymap.set('n', '<leader>y$', 'y$', { desc = 'Copy to end of line' })
vim.keymap.set('n', '<leader>yw', 'yiw', { desc = 'Copy word' })
vim.keymap.set('n', '<leader>yW', 'yiW', { desc = 'Copy WORD' })
vim.keymap.set('n', '<leader>yp', 'yyp', { desc = 'Copy line and paste below' })
vim.keymap.set('n', '<leader>yP', 'yyP', { desc = 'Copy line and paste above' })

-- Paste operations
vim.keymap.set('n', '<leader>pp', 'p', { desc = 'Paste after cursor' })
vim.keymap.set('n', '<leader>pP', 'P', { desc = 'Paste before cursor' })
vim.keymap.set('n', '<leader>gp', '"0p', { desc = 'Paste without overwriting register' })
vim.keymap.set('n', '<leader>gP', '"0P', { desc = 'Paste before without overwriting' })

-- Cut operations
vim.keymap.set('n', '<leader>xx', 'dd', { desc = 'Cut line' })
vim.keymap.set('n', '<leader>x$', 'd$', { desc = 'Cut to end of line' })
vim.keymap.set('n', '<leader>xw', 'diw', { desc = 'Cut word' })
vim.keymap.set('n', '<leader>xW', 'diW', { desc = 'Cut WORD' })

-- Auto-open file explorer when opening a directory (debug version)
vim.api.nvim_create_autocmd('User', {
  pattern = 'VeryLazy',
  callback = function()
    -- Debug: show a notification to see if this runs
    vim.notify('VeryLazy event fired! argc=' .. vim.fn.argc(), vim.log.levels.INFO)
    local argc = vim.fn.argc()
    if argc == 1 then
      local arg = vim.fn.argv(0)
      local stat = vim.loop.fs_stat(arg)
      if stat and stat.type == 'directory' then
        vim.notify('Opening explorer for: ' .. arg, vim.log.levels.INFO)
        -- Simple approach: trigger the file explorer mapping
        vim.defer_fn(function()
          vim.cmd('normal! \\<leader>e')
        end, 100)
      end
    end
  end,
})
