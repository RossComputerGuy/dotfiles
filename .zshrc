autoload -U compinit && compinit

bindkey -v
bindkey "${terminfo[khome]}" beginning-of-line
bindkey "${terminfo[kend]}" end-of-line
bindkey "${terminfo[kdch1]}" delete-char
alias ls="ls --color=auto"
alias grep="grep --color"
export PAGER="vimpager"
export EDITOR="vim"

eval "$(starship init zsh)"
