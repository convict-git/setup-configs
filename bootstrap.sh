#!/bin/zsh
# One-line setup for a Mac that doesn't have this repo (or git) yet:
#
#   zsh -c "$(curl -fsSL https://raw.githubusercontent.com/convict-git/setup-configs/main/bootstrap.sh)"
#
# Downloads the repo as a tarball, which needs no git, and runs install.sh. Once
# git is installed, install.sh turns the folder into a git clone.
# SETUP_CONFIGS_REF=<branch> downloads another branch.

emulate zsh
setopt pipe_fail
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
  # The commit the branch is at now: install.sh later makes the folder a clone of
  # exactly that, even if the branch moves on meanwhile. Without it (the GitHub
  # API unreachable) the branch is downloaded as it is.
  sha=$(curl -fsSL -H 'Accept: application/vnd.github.sha' https://api.github.com/repos/convict-git/setup-configs/commits/$ref 2>/dev/null)
  [[ $sha =~ '^[0-9a-f]{40}$' ]] || sha=''
  print "  → Downloading $ref${sha:+ at ${sha[1,7]}} into $dir"
  # Unpacked next to $dir and moved in once complete: an interrupted download
  # would otherwise leave a partial copy that the next run takes as whole
  mkdir -p ${dir:h} && tmp=$(mktemp -d "${dir:h}/.setup-configs-download.XXXXXX") ||
    { print -u2 "  ✗ Couldn't create a folder in ${dir:h}"; exit 1 }
  trap 'rm -rf $tmp; exit 130' INT
  if ! { curl -fsSL https://github.com/convict-git/setup-configs/archive/${sha:-refs/heads/$ref}.tar.gz |
           tar -xz -C $tmp --strip-components 1 &&
         print -rl -- $ref $sha > $tmp/.setup-configs-source &&
         { rmdir $dir 2>/dev/null; mv $tmp $dir } }; then
    rm -rf $tmp
    print -u2 "  ✗ Download failed"
    exit 1
  fi
fi

exec zsh $dir/install.sh "$@"
