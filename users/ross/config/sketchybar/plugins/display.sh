#!/usr/bin/env sh

set -e
mon=$(yabai -m query --displays | jq ".[$1]")

function reset_color {
  sketchybar --set $NAME label.color=0xffa9b1d6
}

if ! [ "$mon" == "null" ]; then
  has_focus=$(echo $mon | jq ".spaces[]" | xargs -I % yabai -m query --windows --space % | jq ".[] | select(.\"has-focus\")")
  if ! [ -z "$has_focus" ]; then
    sketchybar --set $NAME label.color=0xff9ece6a
  else
    reset_color
  fi
else
  reset_color
fi
