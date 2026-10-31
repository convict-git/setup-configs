# Terminal output, prompts and the run log.
# Colours only when stdout is a terminal and NO_COLOR is unset. Every line
# printed through these helpers is also appended (uncoloured) to $LOG_FILE.

typeset -g LOG_FILE=""
typeset -gA C
if [[ -t 1 && -z $NO_COLOR ]]; then
  C=(reset $'\e[0m' bold $'\e[1m' dim $'\e[2m' red $'\e[31m' green $'\e[32m'
     yellow $'\e[33m' blue $'\e[34m' magenta $'\e[35m' cyan $'\e[36m' grey $'\e[90m')
else
  C=(reset '' bold '' dim '' red '' green '' yellow '' blue '' magenta '' cyan '' grey '')
fi

log_line() { [[ -n $LOG_FILE ]] && print -r -- "$*" >> $LOG_FILE; return 0 }

say()     { print -r -- "$*"; log_line "$*" }
heading() { print; print -r -- "${C[bold]}${C[cyan]}$*${C[reset]}"; log_line; log_line "== $*" }
sub()     { print; print -r -- "  ${C[bold]}$*${C[reset]}"; log_line; log_line "  $*" }
ok()      { print -r -- "  ${C[green]}✓${C[reset]} $*"; log_line "  ✓ $*" }
warn()    { print -r -- "  ${C[yellow]}!${C[reset]} $*"; log_line "  ! $*" }
fail()    { print -r -- "  ${C[red]}✗${C[reset]} $*"; log_line "  ✗ $*" }
info()    { print -r -- "  ${C[grey]}·${C[reset]} $*"; log_line "  · $*" }
step()    { print -r -- "  ${C[blue]}→${C[reset]} $*"; log_line "  → $*" }
detail()  { print -r -- "    ${C[grey]}$*${C[reset]}"; log_line "    $*" }

# ~ instead of $HOME, for shorter paths in output
tildify() { print -r -- "${1/#$HOME/~}" }

# run <cmd...>: shows the command, streams its output indented, and logs both.
# In dry mode it only shows the command.
run() {
  print -r -- "    ${C[grey]}\$ ${(j: :)${(q-)@}}${C[reset]}"
  log_line "    \$ ${(j: :)${(q-)@}}"
  [[ $MODE == dry ]] && return 0
  local line
  { "$@" 2>&1 } | while IFS= read -r line; do
    print -r -- "    ${C[grey]}│${C[reset]} ${line//$'\r'/}"
    log_line "    │ $line"
  done
  return ${pipestatus[1]}
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
