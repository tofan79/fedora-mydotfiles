-- ================================================================================================
-- TITLE : cssls (CSS Language Server) LSP Setup
-- ABOUT : Language server for CSS stylesheets
-- LINKS :
--   > github: https://github.com/hrsh7th/vscode-langservers-extracted
-- ================================================================================================

--- @param capabilities table LSP client capabilities (typically from blink-cmp or similar)
--- @return nil
return function(capabilities)
  vim.lsp.config('cssls', {
    cmd = { 'css-languageserver', '--stdio' },
    capabilities = capabilities,
    filetypes = { 'css', 'scss', 'less' },
  })
end
