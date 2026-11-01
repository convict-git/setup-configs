# Every change install.sh makes goes through these helpers. Each one runs in one
# of three modes, so an intent's apply() is written once:
#   plan   records what it would do (and whether that's already done) for the plan screen
#   apply  does it, showing each command and its output
#   dry    shows the commands without running them

typeset -g MODE=plan
typeset -ga PLAN_ORDER CAUTIONS
typeset -gA PLAN CASK_APPS

# plan_add <group> <text> [already-done 0|1]; the same line twice is shown once
plan_add() {
  local group=$1 text=$2 done=${3:-0} line
  (( ${PLAN_ORDER[(Ie)$group]} )) || PLAN_ORDER+=$group
  if [[ $group == Cautions ]]; then
    line="    $text"
  elif (( done )); then
    line="    ${C[green]}✓${C[reset]} ${C[grey]}$text${C[reset]}"
  else
    line="    ${C[blue]}+${C[reset]} $text"
  fi
  [[ $'\n'${PLAN[$group]} == *$'\n'$line$'\n'* ]] || PLAN[$group]+=$line$'\n'
}

# caution <text>: shown in the plan, and again in the final summary
caution() {
  if [[ $MODE == plan ]]; then
    plan_add "Cautions" "${C[yellow]}!${C[reset]} ${I_TITLE[$CUR]}: $*" 0
  else
    warn "$*"
    CAUTIONS+="${I_TITLE[$CUR]}: $*"
  fi
}

# task <group> <label> <already-done 0|1> <cmd...>
# Runs cmd through run(), or calls it directly when it's a function of ours
# that runs its own commands.
task() {
  local group=$1 label=$2 done=$3; shift 3
  if [[ $MODE == plan ]]; then plan_add $group $label $done; return 0; fi
  if (( done )); then ok "$label (already done)"; return 0; fi
  step $label
  if (( $+functions[$1] )); then "$@"; else run "$@"; fi
}

sudo_ready() {
  [[ $MODE == dry ]] && return 0
  sudo -v -p "    Password for %u (sudo): " < /dev/tty
}

formula_present() { [[ -e $BREW_PREFIX/opt/$1 ]] }

cask_present() {
  local app=${CASK_APPS[$1]}
  [[ -d $BREW_PREFIX/Caskroom/$1 ]] && return 0
  [[ -n $app && ( -d /Applications/$app || -d $HOME/Applications/$app ) ]]
}

# brew_install <formula...>: installs the missing ones; never upgrades
brew_install() {
  local formula missing=() have=()
  for formula in "$@"; do formula_present $formula && have+=$formula || missing+=$formula; done
  if [[ $MODE == plan ]]; then
    (( $#missing )) && plan_add "Homebrew formulae" "${(j: :)missing}"
    (( $#have )) && plan_add "Homebrew formulae" "${(j: :)have}" 1
    return 0
  fi
  if (( ! $#missing )); then ok "Already installed with brew: ${(j: :)have}"; return 0; fi
  step "Installing with brew: ${(j: :)missing}"
  run $BREW_PREFIX/bin/brew install --formula $missing
}

# cask_install <cask...>: apps go to ~/Applications, fonts to ~/Library/Fonts.
# A font that's already installed some other way only gets a caution.
cask_install() {
  local cask rc=0
  for cask in "$@"; do
    if [[ $MODE == plan ]]; then
      cask_present $cask && plan_add "Homebrew casks" $cask 1 || plan_add "Homebrew casks" $cask
      continue
    fi
    if cask_present $cask; then ok "Already installed: $cask"; continue; fi
    step "Installing with brew: $cask"
    if ! run $BREW_PREFIX/bin/brew install --cask --appdir=$HOME/Applications $cask; then
      if [[ $cask == font-* ]]; then
        caution "$cask didn't install; if the font is already on this Mac that's fine"
      else
        rc=1
      fi
    fi
  done
  return $rc
}

# backup <file>: moves it under $BACKUP_DIR, keeping its path relative to ~
backup() {
  local file=$1 dest=$BACKUP_DIR/${1#$HOME/}
  [[ -d ${dest:h} ]] || run mkdir -p ${dest:h} || return 1
  run mv $file $dest || return 1
  [[ $MODE == dry ]] || print -r -- "$file" >> $BACKUP_DIR/.manifest
  detail "Backed up to $(tildify $dest)"
}

# link <repo-relative source> <destination>
link() {
  local src=$ROOT/$1 dest=$2
  if [[ -L $dest && ${dest:A} == ${src:A} ]]; then
    [[ $MODE == plan ]] && plan_add "Links" "$(tildify $dest) → $1" 1 ||
      ok "$(tildify $dest) already links to $1"
    return 0
  fi
  if [[ $MODE == plan ]]; then
    [[ -e $dest || -L $dest ]] && plan_add "Links" "$(tildify $dest) → $1  ${C[grey]}(current one backed up)${C[reset]}" ||
      plan_add "Links" "$(tildify $dest) → $1"
    return 0
  fi
  step "Linking $(tildify $dest) → $1"
  if [[ -e $dest || -L $dest ]]; then backup $dest || return 1; fi
  [[ -d ${dest:h} ]] || run mkdir -p ${dest:h} || return 1
  run ln -s $src $dest
}

# link_dev_tool <name>: links scripts/xcrun-tool as ~/.local/bin/<name>, but only
# when the developer tools have that binary; otherwise the link would make Neovim
# think the tool exists. xcrun is asked only once the Command Line Tools are here
# (before that it's a stub that offers to install them), so the plan assumes the
# ones Foundation installs have it.
link_dev_tool() {
  local name=$1
  if [[ -n ${SYS[clt]} ]] && ! PATH=/usr/bin:/bin xcrun --no-cache --find $name >/dev/null 2>&1; then
    caution "the developer tools have no $name; update the Command Line Tools and run install.sh again"
    return 0
  fi
  link scripts/xcrun-tool $HOME/.local/bin/$name
}

# copy_file <repo-relative source> <destination>: copies when missing or different
copy_file() {
  local src=$ROOT/$1 dest=$2 same=0
  [[ -f $dest ]] && cmp -s $src $dest && same=1
  if [[ $MODE == plan ]]; then plan_add "Files" "$1 → $(tildify $dest)" $same; return 0; fi
  if (( same )); then ok "$(tildify $dest) is up to date"; return 0; fi
  step "Copying $1 → $(tildify $dest)"
  if [[ -e $dest || -L $dest ]]; then backup $dest || return 1; fi
  [[ -d ${dest:h} ]] || run mkdir -p ${dest:h} || return 1
  run cp $src $dest
}

# git_clone_pinned <url> <commit> <destination> [branch]: a shallow checkout of
# one commit; an existing destination is left alone
git_clone_pinned() {
  local url=$1 commit=$2 dest=$3 branch=${4:-main} git
  if [[ -e $dest ]]; then
    [[ $MODE == plan ]] && plan_add "Git clones" "$(tildify $dest) exists, left as it is" 1 ||
      ok "$(tildify $dest) exists, left as it is"
    return 0
  fi
  if [[ $MODE == plan ]]; then
    plan_add "Git clones" "${url#https://} at ${commit[1,7]} → $(tildify $dest)"
    return 0
  fi
  detect_git; git=${SYS[git]:-git}
  step "Cloning ${url#https://} at ${commit[1,7]}"
  run $git init -q -b $branch $dest &&
    run $git -C $dest remote add origin $url &&
    run $git -C $dest fetch -q --depth 1 origin $commit &&
    run $git -C $dest reset -q --hard FETCH_HEAD
}
