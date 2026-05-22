if status is-interactive
    # Eza
    alias ls='eza --icons'
    alias ll='eza -lah --icons'
    alias la='eza -a --icons'
    alias lt='eza --tree --icons'

    # Bat
    alias cat='bat --style=plain'

    # Apps
    alias op='opencode'
    alias cc='claude'
    alias y='yazi'
    alias nv='nvim'

    # Docker
    alias d='docker'
    alias dc='docker compose'
    alias dps='docker ps'
    alias dpa='docker ps -a'
    alias di='docker images'
    alias dex='docker exec -it'
    alias dlog='docker logs -f'

    # System
    alias update='sudo dnf update --refresh'
    alias upgrade='sudo dnf upgrade'
    alias clean='sudo dnf autoremove; and sudo dnf clean all'
    alias cleanfd='~/.config/clean/clean.sh'

    # NVIDIA
    alias prime-run='__NV_PRIME_RENDER_OFFLOAD=1 __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only'

    # FZF
    set -gx FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border'
    set -gx FZF_CTRL_R_OPTS '--height 40% --layout=reverse --border'
    set -gx FZF_CTRL_T_OPTS '--height 40% --layout=reverse --border'

    # Zoxide
    if command -v zoxide &>/dev/null
        zoxide init fish | source
    end

    # mise
    if test -f ~/.local/bin/mise
        ~/.local/bin/mise activate fish | source
    end
end
