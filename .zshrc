autoload -U compinit && compinit

source /usr/share/zsh/scripts/zplug/init.zsh

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000000
SAVEHIST=10000000
setopt SHARE_HISTORY

zplug "zsh-users/zsh-autosuggestions"

bindkey -v
bindkey "${terminfo[khome]}" beginning-of-line
bindkey "${terminfo[kend]}" end-of-line
bindkey "${terminfo[kdch1]}" delete-char
alias ls="ls --color=auto"
alias grep="grep --color"
alias diff="diff --color=auto"
export PAGER="vimpager"
export EDITOR="vim"

zplug load
eval "$(starship init zsh)"
