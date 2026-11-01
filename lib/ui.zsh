# Terminal output, prompts and the run log.
# Colours only when stdout is a terminal and NO_COLOR is unset. Every line
# printed through these helpers is also appended (uncoloured, with the time) to
# $LOG_FILE. Only standard escape codes are used (colours, the window title), so
# Terminal.app, iTerm2 and an SSH session all show the same thing.

zmodload zsh/datetime

typeset -g LOG_FILE=""
typeset -gA C
if [[ -t 1 && -z $NO_COLOR ]]; then
  C=(reset $'\e[0m' bold $'\e[1m' dim $'\e[2m' red $'\e[31m' green $'\e[32m'
     yellow $'\e[33m' blue $'\e[34m' magenta $'\e[35m' cyan $'\e[36m' grey $'\e[90m')
else
  C=(reset '' bold '' dim '' red '' green '' yellow '' blue '' magenta '' cyan '' grey '')
fi
# A terminal to draw on (not a pipe or TERM=dumb), and its width
typeset -gi TTY=0 COLS=80
[[ -t 1 && $TERM != dumb ]] && TTY=1
term_cols() {
  local size
  (( TTY )) && size=$(stty size < /dev/tty 2>/dev/null) && COLS=${size#* }
}
term_cols
TRAPWINCH() { term_cols }

log_line() {
  [[ -n $LOG_FILE ]] || return 0
  (( $# )) || { print >> $LOG_FILE; return 0 }
  local now
  strftime -s now %H:%M:%S $EPOCHSECONDS
  print -r -- "$now $*" >> $LOG_FILE
}

say()     { print -r -- "$*"; log_line "$*" }
sub()     { print; print -r -- "  ${C[bold]}$*${C[reset]}"; log_line; log_line "  $*" }
ok()      { print -r -- "  ${C[green]}✓${C[reset]} $*"; log_line "  ✓ $*" }
warn()    { print -r -- "  ${C[yellow]}! $*${C[reset]}"; log_line "  ! $*" }
fail()    { print -r -- "  ${C[bold]}${C[red]}✗ $*${C[reset]}"; log_line "  ✗ $*" }
info()    { print -r -- "  ${C[grey]}·${C[reset]} $*"; log_line "  · $*" }
step()    { print -r -- "  ${C[blue]}→${C[reset]} ${C[bold]}$*${C[reset]}"; log_line "  → $*" }
detail()  { print -r -- "    ${C[grey]}$*${C[reset]}"; log_line "    $*" }

# heading <title> [note]: a rule across the screen (at most 80 columns), with an
# optional grey note such as "(3 of 14)"
heading() {
  local title=$1 note=$2 width=$(( COLS < 80 ? COLS : 80 )) fill rule
  fill=$(( width - ${(m)#:-━━ $title${note:+ $note} } ))
  (( fill < 2 )) && fill=2
  rule=${(l:$fill::-:):-}
  print
  print -r -- "${C[bold]}${C[cyan]}━━ $title${C[reset]}${note:+ ${C[grey]}$note${C[reset]}} ${C[cyan]}${rule//-/━}${C[reset]}"
  log_line
  log_line "== $title${note:+ $note}"
}

# fmt_duration <seconds>: 42s, 3m 05s or 1h 02m
fmt_duration() {
  local s=${1%.*}
  if (( s < 60 )); then print -r -- "${s}s"
  elif (( s < 3600 )); then printf '%dm %02ds\n' $(( s / 60 )) $(( s % 60 ))
  else printf '%dh %02dm\n' $(( s / 3600 )) $(( s % 3600 / 60 ))
  fi
}

# term_title <text>: the window or tab title; an empty one hands it back to the terminal
term_title() { (( TTY )) && print -n -- $'\e]2;'"$1"$'\a'; return 0 }

# ~ instead of $HOME, for shorter paths in output
tildify() { print -r -- "${1/#$HOME/~}" }

# run <cmd...>: shows the command, streams its output indented, and logs both.
# A failure ends with the exit status. In dry mode it only shows the command.
run() {
  print -r -- "    ${C[grey]}\$ ${(j: :)${(q-)@}}${C[reset]}"
  log_line "    \$ ${(j: :)${(q-)@}}"
  [[ $MODE == dry ]] && return 0
  local line rc
  { "$@" 2>&1 } | while IFS= read -r line; do
    # A progress line redrawn with \r shows its last state
    line=${${line%$'\r'}##*$'\r'}
    print -r -- "    ${C[grey]}│${C[reset]} $line"
    log_line "    │ $line"
  done
  rc=${pipestatus[1]}
  if (( rc )); then
    print -r -- "    ${C[red]}✗ exited with $rc${C[reset]}"
    log_line "    ✗ exited with $rc"
  fi
  return $rc
}

# Prompts read from the terminal, so they work even when stdin is a pipe.
# With --answers they never prompt: the caller passes the stored answer.

# ask_yn <question> <default y|n>: returns 0 for yes
ask_yn() {
  local question=$1 default=${2:-y} reply choices
  [[ $default == y ]] && choices='[Y/n]' || choices='[y/N]'
  while true; do
    print -n -- "  ${C[magenta]}?${C[reset]} $question ${C[grey]}$choices${C[reset]} "
    read -r reply < /dev/tty || reply=''
    reply=${${reply:l}// /}
    [[ -z $reply ]] && reply=$default
    case $reply in
      y|yes) log_line "  ? $question → yes"; return 0 ;;
      n|no)  log_line "  ? $question → no"; return 1 ;;
    esac
  done
}

# ask_text <variable> <question> <default>
ask_text() {
  local _var=$1 question=$2 default=$3 reply
  print -n -- "  ${C[magenta]}?${C[reset]} $question ${default:+${C[grey]}[$default]${C[reset]} }"
  read -r reply < /dev/tty || reply=''
  [[ -z $reply ]] && reply=$default
  : ${(P)_var::=$reply}
  log_line "  ? $question → $reply"
}
