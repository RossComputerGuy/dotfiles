#!/bin/sh

LABEL_FG="#dee0e2"
VALUE_FG="#61756f"
URGENT_FG="#cc0000"

set -e

# Helpers
render() {
  local label=$1; shift
  echo -n "%{F${LABEL_FG}}${label}%{F-}: %{F${VALUE_FG}}$@%{F-}"
}

render_mem() {
  local m=$(free -h --si | tail -2 | sed "$2q;d" | xargs)
  local total=$(echo "${m}" | cut -f2 -d ' ')
  local used=$(echo "${m}" | cut -f3 -d ' ')
  render $1 "${used}/${total}"
}

# Modules
battery() {
  local b=$(acpi --battery | head -1)
  render B "$(echo "${b}" | cut -f2 -d ',' | xargs | cut -f2 -d ' ')"
}

clock() {
  render T "$(date "+%a %b %d, %T")"
}

memory() {
  render_mem M 1
}

swap() {
  render_mem S 2
}

workspaces() {
  local ws=$(i3-msg -t get_workspaces)
  local ws_count=$(echo "${ws}" | jq "length")
  local outputs=()
  for ((i=0; i < ${ws_count}; i++)); do
    local w=$(echo "${ws}" | jq ".[${i}]")
    local w_name=$(echo "${w}"  | jq ".name" | xargs)
    local w_urgent=$(echo "${w}" | jq ".urgent")
    local w_focused=$(echo "${w}" | jq ".focused")
    local btn="%{A:i3-msg \"workspace ${w_name}\":}"
    if ${w_focused}; then
      outputs+=("${btn}%{F${LABEL_FG}}${w_name}%{F-}%{A}")
    else
      if ${w_urgent}; then
        outputs+=("${btn}%{F${URGENT_FG}}${w_name}%{F-}%{A}")
      else
        outputs+=("${btn}%{F${VALUE_FG}}${w_name}%{F-}%{A}")
      fi
    fi
  done
  echo -n "${outputs[@]}"
}

while true; do
  echo "%{l}$(memory) $(swap) %{c}$(workspaces) %{r}$(battery) $(clock)"
done

# vim:set ts=2 sw=2 et:
