#!/bin/zsh
# One-line setup for a Mac that doesn't have this repo (or git) yet:
#
#   zsh -c "$(curl -fsSL https://raw.githubusercontent.com/convict-git/setup-configs/main/bootstrap.sh)"
#
# Downloads the repo as a tarball, which needs no git, and runs install.sh. Once
# git is installed, install.sh turns the folder into a git clone.
# SETUP_CONFIGS_REF=<branch> downloads another branch.

emulate zsh
ref=${SETUP_CONFIGS_REF:-main}
default=$HOME/convict/open-source/setup-configs

print
print "  setup-configs bootstrap"
print -n "  ? Where should the repo go? [${default/#$HOME/~}] "
read -r dir < /dev/tty
dir=${${dir:-$default}/#\~/$HOME}

if [[ -f $dir/install.sh ]]; then
  print "  · Using the copy already in $dir"
else
  if [[ -d $dir && -n $(ls -A $dir) ]]; then
    print -u2 "  ✗ $dir isn't empty. Run again and pick another folder."
    exit 1
  fi
  print "  → Downloading $ref into $dir"
  mkdir -p $dir &&
    curl -fsSL https://github.com/convict-git/setup-configs/archive/refs/heads/$ref.tar.gz |
    tar -xz -C $dir --strip-components 1 || { print -u2 "  ✗ Download failed"; exit 1 }
  print -r -- $ref > $dir/.setup-configs-source
fi

exec zsh $dir/install.sh "$@"
