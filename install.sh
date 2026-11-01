#!/bin/zsh
# Sets up this Mac from the configs in this repo: asks what to set up, shows
# the plan, and changes nothing until you confirm it. See README.md.
#
#   ./install.sh                 interactive setup
#   ./install.sh --check         only the read-only pre-check
#   ./install.sh --dry-run       ask, then show the plan and its commands without running them
#   ./install.sh --answers FILE  no questions: take every answer from FILE (see answers.env)
#   ./install.sh --unlink        remove the links and includes it made, optionally restore backups
#   ./install.sh --docs          regenerate the README's intent and host sections
#                --docs --check  fail if those sections are out of date
#                --docs --refresh  also re-read brew dependencies and plugin URLs (needs brew and nvim)

emulate zsh
setopt extended_glob

ROOT=${0:A:h}
for lib in ui system actions gitconfig intents docs; do source $ROOT/lib/$lib.zsh; done

ACTION=setup DOCS_MODE='' DRY_RUN=0 NONINTERACTIVE=0 ANSWERS_IN=''
while (( $# )); do
  case $1 in
    --check)   [[ $ACTION == docs ]] && DOCS_MODE=check || ACTION=check ;;
    --dry-run) DRY_RUN=1 ;;
    --unlink)  ACTION=unlink ;;
    --answers) ANSWERS_IN=${2:?--answers needs a file}; NONINTERACTIVE=1; shift ;;
    --docs)    ACTION=docs ;;
    --refresh) DOCS_MODE=refresh ;;
    -h|--help) sed -n '2,13s/^# \{0,1\}//p' $0; exit 0 ;;
    *) print -u2 "Unknown option: $1 (see --help)"; exit 2 ;;
  esac
  shift
done

if (( EUID == 0 )); then
  print -u2 "Run this as yourself, not with sudo. It asks before using sudo."
  exit 1
fi

STAMP=$(date +%Y%m%d-%H%M%S)
STATE_DIR=$HOME/.local/state/setup-configs
CONFIG_DIR=$HOME/.config/setup-configs
ANSWERS_FILE=$CONFIG_DIR/answers.env
BACKUP_DIR=$HOME/.setup-configs-backup/$STAMP
REPO_URL=https://github.com/convict-git/setup-configs.git
export SETUP_CONFIGS_DIR=$ROOT

# Homebrew: never update itself, upgrade what's installed, or clean up
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
export HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_ENV_HINTS=1
# Tools installed during this run must be found by later steps
path=($HOME/.local/bin $BREW_PREFIX/bin $BREW_PREFIX/opt/rustup/bin $path)
typeset -U path

typeset -gA ANS FOUNDATION
typeset -g USE_SUDO=0

load_answers() {
  local file=$1 key value
  [[ -f $file ]] || return 0
  while IFS='=' read -r key value; do
    [[ $key == [a-z0-9_]## ]] && ANS[$key]=${(Q)value}
  done < $file
}

save_answers() {
  local key
  mkdir -p $CONFIG_DIR
  { print "# Answers from the last install.sh run, used as the defaults next time."
    print "# Pass a copy to install.sh --answers to run without questions."
    for key in ${(ok)ANS}; do print -r -- "$key=${(q)ANS[$key]}"; done
  } > $ANSWERS_FILE
}

banner() {
  print
  print -r -- "  ${C[bold]}setup-configs${C[reset]}  ${C[grey]}$(tildify $ROOT)${C[reset]}"
  print -r -- "  ${C[grey]}Sets up this Mac from the configs in this repo. Nothing changes until you confirm the plan.${C[reset]}"
  print -r -- "  ${C[grey]}Log: $(tildify $LOG_FILE)${C[reset]}"
}

ask_sudo() {
  heading "Admin rights"
  detail "sudo is only used to install the Command Line Tools and Homebrew when they're missing,"
  detail "and each of those asks first. Everything else installs into your home folder."
  if (( NONINTERACTIVE )); then
    [[ ${ANS[use_sudo]} == y ]] && USE_SUDO=1
    info "Use sudo: ${${USE_SUDO/1/yes}/0/no} (from answers file)"
  elif ask_yn "Use sudo (your admin password) during this setup?" ${ANS[use_sudo]:-n}; then
    USE_SUDO=1
  fi
  ANS[use_sudo]=${${USE_SUDO/1/y}/0/n}
  (( USE_SUDO )) || detail "Without sudo, anything that needs missing Command Line Tools or Homebrew is skipped."
}

platform_supported() {
  [[ ${SYS[arch]} == arm64 && ${SYS[rosetta]} != 1 && ${SYS[macos_major]} -ge 14 ]]
}

# A curl install downloads a tarball (no git needed); once git exists, turn it
# into a clone so `git pull` works
convert_to_clone() {
  [[ -d $ROOT/.git || ! -f $ROOT/.setup-configs-source ]] && return 0
  detect_git
  [[ -n ${SYS[git]} ]] || return 0
  local ref=$(<$ROOT/.setup-configs-source)
  heading "Repository"
  step "Turning $(tildify $ROOT) into a git clone of $ref"
  MODE=apply
  run ${SYS[git]} -C $ROOT init -q -b $ref &&
    run ${SYS[git]} -C $ROOT remote add origin $REPO_URL &&
    run ${SYS[git]} -C $ROOT fetch -q origin $ref &&
    run ${SYS[git]} -C $ROOT reset -q origin/$ref &&
    run ${SYS[git]} -C $ROOT branch -q -u origin/$ref &&
    run rm $ROOT/.setup-configs-source ||
    caution "Couldn't turn $(tildify $ROOT) into a git clone; the files are fine"
}

unlink_all() {
  local target id answer latest file
  heading "Undo links"
  detail "Removes links into this repo and the git includes. Installed packages stay."
  if (( ! NONINTERACTIVE )) && ! ask_yn "Continue?" n; then return 0; fi
  MODE=apply
  for target in ${(u)ALL_TARGETS}; do
    if [[ -L $target && ${target:A} == $ROOT/* ]]; then
      step "Removing link $(tildify $target)"
      run rm $target
    fi
  done
  gitconfig_uninclude git/base.gitconfig
  gitconfig_uninclude git/aliases.gitconfig
  if [[ $(defaults read com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null) == $ROOT/iterm2 ]]; then
    step "Pointing iTerm2 back at its own settings"
    run defaults delete com.googlecode.iterm2 PrefsCustomFolder
    run defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool false
    pgrep -xq iTerm2 && warn "Quit iTerm2 and open it again to use its own settings"
  fi
  latest=($HOME/.setup-configs-backup/*/.manifest(N.om[1]))
  if (( $#latest )) && { (( NONINTERACTIVE )) || ask_yn "Restore files from the last backup ($(tildify ${latest:h}))?" y }; then
    for file in ${(f)"$(<$latest)"}; do
      if [[ -e $file || -L $file ]]; then
        warn "$(tildify $file) exists, so its backup stays in $(tildify ${latest:h})"
      elif [[ -e ${latest:h}/${file#$HOME/} || -L ${latest:h}/${file#$HOME/} ]]; then
        step "Restoring $(tildify $file)"
        run mkdir -p ${file:h} && run mv ${latest:h}/${file#$HOME/} $file
      fi
    done
  fi
  ok "Done"
}

main() {
  mkdir -p $STATE_DIR
  LOG_FILE=$STATE_DIR/$STAMP.log
  load_intents

  case $ACTION in
    docs) docs_main $DOCS_MODE; return ;;
    unlink) banner; detect_git; unlink_all; return ;;
  esac

  load_answers ${ANSWERS_IN:-$ANSWERS_FILE}
  if [[ -n $ANSWERS_IN && ! -f $ANSWERS_IN ]]; then
    print -u2 "No such answers file: $ANSWERS_IN"
    return 2
  fi
  banner
  [[ $ACTION == check ]] || ask_sudo
  detect_all
  print_precheck
  [[ $ACTION == check ]] && return 0
  if ! platform_supported; then
    fail "This Mac isn't supported, so nothing was changed."
    return 1
  fi

  choose_all
  if ! show_plan; then return 0; fi

  if (( DRY_RUN )); then
    heading "Dry run: the commands the plan would run"
    MODE=dry
    apply_all
    print
    ok "Dry run finished. Nothing was changed."
    return 0
  fi

  print
  if (( ! NONINTERACTIVE )) && ! ask_yn "Apply this plan?" y; then
    info "Nothing was changed."
    return 0
  fi
  save_answers
  MODE=apply
  apply_all
  convert_to_clone
  summarize
  print
  detail "Log: $(tildify $LOG_FILE)"
  [[ -s $BACKUP_DIR/.manifest ]] && detail "Backups: $(tildify $BACKUP_DIR)"
  [[ ${STATE[zsh]} == done ]] && detail "Open a new terminal window to load the new shell setup."
  local id
  for id in $INTENT_IDS; do [[ ${STATE[$id]} == failed ]] && return 1; done
  return 0
}

main
