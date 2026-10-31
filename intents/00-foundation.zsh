# Apple's Command Line Tools and Homebrew. Always part of the setup: when they're
# already installed there's nothing to do; when missing, installing either needs sudo.

id=foundation
title="Foundation"
why="Apple's Command Line Tools (git, compilers) and Homebrew. Everything installed with brew needs both."
always=1
packages=(
  "apple Command Line Tools (git, clang, clangd, clang-format, lldb-dap), only if missing"
  "official Homebrew into /opt/homebrew, only if missing"
)
sudo_steps=(
  "Install the Command Line Tools with softwareupdate"
  "Install Homebrew into /opt/homebrew with its official installer"
)
hosts=(swscan.apple.com swcdn.apple.com raw.githubusercontent.com github.com)

ask() {
  if [[ -n ${SYS[clt]} ]]; then
    FOUNDATION[clt]=present
    ok "Command Line Tools: installed"
  elif (( USE_SUDO )); then
    if (( NONINTERACTIVE )); then
      [[ ${ANS[install_clt]:-y} == y ]] && FOUNDATION[clt]=install || FOUNDATION[clt]=skip
    elif ask_yn "Install the Command Line Tools now? (sudo, about 1 GB)" ${ANS[install_clt]:-y}; then
      FOUNDATION[clt]=install
    else
      FOUNDATION[clt]=skip
    fi
    ANS[install_clt]=${${FOUNDATION[clt]/install/y}/skip/n}
  else
    FOUNDATION[clt]=missing
    warn "Command Line Tools missing and sudo is off: everything that needs git, compilers or Homebrew is skipped"
    detail "Install them from Self Service (or ask IT), then run this again."
  fi

  if [[ -n ${SYS[brew]} ]]; then
    if (( SYS[brew_writable] )); then
      FOUNDATION[brew]=present
      ok "Homebrew: installed and writable by you"
    else
      FOUNDATION[brew]=readonly
      warn "Homebrew belongs to ${SYS[brew_owner]}, so everything installed with brew is skipped"
      detail "Ask IT (or use Self Service) to make $BREW_PREFIX yours."
    fi
  elif (( USE_SUDO )) && clt_usable; then
    if (( NONINTERACTIVE )); then
      [[ ${ANS[install_brew]:-y} == y ]] && FOUNDATION[brew]=install || FOUNDATION[brew]=skip
    elif ask_yn "Install Homebrew into $BREW_PREFIX now? (sudo)" ${ANS[install_brew]:-y}; then
      FOUNDATION[brew]=install
    else
      FOUNDATION[brew]=skip
    fi
    ANS[install_brew]=${${FOUNDATION[brew]/install/y}/skip/n}
  else
    FOUNDATION[brew]=missing
    warn "Homebrew can't be installed: $(brew_why_not)"
  fi
}

apply() {
  if [[ ${FOUNDATION[clt]} == install ]]; then
    task "Apple (sudo)" "Install the Command Line Tools" 0 foundation_install_clt || return 1
  fi
  if [[ ${FOUNDATION[brew]} == install ]]; then
    task "Homebrew (sudo)" "Install Homebrew into $BREW_PREFIX" 0 foundation_install_brew || return 1
  fi
  return 0
}

# The same headless route Homebrew's own installer takes: this marker file makes
# softwareupdate list the Command Line Tools
foundation_install_clt() {
  local marker=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress label
  sudo_ready || return 1
  run touch $marker || return 1
  if [[ $MODE == dry ]]; then
    label="Command Line Tools for Xcode-<latest>"
  else
    detail "Looking up the latest Command Line Tools (this takes a moment)"
    label=$(softwareupdate -l 2>/dev/null | sed -n 's/^.*\* Label: \(Command Line Tools.*\)$/\1/p' | sort -V | tail -1)
  fi
  if [[ -z $label ]]; then
    run rm -f $marker
    fail "softwareupdate didn't offer the Command Line Tools; install them with: xcode-select --install"
    return 1
  fi
  run sudo softwareupdate --install $label --verbose
  local rc=$?
  run rm -f $marker
  [[ $MODE == dry ]] && return 0
  detect_clt; detect_git
  (( rc == 0 )) && [[ -n ${SYS[clt]} ]]
}

foundation_install_brew() {
  local script=$(mktemp)
  sudo_ready || return 1
  run curl -fsSL -o $script https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh || return 1
  run env NONINTERACTIVE=1 /bin/bash $script
  local rc=$?
  rm -f $script
  [[ $MODE == dry ]] && return 0
  detect_brew; detect_git
  (( rc == 0 )) && [[ -n ${SYS[brew]} ]]
}
