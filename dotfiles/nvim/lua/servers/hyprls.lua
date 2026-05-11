-- ================================================================================================
-- TITLE : hyprls (Hyprland Language Server) LSP Setup
-- ABOUT : Language server for Hyprland window manager configuration
-- LINKS :
--   > github: https://github.com/hyprwm/hyprland-protocols
-- ================================================================================================

--- @param capabilities table LSP client capabilities (typically from blink-cmp or similar)
--- @return nil
return function(capabilities)
  vim.lsp.config('hyprls', {
    cmd = { 'hyprls' },
    capabilities = capabilities,
    filetypes = { 'hyprland' },
  })
end
