# Read-only facts about this Mac, gathered into $SYS, and the pre-check report.
# Nothing here installs or changes anything, and nothing calls /usr/bin/git or
# xcrun directly: on a Mac without the Command Line Tools those are stubs that
# pop up Apple's install dialog.

typeset -gA SYS HOST_OK

BREW_PREFIX=/opt/homebrew
CLT_DIR=/Library/Developer/CommandLineTools

detect_macos() {
  SYS[macos]=$(sw_vers -productVersion 2>/dev/null)
  SYS[macos_major]=${SYS[macos]%%.*}
  SYS[arch]=$(uname -m)
  SYS[rosetta]=$(sysctl -n sysctl.proc_translated 2>/dev/null || print 0)
}

# Command Line Tools: the package Homebrew needs (Xcode.app alone isn't enough)
detect_clt() {
  [[ -x $CLT_DIR/usr/bin/git ]] && SYS[clt]=$CLT_DIR || SYS[clt]=''
}

# A real git: Homebrew's, or the one in the active developer folder
detect_git() {
  local dev
  SYS[git]=''
  if [[ -x $BREW_PREFIX/bin/git ]]; then
    SYS[git]=$BREW_PREFIX/bin/git
  elif dev=$(/usr/bin/xcode-select -p 2>/dev/null) && [[ -x $dev/usr/bin/git ]]; then
    SYS[git]=$dev/usr/bin/git
  fi
}

detect_brew() {
  local dir
  SYS[brew]='' SYS[brew_owner]='' SYS[brew_writable]=0
  [[ -d $BREW_PREFIX ]] && SYS[brew_owner]=$(stat -f %Su $BREW_PREFIX)
  [[ -x $BREW_PREFIX/bin/brew ]] || return 0
  SYS[brew]=$BREW_PREFIX/bin/brew
  SYS[brew_writable]=1
  for dir in $BREW_PREFIX $BREW_PREFIX/bin $BREW_PREFIX/Cellar $BREW_PREFIX/Caskroom; do
    [[ -d $dir && ! -w $dir ]] && SYS[brew_writable]=0
  done
  return 0
}

detect_admin() {
  dseditgroup -o checkmember -m "$USER" admin >/dev/null 2>&1 && SYS[admin]=1 || SYS[admin]=0
}

detect_management() {
  SYS[jamf]=0 SYS[self_service]='' SYS[mdm]=0 SYS[santa]=''
  [[ -e /usr/local/jamf/bin/jamf || -d "/Library/Application Support/JAMF" ]] && SYS[jamf]=1
  local app
  for app in "/Applications/Self Service.app" "/Applications/Self Service+.app"; do
    [[ -d $app ]] && SYS[self_service]=$app
  done
  profiles status -type enrollment 2>/dev/null | grep -q 'MDM enrollment: Yes' && SYS[mdm]=1
  if [[ -x /usr/local/bin/santactl ]]; then
    SYS[santa]=$(/usr/local/bin/santactl status 2>/dev/null | awk -F'|' '/Mode/ {gsub(/^ +| +$/, "", $2); print $2; exit}')
    [[ -z ${SYS[santa]} ]] && SYS[santa]=unknown
  fi
}

# Who signed github.com's certificate. A proxy that inspects HTTPS (Zscaler,
# Netskope, ...) re-signs it with its own CA, which tools with their own
# certificate store (node, npm, rustup) then reject.
detect_tls() {
  SYS[tls_issuer]=$(curl -sv --max-time 8 -o /dev/null https://github.com 2>&1 |
    sed -n 's/^\*  *issuer: //p' | head -1)
  SYS[tls_org]=$(print -r -- ${SYS[tls_issuer]} | sed -n 's/.*O=\([^;]*\).*/\1/p')
  SYS[tls_intercepted]=0
  if [[ -n ${SYS[tls_issuer]} ]] && ! print -r -- ${SYS[tls_issuer]} |
      grep -qiE 'sectigo|digicert|globalsign|let.s encrypt|isrg|github|comodo|usertrust'; then
    SYS[tls_intercepted]=1
  fi
}

detect_disk() {
  SYS[disk_free_gb]=$(df -g $HOME | awk 'NR==2 {print $4}')
}

# check_hosts <host...>: any HTTP answer counts as reachable; 000 means the
# connection or TLS handshake failed
check_hosts() {
  local host tmp=$(mktemp -d)
  for host in "$@"; do
    { curl -s -o /dev/null -w '%{http_code}' --max-time 10 https://$host/ > $tmp/$host 2>/dev/null } &
  done
  wait
  for host in "$@"; do
    [[ -s $tmp/$host && $(<$tmp/$host) != 000 ]] && HOST_OK[$host]=1 || HOST_OK[$host]=0
  done
  rm -rf $tmp
}

detect_all() {
  detect_macos; detect_clt; detect_git; detect_brew; detect_admin
  detect_management; detect_tls; detect_disk
}

# foundation_installs <clt|brew>: Foundation is to install it. The plan takes
# that on trust; once applying, it counts only if Foundation finished, so the
# intents that work without brew fall back instead of running a missing one.
foundation_installs() {
  [[ ${FOUNDATION[$1]} == install && ( $MODE == plan || ${STATE[foundation]} == done ) ]]
}

# Will the Command Line Tools be there for this run (now, or once Foundation installs them)?
clt_usable() {
  [[ -n ${SYS[clt]} ]] || foundation_installs clt
}

# Can brew be used for this run? It needs the Command Line Tools too.
brew_usable() {
  clt_usable || return 1
  [[ -n ${SYS[brew]} ]] && (( SYS[brew_writable] )) && return 0
  [[ -z ${SYS[brew]} ]] && foundation_installs brew
}

brew_why_not() {
  if ! clt_usable; then
    if [[ ${FOUNDATION[clt]} == install ]]; then print "the Command Line Tools didn't install"
    elif (( USE_SUDO )); then print "the Command Line Tools won't be installed"
    else print "the Command Line Tools are missing and sudo is off"
    fi
  elif [[ -n ${SYS[brew]} ]]; then
    print "Homebrew isn't writable by you"
  elif [[ ${FOUNDATION[brew]} == install ]]; then
    print "Homebrew didn't install"
  elif (( USE_SUDO )); then
    print "Homebrew won't be installed"
  else
    print "Homebrew is missing and sudo is off"
  fi
}

print_precheck() {
  heading "Checking this Mac"

  if [[ ${SYS[arch]} == arm64 && ${SYS[rosetta]} != 1 && ${SYS[macos_major]} -ge 14 ]]; then
    ok "macOS ${SYS[macos]} on Apple Silicon"
  elif [[ ${SYS[rosetta]} == 1 ]]; then
    fail "This terminal runs under Rosetta (Intel mode). Open it natively and run again."
  else
    fail "macOS ${SYS[macos]} on ${SYS[arch]}: only Apple Silicon with macOS 14 or newer is supported"
  fi

  if (( USE_SUDO )); then
    (( SYS[admin] )) && ok "You're an administrator, so sudo should work" ||
      warn "You aren't in the admin group, so sudo will probably be refused"
  fi

  if [[ -n ${SYS[clt]} ]]; then
    ok "Command Line Tools installed"
  else
    warn "Command Line Tools missing: no git or compilers, and Homebrew can't work without them"
  fi
  if [[ -n ${SYS[git]} ]]; then
    ok "git $(${SYS[git]} --version 2>/dev/null | awk '{print $3}') at $(tildify ${SYS[git]})"
  else
    info "No git yet (it comes with the Command Line Tools)"
  fi

  if [[ -n ${SYS[brew]} ]]; then
    local version=$(HOMEBREW_NO_AUTO_UPDATE=1 ${SYS[brew]} --version 2>/dev/null | head -1)
    if (( SYS[brew_writable] )); then
      ok "${version:-Homebrew} at $BREW_PREFIX, owned by ${SYS[brew_owner]} and writable by you"
    else
      warn "${version:-Homebrew} at $BREW_PREFIX is owned by ${SYS[brew_owner]} and not writable by you"
      detail "Anything installed with brew will be skipped. Ask IT (or Self Service) to make"
      detail "$BREW_PREFIX yours; a second Homebrew elsewhere isn't supported."
    fi
  elif [[ -n ${SYS[brew_owner]} ]]; then
    warn "$BREW_PREFIX exists (owned by ${SYS[brew_owner]}) but has no Homebrew in it"
  else
    info "Homebrew not installed"
  fi
  [[ -x /usr/local/bin/brew ]] && warn "An Intel Homebrew exists in /usr/local; it's left alone and not used"

  local managed=()
  (( SYS[mdm] )) && managed+="MDM enrolled"
  (( SYS[jamf] )) && managed+="Jamf"
  [[ -n ${SYS[self_service]} ]] && managed+="${SYS[self_service]:t:r} available"
  (( $#managed )) && info "Managed Mac: ${(j: · :)managed}" || info "Not managed by an MDM"
  case ${SYS[santa]} in
    '') ;;
    Lockdown) warn "Santa is in Lockdown mode: binaries it doesn't know may be blocked from running" ;;
    *) info "Santa installed (${SYS[santa]} mode)" ;;
  esac

  if [[ -z ${SYS[tls_issuer]} ]]; then
    warn "Couldn't reach github.com over HTTPS"
  elif (( SYS[tls_intercepted] )); then
    warn "HTTPS is inspected by a proxy (github.com's certificate is signed by ${SYS[tls_org]:-${SYS[tls_issuer]}})"
    detail "Tools with their own certificate store (node, npm, rustup) may fail to download."
    detail "If they do, point NODE_EXTRA_CA_CERTS at your company's root certificate."
  else
    ok "HTTPS isn't intercepted (github.com signed by ${SYS[tls_org]})"
  fi

  (( SYS[disk_free_gb] >= 10 )) && ok "${SYS[disk_free_gb]} GB free" ||
    warn "Only ${SYS[disk_free_gb]} GB free; a full setup needs about 6 GB"

  local hosts=(${(ou)=${(j: :)I_HOSTS}}) unreachable=() host
  check_hosts $hosts
  for host in $hosts; do (( HOST_OK[$host] )) || unreachable+=$host; done
  if (( $#unreachable )); then
    warn "Can't reach: ${(j:, :)unreachable}"
    detail "Intents that download from these will probably fail; see the README's host list."
  else
    ok "All ${#hosts} download hosts reachable"
  fi

  local target conflicts=()
  for target in ${(u)ALL_TARGETS}; do
    if [[ -L $target ]]; then
      [[ ${target:A} == $ROOT/* ]] || conflicts+="$(tildify $target) (link to $(tildify $(readlink $target)))"
    elif [[ -e $target ]]; then
      conflicts+="$(tildify $target)"
    fi
  done
  if (( $#conflicts )); then
    info "Files that would be replaced if you choose their intent (backed up first):"
    for target in $conflicts; do detail "$target"; done
  fi
}
