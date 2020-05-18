#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep="grep --color"
alias yay="yay --nopgpfetch --mflags \"--skippgpcheck\""
PS1='[\u@\h \W]\$ '
export PAGER="vimpager"

eval "$(starship init bash)"
