-- ================================================================================================
-- TITLE : nil_ls (Nix Language Server) LSP Setup
-- ABOUT : Language server for Nix package manager
-- LINKS :
--   > github: https://github.com/oxalica/nil
-- ================================================================================================

--- @param capabilities table LSP client capabilities (typically from blink-cmp or similar)
--- @return nil
return function(capabilities)
  vim.lsp.config('nil_ls', {
    cmd = { 'nil' },
    capabilities = capabilities,
    filetypes = { 'nix' },
  })
end
