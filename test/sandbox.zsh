#!/bin/zsh
# Throwaway macOS VMs (Tart) for testing install.sh in isolation.
#
#   test/sandbox.zsh setup            install Tart and build the two base VMs
#   test/sandbox.zsh run <scenario>   run install.sh in a fresh clone of a base VM, then check it
#   test/sandbox.zsh new [base]       a clone to poke at by hand (base: fresh or brew)
#   test/sandbox.zsh ssh <vm> [user]  log in (user: admin or worker)
#   test/sandbox.zsh ls               VMs and disk use
#   test/sandbox.zsh clean            delete test VMs, keep the base ones
#   test/sandbox.zsh purge            delete every VM and Tart's image cache; offers to uninstall Tart
#
# Scenarios: fresh-sudo, fresh-nosudo, brew-other, brew-own (see README "Testing in a VM").
# SANDBOX_YES=1 answers yes to this script's own questions, for running it unattended.

emulate zsh
setopt extended_glob

ROOT=${0:A:h:h}
IMAGE=ghcr.io/cirruslabs/macos-tahoe-vanilla:latest
BASE_FRESH=sc-golden-fresh   # clean macOS, admin (password admin) plus standard user worker
BASE_BREW=sc-golden-brew     # plus the Command Line Tools and a Homebrew owned by admin
KEY=$ROOT/test/.sandbox/id_ed25519
SSH_OPTS=(-i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10)
GUEST_REPO='~/convict/open-source/setup-configs'
SHARE='/Volumes/My Shared Files/repo'

say()  { print -r -- "  $*" }
step() { print -u2 -r -- "  → $*" }
die()  { print -u2 -r -- "  ✗ $*"; exit 1 }

confirm() {
  local reply
  [[ $SANDBOX_YES == 1 ]] && { say "$1 yes (SANDBOX_YES)"; return 0 }
  print -n -- "  ? $1 [y/N] "
  read -r reply < /dev/tty
  [[ ${reply:l} == y(es|) ]]
}

need_tart() { (( $+commands[tart] )) || die "Tart isn't installed; run: test/sandbox.zsh setup" }

vm_exists() { tart list -q 2>/dev/null | grep -qx -- $1 }

# start <vm> [share-repo]: boots headless in the background and waits for SSH
start() {
  local vm=$1 share=$2 ip i
  step "Booting $vm"
  if [[ -n $share ]]; then
    tart run --no-graphics --dir=repo:${ROOT}:ro $vm >/dev/null 2>&1 &!
  else
    tart run --no-graphics $vm >/dev/null 2>&1 &!
  fi
  ip=$(tart ip --wait 180 $vm) || die "$vm didn't get an IP address"
  for i in {1..60}; do
    nc -z -G 2 $ip 22 2>/dev/null && { sleep 2; print -r -- $ip; return 0 }
    sleep 3
  done
  die "$vm didn't open SSH"
}

vm_state() { tart list --source local 2>/dev/null | awk -v n=$1 '$2 == n { print $NF }' }

# stop <vm> <ip>: shuts the guest down from inside, so everything it wrote
# reaches its disk (tart stop alone can cut off the last minutes of writes)
stop() {
  local vm=$1 ip=$2 i
  step "Shutting down $vm"
  ssh $SSH_OPTS admin@$ip 'sync; sudo shutdown -h now' >/dev/null 2>&1
  for i in {1..60}; do
    [[ $(vm_state $vm) == stopped ]] && return 0
    sleep 2
  done
  tart stop $vm >/dev/null 2>&1
}

# on <ip> <user> <command>: runs a command in the guest over SSH, with a terminal
on() {
  local ip=$1 user=$2; shift 2
  ssh $SSH_OPTS -tt $user@$ip "$@"
}

# Installs our key for admin, using the image's default password
install_key() {
  local ip=$1
  expect <<EOF >/dev/null
set timeout 60
spawn ssh-copy-id -i $KEY.pub -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null admin@$ip
expect {
  -re "assword:" { send "admin\r"; exp_continue }
  eof
}
EOF
}

cmd_setup() {
  local ip
  if (( ! $+commands[tart] )); then
    confirm "Install Tart with Homebrew (brew install openai/tools/tart)?" || die "Tart is needed"
    brew install openai/tools/tart || die "Couldn't install Tart"
  fi
  [[ -f $KEY ]] || { mkdir -p ${KEY:h}; ssh-keygen -q -t ed25519 -N '' -C setup-configs-sandbox -f $KEY }

  # Each base VM is built under a -wip name and renamed once it's done, so a
  # failed setup never leaves a half-built base behind
  if ! vm_exists $BASE_FRESH; then
    confirm "Download the macOS Tahoe image (about 25 GB) and build $BASE_FRESH?" || die "Stopped"
    vm_exists $BASE_FRESH-wip && tart delete $BASE_FRESH-wip
    step "Cloning $IMAGE"
    tart clone $IMAGE $BASE_FRESH-wip || die "Couldn't download the image"
    ip=$(start $BASE_FRESH-wip) || exit 1
    step "Installing the sandbox SSH key for admin"
    install_key $ip
    # verifypw=any lets install.sh's sudo -v through too; by default it still
    # asks, because admin's %admin entry in /etc/sudoers wants a password
    step "Allowing admin to sudo without a password and adding the standard user worker"
    on $ip admin "echo admin | sudo -S -p '' true &&
      printf '%s\n' 'admin ALL=(ALL) NOPASSWD: ALL' 'Defaults:admin verifypw=any' | sudo tee /etc/sudoers.d/admin >/dev/null &&
      sudo chmod 440 /etc/sudoers.d/admin && sudo -k && sudo -n -v &&
      sudo sysadminctl -addUser worker -fullName Worker -password worker -home /Users/worker &&
      sudo createhomedir -c -u worker >/dev/null &&
      sudo mkdir -p /Users/worker/.ssh && sudo cp ~/.ssh/authorized_keys /Users/worker/.ssh/ &&
      sudo chown -R worker:staff /Users/worker/.ssh && sudo chmod 700 /Users/worker/.ssh &&
      (dseditgroup -o read com.apple.access_ssh >/dev/null 2>&1 && sudo dseditgroup -o edit -a worker -t user com.apple.access_ssh || true)" ||
      die "Couldn't prepare $BASE_FRESH"
    on $ip worker true || die "worker can't log in over SSH"
    stop $BASE_FRESH-wip $ip
    tart rename $BASE_FRESH-wip $BASE_FRESH
  fi

  if ! vm_exists $BASE_BREW; then
    step "Building $BASE_BREW from $BASE_FRESH"
    vm_exists $BASE_BREW-wip && tart delete $BASE_BREW-wip
    tart clone $BASE_FRESH $BASE_BREW-wip || die "Couldn't clone $BASE_FRESH"
    ip=$(start $BASE_BREW-wip) || exit 1
    step "Installing the Command Line Tools and Homebrew as admin"
    on $ip admin 'touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress &&
      label=$(softwareupdate -l 2>/dev/null | sed -n "s/^.*\* Label: \(Command Line Tools.*\)$/\1/p" | sort -V | tail -1) &&
      sudo softwareupdate --install "$label" &&
      rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress &&
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &&
      /opt/homebrew/bin/brew --version' ||
      die "Couldn't install the Command Line Tools and Homebrew in $BASE_BREW"
    stop $BASE_BREW-wip $ip
    tart rename $BASE_BREW-wip $BASE_BREW
  fi
  say "✓ Base VMs ready: $BASE_FRESH, $BASE_BREW"
}

# The answers each scenario runs with: every intent yes
answers_for() {
  local sudo=$1 id
  print "use_sudo=$sudo"
  print "install_clt=y"
  print "install_brew=y"
  print "git_name='Sandbox Tester'"
  print "git_email=sandbox@example.com"
  for id in core_cli deimos_font git_config git_aliases zsh nvm yazi yazi_previews neovim \
            neovim_ts neovim_cpp neovim_rust iterm2 vscode; do
    print "intent_$id=y"
  done
}

cmd_run() {
  local scenario=$1 base user sudo vm ip rc
  case $scenario in
    fresh-sudo)   base=$BASE_FRESH user=admin  sudo=y ;;
    fresh-nosudo) base=$BASE_FRESH user=worker sudo=n ;;
    brew-other)   base=$BASE_BREW  user=worker sudo=n ;;
    brew-own)     base=$BASE_BREW  user=admin  sudo=n ;;
    *) die "Unknown scenario '$scenario'. Pick one of: fresh-sudo fresh-nosudo brew-other brew-own" ;;
  esac
  need_tart
  vm_exists $base || die "$base is missing; run: test/sandbox.zsh setup"
  vm=sc-$scenario-$(date +%H%M%S)
  step "Cloning $base as $vm"
  tart clone $base $vm || die "Couldn't clone $base"
  ip=$(start $vm share) || exit 1

  # The share is mounted for admin (the logged-in user) only, so admin copies it
  step "Copying this repo (with uncommitted changes) into $user's home"
  on $ip admin "for i in {1..30}; do [ -d '$SHARE' ] && break; sleep 2; done
    dest=/Users/$user/${GUEST_REPO#\~/}
    sudo mkdir -p \${dest%/*} && sudo ditto '$SHARE' \$dest && sudo rm -rf \${dest:?}/test/.sandbox &&
    sudo chown -R ${user}:staff /Users/$user/${${GUEST_REPO#\~/}%%/*}" >/dev/null ||
    die "Couldn't copy the repo"
  answers_for $sudo | ssh $SSH_OPTS $user@$ip "cat > /tmp/answers.env" || die "Couldn't write the answers"

  step "Running install.sh as $user (sudo: $sudo)"
  on $ip $user "zsh $GUEST_REPO/install.sh --answers /tmp/answers.env"
  rc=$?
  say "install.sh exited with $rc"

  step "Checking the result"
  on $ip $user "zsh $GUEST_REPO/test/checks.zsh $scenario"
  rc=$?
  print
  say "VM kept for a look: test/sandbox.zsh ssh $vm $user (delete with: test/sandbox.zsh clean)"
  return $rc
}

cmd_new() {
  local base=$BASE_FRESH vm ip
  [[ $1 == brew ]] && base=$BASE_BREW
  need_tart
  vm=sc-manual-$(date +%H%M%S)
  tart clone $base $vm || die "Couldn't clone $base"
  ip=$(start $vm share) || exit 1
  say "✓ $vm is running at $ip. The repo is shared at '$SHARE'."
  say "  Log in: test/sandbox.zsh ssh $vm [admin|worker]"
}

cmd_ssh() {
  local vm=${1:?usage: ssh <vm> [user]} user=${2:-admin} ip
  need_tart
  ip=$(tart ip $vm 2>/dev/null) || die "$vm isn't running"
  exec ssh $SSH_OPTS $user@$ip
}

cmd_ls() {
  need_tart
  tart list
  print
  du -sh ${TART_HOME:-$HOME/.tart}/{vms,cache} 2>/dev/null
}

cmd_clean() {
  local vm
  need_tart
  for vm in ${(f)"$(tart list -q --source local 2>/dev/null)"}; do
    [[ $vm == sc-* && $vm != ($BASE_FRESH|$BASE_BREW) ]] || continue
    step "Deleting $vm"
    tart stop $vm >/dev/null 2>&1
    tart delete $vm
  done
  say "✓ Clean. Base VMs kept."
}

cmd_purge() {
  local vm
  need_tart
  confirm "Delete every sandbox VM, including the base ones, and Tart's image cache?" || return 0
  for vm in ${(f)"$(tart list -q --source local 2>/dev/null)"}; do
    [[ $vm == sc-* ]] || continue
    step "Deleting $vm"
    tart stop $vm >/dev/null 2>&1
    tart delete $vm
  done
  step "Pruning Tart's cache"
  tart prune --entries=caches --older-than=0 >/dev/null 2>&1
  rm -rf ${KEY:h}
  if confirm "Uninstall Tart too?"; then brew uninstall openai/tools/tart; fi
  say "✓ Purged"
}

case $1 in
  setup|run|new|ssh|ls|clean|purge) cmd=$1; shift; cmd_$cmd "$@" ;;
  *) sed -n '2,13s/^# \{0,1\}//p' $0; exit 2 ;;
esac
