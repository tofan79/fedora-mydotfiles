if status is-interactive
    # ---- Welcome ----
    function fish_greeting
        fastfetch
    end

    # ---- Better man pages ----
    set -gx MANROFFOPT "-c"
    set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"

    # ---- PATH ----
    if test -d ~/.local/bin
        if not contains -- ~/.local/bin $PATH
            set -p PATH ~/.local/bin
        end
    end

    # ---- .fish_profile support ----
    if test -f ~/.fish_profile
        source ~/.fish_profile
    end

    # ---- !! and !$ (repeat last cmd/arg) ----
    function __history_previous_command
        switch (commandline -t)
            case "!"
                commandline -t $history[1]; commandline -f repaint
            case "*"
                commandline -i !
        end
    end

    function __history_previous_command_arguments
        switch (commandline -t)
            case "!"
                commandline -t ""
                commandline -f history-token-search-backward
            case "*"
                commandline -i '$'
        end
    end

    bind ! __history_previous_command
    bind '$' __history_previous_command_arguments

    # ---- history with timestamps ----
    function history
        builtin history --show-time='%F %T '
    end

    # ---- backup file ----
    function backup --argument filename
        cp $filename $filename.bak
    end

    # ---- smarter copy (dir aware) ----
    function copy
        set count (count $argv | tr -d \n)
        if test "$count" = 2; and test -d "$argv[1]"
            set from (echo $argv[1] | string trim -r -c /)
            command cp -r $from $argv[2]
        else
            command cp $argv
        end
    end

    # ---- Navigation ----
    alias ..='cd ..'
    alias ...='cd ../..'
    alias ....='cd ../../..'
    alias .....='cd ../../../..'

    # ---- Eza ----
    alias ls='eza -al --color=always --group-directories-first --icons'
    alias la='eza -a --color=always --group-directories-first --icons'
    alias ll='eza -l --color=always --group-directories-first --icons'
    alias lt='eza -aT --color=always --group-directories-first --icons'
    alias l.="eza -a | grep -e '^\.'"

    # ---- Bat ----
    alias cat='bat --style=plain'

    # ---- Apps ----
    alias op='opencode'
    alias y='yazi'
    alias nv='nvim'

    # ---- Docker / Podman ----
    alias d='docker'
    alias dps='docker ps'
    alias dpa='docker ps -a'
    alias di='docker images'
    alias dex='docker exec -it'
    alias dlog='docker logs -f'

    # ---- Fedora system ----
    alias update='sudo dnf upgrade --refresh'
    alias install='sudo dnf install'
    alias remove='sudo dnf remove'
    alias search='dnf search'
    alias clean='sudo dnf clean all'
    alias repos='dnf repolist'
    alias jctl="journalctl -p 3 -xb"
    alias psmem='ps auxf | sort -nr -k 4'
    alias psmem10='ps auxf | sort -nr -k 4 | head -10'
    alias grep='grep --color=auto'
    alias hw='hwinfo --short'

    # ---- FZF ----
    set -gx FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border'
    set -gx FZF_CTRL_R_OPTS '--height 40% --layout=reverse --border'
    set -gx FZF_CTRL_T_OPTS '--height 40% --layout=reverse --border'

    # ---- Zoxide ----
    if command -v zoxide &>/dev/null
        zoxide init fish | source
    end

end

# ---- mise ----
if test -x ~/.local/bin/mise
    ~/.local/bin/mise activate fish | source
end
