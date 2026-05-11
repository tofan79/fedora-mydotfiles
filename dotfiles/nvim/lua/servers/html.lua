-- ================================================================================================
-- TITLE : html (HTML Language Server) LSP Setup
-- ABOUT : Language server for HTML markup
-- LINKS :
--   > github: https://github.com/hrsh7th/vscode-langservers-extracted
-- ================================================================================================

--- @param capabilities table LSP client capabilities (typically from blink-cmp or similar)
--- @return nil
return function(capabilities)
  vim.lsp.config('html', {
    cmd = { 'html-languageserver', '--stdio' },
    capabilities = capabilities,
    filetypes = { 'html', 'templ' },
  })
end
