-- ================================================================================================
-- TITLE : which-key
-- ABOUT : WhichKey helps you remember your Neovim keymaps, by showing keybindings as you type.
-- LINKS :
--   > github : https://github.com/folke/which-key.nvim
-- ================================================================================================

return {
  'folke/which-key.nvim',
  event = 'VeryLazy',
  opts = {
    preset = 'helix',
    delay = 200, -- Show popup after 200ms (faster for better UX)
    spec = {
      { '<leader>b', group = 'Buffer' },
      { '<leader>d', group = 'Debug' },
      { '<leader>f', group = 'Files' },
      { '<leader>g', group = 'Git' },
      { '<leader>S', group = 'Settings' },
      { '<leader>?', hidden = true },
      { '<leader>,', hidden = true },
      { '<leader>.', hidden = true },
      { '<leader>/', hidden = true },
      { '<leader>:', hidden = true },
      { '<leader>n', hidden = true },
      { '<leader>N', hidden = true },
      { '<leader>z', hidden = true },
      { '<leader>Z', hidden = true },
      { '<leader><space>', desc = 'Smart Find Files' },
      { '<leader>c', hidden = true },
      { '<leader>m', hidden = true },
      { '<leader>p', hidden = true },
      { '<leader>q', hidden = true },
      { '<leader>r', hidden = true },
      { '<leader>s', hidden = true },
      { '<leader>u', hidden = true },
      { '<leader>x', hidden = true },
      { '<leader>y', hidden = true },
    },
  },
  keys = {
    {
      '<leader>?',
      function()
        require('which-key').show { global = false }
      end,
      desc = 'Buffer Local Keymaps (which-key)',
    },
  },
}
