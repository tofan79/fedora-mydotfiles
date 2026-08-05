# ---- fastfetch ----
fastfetch
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
source ~/.config/powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ---- PATH ----
export PATH="$HOME/.local/bin:$PATH"

# ---- Better man pages ----
export MANROFFOPT="-c"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

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
alias yz='yazi'
alias nv='nvim'
# ---- Docker / Podman ----
alias d='docker'
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f'
# ---- Fedora ----
alias update='sudo dnf upgrade --refresh && flatpak update -y'
function uptools() {
  mise self-update && mise upgrade
  nub upgrade && nub node install latest
  local latest=$(nub node ls | tail -1)
  nub node ls | grep -v "$latest" | xargs -r nub node uninstall
  composer self-update && composer global update
  npm update -g
  uv self update
  opencode upgrade
}
alias install='sudo dnf install'
alias remove='sudo dnf remove'
alias search='dnf search'
alias list='dnf list --installed'
alias clean='~/.config/clean/clean.sh'
alias jctl="journalctl -p 3 -xb"
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias grep='grep --color=auto'
alias hw='hwinfo --short'
# ---- `i` = mise install + use global ----
alias ims='mise use -g'

# ---- Zoxide ----
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# ---- FZF ----
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_CTRL_R_OPTS='--height 40% --layout=reverse --border'
export FZF_CTRL_T_OPTS='--height 40% --layout=reverse --border'

# ---- mise ----
eval "$(~/.local/bin/mise activate zsh)"

# ---- opencode ----
export PATH="$HOME/.opencode/bin:$PATH"

# ---- Composer global ----
export PATH="$PATH:$HOME/.config/composer/vendor/bin"

# ---- Zsh plugins (autosuggestions, syntax-highlighting, completions) ----
source ~/.oh-my-zsh/custom/plugins/zsh-completions/zsh-completions.plugin.zsh
autoload -Uz compinit && compinit
source ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
source ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh

# nub
export PATH="$HOME/.nub/bin:$PATH"

# nub node shim
export PATH="$HOME/.nub/node-shim:$PATH"

# nub shims
export PATH="$HOME/.nub/shims:$PATH"
