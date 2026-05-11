-- ================================================================================================
-- TITLE: markdown-preview.nvim
-- ABOUT: Preview markdown files in browser with live updates
-- LINKS: markdown-preview.nvim https://github.com/iamcco/markdown-preview.nvim
-- ================================================================================================
return {
  "iamcco/markdown-preview.nvim",
  cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
  ft = { "markdown" },
  init = function()
    vim.g.mkdp_auto_start = 0
    vim.g.mkdp_auto_close = 0
    vim.g.mkdp_refresh_slow = 0
    vim.g.mkdp_command_delay = 100
    vim.g.mkdp_open_to_the_world = 0
    vim.g.mkdp_open_ip = ""
    vim.g.mkdp_browser = ""
    vim.g.mkdp_echo_preview_url = 1
    vim.g.mkdp_page_title = "「${name}」"
    vim.g.mkdp_filetypes = { "markdown" }
  end,
}
