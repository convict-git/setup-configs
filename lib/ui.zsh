# Terminal output, prompts and the run log.
# Colours only when stdout is a terminal and NO_COLOR is unset. Every line
# printed through these helpers is also appended (uncoloured, with the time) to
# $LOG_FILE. Only standard escape codes are used (colours, the window title), so
# Terminal.app, iTerm2 and an SSH session all show the same thing.

zmodload zsh/datetime zsh/system zsh/zselect

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
  (( TTY )) && size=$(stty size < /dev/tty 2>/dev/null) && (( ${size#* } > 0 )) && COLS=${size#* }
  return 0
}
term_cols
TRAPWINCH() { term_cols }
# This shell's stdin, kept for the commands run_live starts in the background
exec {STDIN_FD}<&0

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

# run <cmd...>: shows the command and its output, and logs both in full. A
# failure ends with the exit status. On a terminal the output scrolls in a small
# window that folds away on success (see run_live); elsewhere every line is
# printed. In dry mode it only shows the command.
run() {
  local cmd="\$ ${(j: :)${(q-)@}}"
  log_line "    $cmd"
  if [[ $MODE == dry ]]; then print -r -- "    ${C[grey]}$cmd${C[reset]}"; return 0; fi
  if (( TTY )); then run_live $cmd "$@"; return; fi
  print -r -- "    ${C[grey]}$cmd${C[reset]}"
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

# run_live <shown command> <cmd...>: runs the command in the background with its
# output going to a file, and redraws the command (with the time so far) and its
# last LIVE_ROWS lines in place. Success leaves just the command and its time;
# failure leaves its last FAIL_ROWS lines, the exit status and where the log is.
# Only cursor-up and erase codes are used, which every terminal understands.
typeset -gi LIVE_ROWS=6 FAIL_ROWS=30
run_live() {
  local cmd=$1; shift
  local out=$(mktemp) start=$EPOCHREALTIME pid rc fd partial='' drawn=0 changed second=0 took line nlines=0
  local -a lines
  # Background commands get /dev/null as stdin; this keeps the terminal
  "$@" <&$STDIN_FD > $out 2>&1 &
  pid=$!
  exec {fd}< $out
  run_live_draw
  while :; do
    changed=0
    run_live_read
    kill -0 $pid 2>/dev/null || break
    took=$(( EPOCHREALTIME - start ))
    if (( changed )); then
      second=${took%.*}
      run_live_draw
    elif (( ${took%.*} != second )); then
      # Only the timer changes, so only its line is rewritten, leaving anything a
      # command printed straight to the terminal (a password prompt) in place
      second=${took%.*}
      run_live_head
      print -rn -- $'\e7\e['"${drawn}A"$'\r\e[2K'"$REPLY"$'\e8'
    fi
    zselect -t 10
  done
  wait $pid
  rc=$?
  run_live_read
  [[ -n $partial ]] && run_live_add "$partial"
  exec {fd}<&-
  rm -f $out
  took=$(( EPOCHREALTIME - start ))
  (( drawn )) && print -rn -- $'\e['"${drawn}A"$'\r\e[J'
  line="    ${C[grey]}$cmd"
  (( took >= 1 )) && line+="  · $(fmt_duration $took)"
  print -r -- "$line${C[reset]}"
  (( rc )) || return 0
  (( nlines > FAIL_ROWS )) && detail "… (the last $FAIL_ROWS of $nlines lines)"
  for line in "${(@)lines}"; do print -r -- "    ${C[grey]}│${C[reset]} $line"; done
  print -r -- "    ${C[red]}✗ exited with $rc${C[reset]}"
  log_line "    ✗ exited with $rc"
  [[ -n $LOG_FILE ]] && detail "The full output is in $(tildify $LOG_FILE)"
  return $rc
}

# Moves complete lines from the output file into $lines (and the log); the
# unfinished last line stays in $partial
run_live_read() {
  local chunk line
  while sysread -i $fd chunk; do partial+=$chunk; changed=1; done
  [[ $partial == *$'\n'* ]] || return 0
  for line in "${(@f)${partial%$'\n'*}}"; do run_live_add "$line"; done
  partial=${partial##*$'\n'}
}

run_live_add() {
  # A progress line redrawn with \r shows its last state
  local line=${${1%$'\r'}##*$'\r'}
  lines+=("$line")
  (( ++nlines > FAIL_ROWS )) && shift lines
  log_line "    │ $line"
  changed=1
}

# The command line with the time so far, cut to one screen line, in $REPLY
run_live_head() {
  local timer="  · $(fmt_duration $second)"
  run_live_fit "$cmd" $(( COLS - 5 - ${#timer} ))
  REPLY="    ${C[grey]}$REPLY$timer${C[reset]}"
}

# Redraws the command and the last LIVE_ROWS lines (plus an unfinished one, such
# as a prompt) over what was drawn before; every line fits one screen line. Each
# starts with \r: sudo puts the terminal in raw mode while its command runs, and
# then a newline alone doesn't go back to the first column.
run_live_draw() {
  local -a show
  local text
  # zsh slices nothing when a negative start is before the first line
  (( $#lines )) && show=("${(@)lines[$(( $#lines > LIVE_ROWS ? $#lines - LIVE_ROWS + 1 : 1 )),-1]}")
  [[ -n ${partial##*$'\r'} ]] && show+=("${partial##*$'\r'}")
  (( drawn )) && print -rn -- $'\e['"${drawn}A"$'\r\e[J'
  run_live_head
  print -r -- $'\r'"$REPLY"
  for text in "${(@)show}"; do
    run_live_fit "$text" $(( COLS - 7 ))
    print -r -- $'\r'"    ${C[grey]}│ $REPLY${C[reset]}"
  done
  drawn=$(( 1 + $#show ))
}

# run_live_fit <text> <columns>: the text without escape codes, cut to that many
# columns, in $REPLY
run_live_fit() {
  local text=${1//$'\t'/  } max=$2
  (( max < 10 )) && max=10
  text=${(S)text//$'\e'\[[0-9;?]#[@-~]}
  # Control characters, the 8-bit ones too: some terminals act on those (one moves the cursor up)
  text=${text//[$'\x01'-$'\x1f'$'\u0080'-$'\u009f']}
  if (( ${(m)#text} > max )); then
    text=${text[1,max-1]}
    while (( ${(m)#text} > max - 1 )); do text=${text[1,-2]}; done
    text+=…
  fi
  REPLY=$text
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
