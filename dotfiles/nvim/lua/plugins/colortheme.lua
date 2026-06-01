-- Theme plugins — pilih salah satu lewat `:colorscheme <nama>`

return {
  { "catppuccin/nvim", name = "catppuccin", lazy = false, priority = 1000 },
  { "folke/tokyonight.nvim", lazy = false, priority = 1000 },
  { "Mofiqul/vscode.nvim", name = "vscode", lazy = false, priority = 1000 },
  { "sainnhe/everforest", lazy = false, priority = 1000 },
  { "sainnhe/gruvbox-material", lazy = false, priority = 1000 },
  { "ellisonleao/gruvbox.nvim", name = "gruvbox", lazy = false, priority = 1000 },
  { "sainnhe/sonokai", lazy = false, priority = 1000 },
  { "shaunsingh/nord.nvim", lazy = false, priority = 1000 },
  { "tjdevries/colorbuddy.nvim", lazy = false, priority = 1000 },
  { "olimorris/onedark.nvim", lazy = false, priority = 1000 },
  { "tanvirtin/monokai.nvim", lazy = false, priority = 1000 },
  { "nyoom-engineering/oxocarbon.nvim", lazy = false, priority = 1000 },
  { "rebelot/kanagawa.nvim", lazy = false, priority = 1000 },
  { "Mofiqul/dracula.nvim", name = "dracula", lazy = false, priority = 1000 },
  { "rose-pine/neovim", name = "rose-pine", lazy = false, priority = 1000 },
  { "kdheepak/monochrome.nvim", lazy = false, priority = 1000 },

  -- Default colorscheme
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight-night")

      vim.schedule(function()
        vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
        vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
        vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
        vim.api.nvim_set_hl(0, "LineNr", { bg = "none" })
        vim.api.nvim_set_hl(0, "Folded", { bg = "none" })
        vim.api.nvim_set_hl(0, "NonText", { bg = "none" })
        vim.api.nvim_set_hl(0, "SpecialKey", { bg = "none" })
        vim.api.nvim_set_hl(0, "VertSplit", { bg = "none" })
        vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" })
      end)
    end,
  },
}
