# Created by newuser for 5.7.1
export LANG=en_US.UTF-8

autoload -U promptinit; promptinit
prompt spaceship

autoload -U compinit; compinit

alias ls="ls --color=auto"

export PATH=$PATH:~/bin:~/go/bin:~/.bin/:~/RonixOS/devtools
export XDG_CONFIG_HOME=~/.config
export GOPATH=$HOME/go
export POWERLINE_CONFIG_PATHS=~/.config/powerline/

export EDITOR=vim
alias music-dl="youtube-dl -o \"%(title)s.%(ext)s\" -x --embed-thumbnail --add-metadata --audio-format mp3"
alias nestx="Xephyr -ac -screen 800x600 -reset :2"

if [ -z "$TMUX" ]
then
    tmux attach -t MAIN || tmux new -s MAIN
fi

bindkey -v
bindkey '^R' history-incremental-search-backward
bindkey "${terminfo[khome]}" beginning-of-line
bindkey "${terminfo[kend]}" end-of-line
bindkey    "^[[3~"          delete-char
bindkey "^[3;5~" delete-char

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
