# ~/.gitconfig stays a file of your own: install.sh only sets user.name and
# user.email and adds include.path lines pointing at git/*.gitconfig in the repo.
# When there's no git yet (no Command Line Tools), it writes those same lines as
# plain text, which git reads once it's installed.

# The file `git config --global` would write to
gitconfig_file() {
  local xdg=${XDG_CONFIG_HOME:-$HOME/.config}/git/config
  if [[ -n $GIT_CONFIG_GLOBAL ]]; then print -r -- $GIT_CONFIG_GLOBAL
  elif [[ -e $HOME/.gitconfig || -L $HOME/.gitconfig ]]; then print -r -- $HOME/.gitconfig
  elif [[ -f $xdg ]]; then print -r -- $xdg
  else print -r -- $HOME/.gitconfig
  fi
}

# An old setup linked ~/.gitconfig straight to the repo's git/.gitconfig
gitconfig_is_legacy_link() {
  local file=$HOME/.gitconfig
  [[ -L $file && ${file:A} == $ROOT/* ]]
}

# gitconfig_get <section.key>: the last value, read without git if need be
gitconfig_get() {
  local file=$(gitconfig_file) key=$1
  [[ -f $file ]] || return 1
  if [[ -n ${SYS[git]} ]]; then
    ${SYS[git]} config --file $file --get $key 2>/dev/null
    return
  fi
  awk -v want_section=${${key%.*}:l} -v want_key=${${key##*.}:l} '
    /^[ \t]*\[/ { s = tolower($0); gsub(/^[ \t]*\[|\][ \t]*$/, "", s); section = s; next }
    section == want_section {
      line = $0; sub(/^[ \t]+/, "", line)
      k = line; sub(/[ \t]*=.*/, "", k)
      if (tolower(k) == want_key) {
        v = line; sub(/^[^=]*=[ \t]*/, "", v); gsub(/^"|"$/, "", v)
        gsub(/\\"/, "\"", v); gsub(/\\\\/, "\\", v)
        value = v; found = 1
      }
    }
    END { if (found) print value; else exit 1 }' $file
}

gitconfig_has_include() {
  local file=$(gitconfig_file) inc=$1
  [[ -f $file ]] || return 1
  if [[ -n ${SYS[git]} ]]; then
    ${SYS[git]} config --file $file --get-all include.path 2>/dev/null | grep -qxF -- $inc
  else
    grep -qE "^[[:space:]]*path[[:space:]]*=[[:space:]]*\"?${(b)inc}\"?[[:space:]]*$" $file
  fi
}

# gitconfig_append <file> <section header> <key = value>...: for when there's no git
gitconfig_append() {
  local file=$1 header=$2 line; shift 2
  detail "Writing to $(tildify $file) (no git yet):"
  detail "  $header"
  for line in "$@"; do detail "      $line"; done
  [[ $MODE == dry ]] && return 0
  mkdir -p ${file:h}
  [[ -s $file && -n $(tail -c1 $file) ]] && print >> $file
  { print -r -- $header; for line in "$@"; do print -r -- $'\t'$line; done } >> $file
}

# Quotes a value the way git config writes it
gitconfig_quote() { print -r -- "\"${${1//\\/\\\\}//\"/\\\"}\"" }

# Replaces a ~/.gitconfig that links into this repo with a file of your own
gitconfig_replace_legacy_link() {
  gitconfig_is_legacy_link || return 0
  local file=$HOME/.gitconfig
  if [[ $MODE == plan ]]; then
    plan_add "Git config" "~/.gitconfig links into this repo; it becomes a file of your own (old one backed up)"
    return 0
  fi
  step "Replacing ~/.gitconfig, which links into this repo, with a file of your own"
  run mkdir -p $BACKUP_DIR && run cp -L $file $BACKUP_DIR/.gitconfig && run rm $file || return 1
  [[ $MODE == dry ]] || print -r -- $file >> $BACKUP_DIR/.manifest
  detail "Backed up to $(tildify $BACKUP_DIR/.gitconfig); any includeIf lines in it aren't carried over"
}

# gitconfig_set_user <name> <email>: either may be empty to leave it unset
gitconfig_set_user() {
  local name=$1 email=$2 file=$(gitconfig_file) done=0
  [[ -z $name && -z $email ]] && return 0
  if ! gitconfig_is_legacy_link && [[ $(gitconfig_get user.name) == $name && $(gitconfig_get user.email) == $email ]]; then
    done=1
  fi
  if [[ $MODE == plan ]]; then
    plan_add "Git config" "$(tildify $file): user ${name:-(unset)} <${email:-unset}>" $done
    return 0
  fi
  (( done )) && { ok "$(tildify $file) already has your name and email"; return 0; }
  step "Setting your name and email in $(tildify $file)"
  if [[ -n ${SYS[git]} ]]; then
    [[ -n $name ]] && { run ${SYS[git]} config --file $file user.name $name || return 1 }
    [[ -n $email ]] && { run ${SYS[git]} config --file $file user.email $email || return 1 }
    return 0
  fi
  local lines=()
  [[ -n $name ]] && lines+="name = $(gitconfig_quote $name)"
  [[ -n $email ]] && lines+="email = $(gitconfig_quote $email)"
  gitconfig_append $file "[user]" $lines
}

# gitconfig_include <repo-relative file>
gitconfig_include() {
  local file=$(gitconfig_file) inc=$ROOT/$1 done=0
  ! gitconfig_is_legacy_link && gitconfig_has_include $inc && done=1
  if [[ $MODE == plan ]]; then
    plan_add "Git config" "$(tildify $file): include $1" $done
    return 0
  fi
  (( done )) && { ok "$(tildify $file) already includes $1"; return 0; }
  step "Including $1 from $(tildify $file)"
  if [[ -n ${SYS[git]} ]]; then
    run ${SYS[git]} config --file $file --add include.path $inc
  else
    gitconfig_append $file "[include]" "path = $inc"
  fi
}

# gitconfig_uninclude <repo-relative file>: for --unlink
gitconfig_uninclude() {
  local file=$(gitconfig_file) inc=$ROOT/$1
  gitconfig_has_include $inc || return 0
  step "Removing the include of $1 from $(tildify $file)"
  if [[ -n ${SYS[git]} ]]; then
    run ${SYS[git]} config --file $file --fixed-value --unset-all include.path $inc
  else
    run sed -i '' "\\|^[[:space:]]*path[[:space:]]*=[[:space:]]*\"\\{0,1\\}${inc}\"\\{0,1\\}[[:space:]]*\$|d" $file
  fi
}
