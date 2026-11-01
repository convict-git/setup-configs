# Loads intents/*.zsh, asks which to set up, shows the plan, applies it and
# summarises. See intents/README.md for what an intent file declares.

typeset -ga INTENT_IDS ALL_TARGETS
typeset -gA I_TITLE I_WHY I_REQUIRES I_SOFT I_HOSTS I_PACKAGES I_BEHIND I_SUDO I_TARGETS I_ALWAYS
typeset -gA STATE REASON   # STATE: chosen declined unavailable done failed skipped
typeset -g CUR             # the intent being processed, for caution()
typeset -g WHY_NOT         # set by an intent's available() when it returns 1

# Hosts every brew install talks to: formula metadata, and bottles (with their redirect)
BREW_HOSTS=(formulae.brew.sh ghcr.io pkg-containers.githubusercontent.com)

load_intents() {
  local file fn line host
  local -a extra_hosts
  local id title why always
  local -a requires works_best_with hosts packages behind sudo_steps targets cask_apps
  for file in $ROOT/intents/<->-*.zsh(n); do
    id='' title='' why='' always=0
    requires=() works_best_with=() hosts=() packages=() behind=() sudo_steps=() targets=() cask_apps=()
    for fn in available ask apply finish; do unfunction $fn 2>/dev/null; done
    source $file
    INTENT_IDS+=$id
    I_TITLE[$id]=$title I_WHY[$id]=$why I_ALWAYS[$id]=$always
    I_REQUIRES[$id]=${(j: :)requires} I_SOFT[$id]=${(j: :)works_best_with}
    # brew and cask lines add Homebrew's hosts and each cask's download host
    extra_hosts=()
    for line in $packages; do
      [[ $line == (brew|cask)\ * ]] && extra_hosts+=($BREW_HOSTS)
      [[ $line == cask\ * ]] || continue
      host=$(inventory_get cask-host ${${line#cask }%% *})
      [[ $host == github.com ]] && extra_hosts+=(github.com release-assets.githubusercontent.com) ||
        { [[ -n $host ]] && extra_hosts+=$host }
    done
    extra_hosts=($hosts $extra_hosts)
    I_HOSTS[$id]=${(j: :)${(u)extra_hosts}}
    I_SUDO[$id]=${(pj:\n:)sudo_steps}
    I_PACKAGES[$id]=${(pj:\n:)packages} I_BEHIND[$id]=${(pj:\n:)behind}
    I_TARGETS[$id]=${(pj:\n:)targets}
    ALL_TARGETS+=($targets)
    (( $#cask_apps )) && CASK_APPS+=($cask_apps)
    for fn in available ask apply finish; do
      (( $+functions[$fn] )) && functions[$fn:$id]=$functions[$fn] && unfunction $fn
    done
  done
}

# A short one-line summary of an intent's packages, for the question screen
packages_summary() {
  local id=$1 line kind rest
  local -A by_kind
  local -a kinds
  for line in ${(f)I_PACKAGES[$id]}; do
    kind=${line%% *} rest=${line#* }
    (( ${kinds[(Ie)$kind]} )) || kinds+=$kind
    by_kind[$kind]+="${by_kind[$kind]:+ · }${rest%% \(*}"
  done
  for kind in $kinds; do detail "${(r:11:)kind}${by_kind[$kind]}"; done
}

answer_key() { print -r -- "intent_${1//-/_}" }

# Decides one intent: unavailable, declined or chosen
choose_intent() {
  local id=$1 dep key=$(answer_key $1) default
  CUR=$id
  sub "${I_TITLE[$id]}"
  detail "${I_WHY[$id]}"
  packages_summary $id

  for dep in ${=I_REQUIRES[$id]}; do
    if [[ ${STATE[$dep]} != chosen ]]; then
      STATE[$id]=unavailable
      [[ ${STATE[$dep]} == declined ]] && REASON[$id]="needs ${I_TITLE[$dep]}, which you declined" ||
        REASON[$id]="needs ${I_TITLE[$dep]}, which isn't available"
      info "Skipped: ${REASON[$id]}"
      return
    fi
  done
  WHY_NOT=''
  if (( $+functions[available:$id] )) && ! available:$id; then
    STATE[$id]=unavailable REASON[$id]=$WHY_NOT
    info "Skipped: ${REASON[$id]}"
    return
  fi

  if (( I_ALWAYS[$id] )); then
    STATE[$id]=chosen
  else
    default=${ANS[$key]:-y}
    if (( NONINTERACTIVE )); then
      [[ $default == y ]] && STATE[$id]=chosen || STATE[$id]=declined
      info "${I_TITLE[$id]}: ${${default/y/yes}/n/no} (from answers file)"
    elif ask_yn "Set up ${I_TITLE[$id]}?" $default; then
      STATE[$id]=chosen
    else
      STATE[$id]=declined
    fi
    ANS[$key]=${${STATE[$id]/chosen/y}/declined/n}
  fi

  [[ ${STATE[$id]} == chosen ]] && (( $+functions[ask:$id] )) && ask:$id
  return 0
}

choose_all() {
  heading "Choose what to set up"
  detail "Each item says what it installs. Items others depend on come first."
  local id dep
  for id in $INTENT_IDS; do choose_intent $id; done
  for id in $INTENT_IDS; do
    [[ ${STATE[$id]} == chosen ]] || continue
    for dep in ${=I_SOFT[$id]}; do
      [[ ${STATE[$dep]} == chosen ]] || { print; info "${I_TITLE[$id]} works best with ${I_TITLE[$dep]}, which isn't chosen" }
    done
  done
}

# Plan groups in this order; any other group follows
PLAN_GROUP_ORDER=("Apple (sudo)" "Homebrew (sudo)" "Homebrew formulae" "Homebrew casks" "Git clones"
  "Node.js" "npm" "rustup" "Neovim" "Links" "Files" "Git config" "iTerm2" "Cautions")

# Installs the brew formulae and casks listed in the current intent's packages
install_packages() {
  local line formulae=() casks=()
  for line in ${(f)I_PACKAGES[$CUR]}; do
    case ${line%% *} in
      brew) formulae+=${${line#brew }%% *} ;;
      cask) casks+=${${line#cask }%% *} ;;
    esac
  done
  (( $#formulae )) && { brew_install $formulae || return 1 }
  (( $#casks )) && { cask_install $casks || return 1 }
  return 0
}

show_plan() {
  local id group
  PLAN_ORDER=() PLAN=()
  MODE=plan
  for id in $INTENT_IDS; do
    [[ ${STATE[$id]} == chosen ]] || continue
    CUR=$id
    apply:$id
  done
  for id in $INTENT_IDS; do
    [[ ${STATE[$id]} == chosen ]] && (( $+functions[finish:$id] )) || continue
    CUR=$id
    finish:$id
  done
  heading "The plan"
  if (( ! $#PLAN_ORDER )); then
    detail "Nothing to do."
    return 1
  fi
  detail "${C[blue]}+${C[grey]} will be done   ${C[green]}✓${C[grey]} already done"
  local ordered=(${PLAN_GROUP_ORDER:*PLAN_ORDER} ${PLAN_ORDER:|PLAN_GROUP_ORDER})
  for group in $ordered; do
    sub $group
    print -n -- ${PLAN[$group]}
    log_line "${PLAN[$group]}"
  done
  (( ${+PLAN[Links]} || ${+PLAN[Files]} )) && { print; detail "Anything replaced is moved to $(tildify $BACKUP_DIR) first." }
  return 0
}

# Applies chosen intents in order; an intent whose dependency failed is skipped
apply_all() {
  local id dep failed_dep
  for id in $INTENT_IDS; do
    [[ ${STATE[$id]} == chosen ]] || continue
    CUR=$id failed_dep=''
    for dep in ${=I_REQUIRES[$id]}; do
      [[ ${STATE[$dep]} == done ]] || failed_dep=$dep
    done
    heading "${I_TITLE[$id]}"
    if [[ -n $failed_dep ]]; then
      STATE[$id]=skipped REASON[$id]="${I_TITLE[$failed_dep]} didn't finish"
      warn "Skipped: ${REASON[$id]}"
      continue
    fi
    if apply:$id; then
      STATE[$id]=done
    else
      STATE[$id]=failed REASON[$id]="see the log"
      fail "${I_TITLE[$id]} didn't finish"
    fi
  done
  for id in $INTENT_IDS; do
    [[ ${STATE[$id]} == done ]] && (( $+functions[finish:$id] )) || continue
    CUR=$id
    heading "${I_TITLE[$id]}: finishing"
    finish:$id || { STATE[$id]=failed REASON[$id]="its final step failed; see the log"; fail "${I_TITLE[$id]} didn't finish" }
  done
}

summarize() {
  local id line
  heading "Summary"
  for id in $INTENT_IDS; do
    case ${STATE[$id]} in
      done)        ok "${I_TITLE[$id]}" ;;
      failed)      fail "${I_TITLE[$id]}: failed (${REASON[$id]})" ;;
      skipped|unavailable) info "${I_TITLE[$id]}: skipped, ${REASON[$id]}" ;;
      declined)    info "${I_TITLE[$id]}: not chosen" ;;
    esac
  done
  if (( $#CAUTIONS )); then
    sub "Worth knowing"
    for line in $CAUTIONS; do warn $line; done
  fi
}
