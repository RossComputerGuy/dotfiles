# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/ross/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

alias ls="lsd"

MNML_INSERT_CHAR='>'
MNML_USER_CHAR='~'

source ~/.zgen/zgen.zsh

if ! zgen saved; then
	zgen load subnixr/minimal
	zgen save
fi
