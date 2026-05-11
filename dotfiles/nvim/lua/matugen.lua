local M = {}

function M.setup()
  require('base16-colorscheme').setup {
    -- Background tones
    base00 = '#171214', -- Default Background
    base01 = '#231e20', -- Lighter Background (status bars)
    base02 = '#2e282b', -- Selection Background
    base03 = '#9c8d92', -- Comments, Invisibles
    -- Foreground tones
    base04 = '#d4c2c8', -- Dark Foreground (status bars)
    base05 = '#ebe0e2', -- Default Foreground
    base06 = '#ebe0e2', -- Light Foreground
    base07 = '#ebe0e2', -- Lightest Foreground
    -- Accent colors
    base08 = '#ffb4ab', -- Variables, XML Tags, Errors
    base09 = '#f3ba9b', -- Integers, Constants
    base0A = '#dfbdcc', -- Classes, Search Background
    base0B = '#ffafd7', -- Strings, Diff Inserted
    base0C = '#f3ba9b', -- Regex, Escape Chars
    base0D = '#ffafd7', -- Functions, Methods
    base0E = '#dfbdcc', -- Keywords, Storage
    base0F = '#93000a', -- Deprecated, Embedded Tags
  }
end

-- Register a signal handler for SIGUSR1 (matugen updates)
local signal = vim.uv.new_signal()
signal:start(
  'sigusr1',
  vim.schedule_wrap(function()
    package.loaded['matugen'] = nil
    require('matugen').setup()
  end)
)

return M
