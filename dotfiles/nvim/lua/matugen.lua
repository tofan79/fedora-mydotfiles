local M = {}

function M.setup()
  require('base16-colorscheme').setup {
    base00 = '#0b0e14',
    base01 = '#1e222a',
    base02 = '#565b66',
    base03 = '#8e959e',
    base04 = '#8e959e',
    base05 = '#d1d1c7',
    base06 = '#d1d1c7',
    base07 = '#d1d1c7',
    base08 = '#d95757',
    base09 = '#e6b450',
    base0A = '#aad94c',
    base0B = '#39bae6',
    base0C = '#39bae6',
    base0D = '#e6b450',
    base0E = '#aad94c',
    base0F = '#d95757',
  }
end

local signal = vim.uv.new_signal()
signal:start(
  'sigusr1',
  vim.schedule_wrap(function()
    package.loaded['matugen'] = nil
    require('matugen').setup()
  end)
)

return M
