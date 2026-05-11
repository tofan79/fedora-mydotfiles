-- ================================================================================================
-- TITLE: noice.nvim
-- ABOUT: Displays cmdline and events in popup windows
-- LINKS: noice.nvim     https://github.com/folke/noice.nvim
--        nui.nvim       https://github.com/MunifTanjim/nui.nvim
--        nvim-notify    https://github.com/rcarriga/nvim-notify
-- ================================================================================================
return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {
    lsp = {
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true,
      },
    },
    presets = {
      bottom_search = true,      -- use a classic bottom cmdline for search
      command_palette = true,    -- position the cmdline and popupmenu together
      long_message_to_split = true,  -- long messages will be sent to a split
      inc_rename = false,        -- enables an input dialog for inc-rename
      lsp_doc_border = false,    -- add a border to hover docs and signature help
    },
  },
  dependencies = {
    "MunifTanjim/nui.nvim",
    "rcarriga/nvim-notify",
  },
}
