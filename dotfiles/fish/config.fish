if status is-interactive
    # Commands to run in interactive sessions can go here

    # Initialize zoxide
    zoxide init fish | source
end

# Alias for opencode
alias op='opencode'

# Alias for Claude
alias cc='claude'

# Alias for yazi
alias y='yazi'

# Alias for neovim
alias nv='nvim'

# Add scripts directory to PATH
fish_add_path $HOME/.config/scripts

# Add opencode to PATH
# fish_add_path $HOME/.opencode/bin

# Set Chrome executable for Flutter web development
# set -gx CHROME_EXECUTABLE /usr/bin/chromium
