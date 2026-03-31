#!/usr/bin/env bash

set -euo pipefail

#############################################
# Colors & Styles
#############################################
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

#############################################
# Logging helpers
#############################################
section() {
  echo
  echo -e "${CYAN}============================================================${RESET}"
  echo -e "${BOLD}$1${RESET}"
  echo -e "${CYAN}============================================================${RESET}"
}

log_info()    { echo -e "${BLUE}[INFO]${RESET} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }

log_cmd() {
  echo -e "${MAGENTA}[CMD]${RESET} ${BOLD}$1${RESET}"
}

run_cmd() {
  log_cmd "$*"
  eval "$@"
}

#############################################
# Argument parsing
#############################################
NO_FETCH=false
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --no-fetch)
      NO_FETCH=true
      ;;
    *)
      POSITIONAL+=("$arg")
      ;;
  esac
done

#############################################
# Input validation
#############################################
section "INPUT VALIDATION"

if [[ ${#POSITIONAL[@]} -ne 3 ]]; then
  log_error "Invalid arguments."
  echo -e "${BOLD}Usage:${RESET} $0 [--no-fetch] <source-branch> <target-branch> <commit-hash>"
  exit 1
fi

SOURCE_BRANCH="${POSITIONAL[0]}"
TARGET_BRANCH="${POSITIONAL[1]}"
COMMIT_HASH="${POSITIONAL[2]}"

SOURCE_REMOTE="origin/${SOURCE_BRANCH}"
TARGET_REMOTE="origin/${TARGET_BRANCH}"

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"
DIFF_FILE="branch-diff_${SOURCE_BRANCH}_vs_${TARGET_BRANCH}_${COMMIT_HASH}.diff"

# Track files that actually had differences (for summary breakdown)
SUMMARY_DELETED=()
SUMMARY_RENAMED=()
SUMMARY_ADDED=()
SUMMARY_ADDED_ADD_TOTAL=0
SUMMARY_MODIFIED=()
SUMMARY_MODIFIED_ADD_TOTAL=0
SUMMARY_MODIFIED_DEL_TOTAL=0

log_info "Source Branch : ${BOLD}${SOURCE_BRANCH}${RESET}"
log_info "Target Branch : ${BOLD}${TARGET_BRANCH}${RESET}"
log_info "Commit Hash  : ${BOLD}${COMMIT_HASH}${RESET}"
log_info "Diff Output  : ${BOLD}${DIFF_FILE}${RESET}"
if [[ "$NO_FETCH" == true ]]; then
  log_info "Fetch        : ${BOLD}skipped (--no-fetch)${RESET}"
fi

#############################################
# Fetch branches
#############################################
if [[ "$NO_FETCH" == true ]]; then
  section "FETCH (SKIPPED)"
  log_info "Skipping ${BOLD}git fetch${RESET} because ${BOLD}--no-fetch${RESET} was passed."
else
  section "FETCHING BRANCHES FROM ORIGIN"

  run_cmd "git fetch origin ${SOURCE_BRANCH}"
  run_cmd "git fetch origin ${TARGET_BRANCH}"
fi

#############################################
# Commit presence on branches
#############################################
section "COMMIT PRESENCE ON BRANCHES"

check_commit_present_in_branch() {
  local commit="$1"
  local branch="$2"

  if git merge-base --is-ancestor "$commit" "$branch"; then
    log_success "Commit ${commit} IS present in ${branch}"
    return 0
  else
    log_warn "Commit ${commit} is NOT present in ${branch}"
    return 1
  fi
}

SOURCE_PRESENT=false
TARGET_PRESENT=false

check_commit_present_in_branch "$COMMIT_HASH" "$SOURCE_REMOTE" && SOURCE_PRESENT=true
check_commit_present_in_branch "$COMMIT_HASH" "$TARGET_REMOTE" && TARGET_PRESENT=true

#############################################
# Files in commit
#############################################
section "FILES CHANGED IN COMMIT"

FILES=$(git diff-tree --no-commit-id --name-only -r "$COMMIT_HASH")

if [[ -z "$FILES" ]]; then
  log_warn "No files found in commit ${COMMIT_HASH}"
  exit 0
fi

echo -e "${BOLD}Changed Files in ${COMMIT_HASH}:${RESET}"
echo "$FILES"

#############################################
# Diff collection
#############################################
section "COLLECTING DIFFS (SAFE MODE)"

# Fresh output each run (avoid appending stale full diffs from older invocations)
: > "${DIFF_FILE}"

for file in $FILES; do
  log_info "Processing file: ${BOLD}${file}${RESET}"

  STATUS_LINE=$(git diff --name-status "$SOURCE_REMOTE..$TARGET_REMOTE" -- "$file" || true)

  if [[ -z "$STATUS_LINE" ]]; then
    log_success "No diff found for ${file}"
    continue
  fi

  STATUS=$(echo "$STATUS_LINE" | awk '{print $1}')

  {
    echo "================================================================================"
    echo "Timestamp      : ${TIMESTAMP}"
    echo "Commit         : ${COMMIT_HASH}"
    echo "Source Branch  : ${SOURCE_REMOTE}"
    echo "Target Branch  : ${TARGET_REMOTE}"
    echo "File           : ${file}"
  } >> "${DIFF_FILE}"

  if [[ "$STATUS" == "D" ]]; then
    NUMSTAT_LINE_D=$(git diff --numstat "${SOURCE_REMOTE}..${TARGET_REMOTE}" -- "$file" | head -n1 || true)
    added_raw_d=""
    deleted_raw_d=""
    if [[ -n "$NUMSTAT_LINE_D" ]]; then
      added_raw_d="$(echo "$NUMSTAT_LINE_D" | awk '{print $1}')"
      deleted_raw_d="$(echo "$NUMSTAT_LINE_D" | awk '{print $2}')"
    fi
    if [[ -n "$added_raw_d" && "$added_raw_d" != "-" && -n "$deleted_raw_d" && "$deleted_raw_d" != "-" ]]; then
      SUMMARY_DELETED+=("$file (+${added_raw_d} / -${deleted_raw_d})")
    elif [[ "$added_raw_d" == "-" || "$deleted_raw_d" == "-" ]]; then
      SUMMARY_DELETED+=("$file (binary)")
    else
      SUMMARY_DELETED+=("$file")
    fi
    {
      echo "Status         : DELETED"
      if [[ -n "$added_raw_d" && "$added_raw_d" != "-" && -n "$deleted_raw_d" && "$deleted_raw_d" != "-" ]]; then
        echo "Numstat        : +${added_raw_d} / -${deleted_raw_d} (per git diff --numstat)"
      elif [[ "$added_raw_d" == "-" || "$deleted_raw_d" == "-" ]]; then
        echo "Numstat        : binary (per git diff --numstat)"
      fi
      echo "Note           : File was deleted between refs. Diff content intentionally omitted."
      echo "================================================================================"
      echo
    } >> "${DIFF_FILE}"

    log_warn "File deleted — diff content skipped"
    continue
  fi

  if [[ "$STATUS" == R* ]]; then
    # Rename lines: R100<tab>old<tab>new (tabs; paths may contain spaces)
    rename_from=""
    rename_to=""
    if [[ "$STATUS_LINE" == *$'\t'* ]]; then
      rename_from="$(printf '%s\n' "$STATUS_LINE" | cut -f2)"
      rename_to="$(printf '%s\n' "$STATUS_LINE" | cut -f3)"
    else
      rename_from="$(echo "$STATUS_LINE" | awk '{print $2}')"
      rename_to="$(echo "$STATUS_LINE" | awk '{print $3}')"
    fi
    SUMMARY_RENAMED+=("${rename_from} → ${rename_to}")
    {
      echo "Status         : RENAMED / MOVED"
      echo "Note           : File was renamed/moved. Diff content intentionally omitted."
      echo "================================================================================"
      echo
    } >> "${DIFF_FILE}"

    log_warn "File renamed/moved — diff content skipped"
    continue
  fi

  if [[ "$STATUS" == "A" ]]; then
    NUMSTAT_LINE_A=$(git diff --numstat "${SOURCE_REMOTE}..${TARGET_REMOTE}" -- "$file" | head -n1 || true)
    added_raw_a=""
    deleted_raw_a=""
    if [[ -n "$NUMSTAT_LINE_A" ]]; then
      added_raw_a="$(echo "$NUMSTAT_LINE_A" | awk '{print $1}')"
      deleted_raw_a="$(echo "$NUMSTAT_LINE_A" | awk '{print $2}')"
    fi
    if [[ "$added_raw_a" == "-" || "$deleted_raw_a" == "-" ]]; then
      SUMMARY_ADDED+=("$file (binary)")
    elif [[ -n "$added_raw_a" && -n "$deleted_raw_a" ]]; then
      SUMMARY_ADDED+=("$file (+${added_raw_a} / -${deleted_raw_a})")
      SUMMARY_ADDED_ADD_TOTAL=$((SUMMARY_ADDED_ADD_TOTAL + added_raw_a))
    else
      SUMMARY_ADDED+=("$file")
    fi
    {
      echo "Status         : ADDED"
      if [[ -n "$added_raw_a" && "$added_raw_a" != "-" && -n "$deleted_raw_a" && "$deleted_raw_a" != "-" ]]; then
        echo "Numstat        : +${added_raw_a} / -${deleted_raw_a} (per git diff --numstat)"
      fi
      echo "Note           : File was added between refs. Diff content intentionally omitted."
      echo "================================================================================"
      echo
    } >> "${DIFF_FILE}"

    log_warn "File added — diff content skipped"
    continue
  fi

  NUMSTAT_LINE=$(git diff --numstat "${SOURCE_REMOTE}..${TARGET_REMOTE}" -- "$file" | head -n1 || true)
  added_raw=""
  deleted_raw=""
  if [[ -n "$NUMSTAT_LINE" ]]; then
    added_raw="$(echo "$NUMSTAT_LINE" | awk '{print $1}')"
    deleted_raw="$(echo "$NUMSTAT_LINE" | awk '{print $2}')"
  fi
  if [[ "$added_raw" == "-" || "$deleted_raw" == "-" ]]; then
    SUMMARY_MODIFIED+=("$file (binary)")
  elif [[ -n "$added_raw" && -n "$deleted_raw" ]]; then
    SUMMARY_MODIFIED+=("$file (+${added_raw} / -${deleted_raw})")
    SUMMARY_MODIFIED_ADD_TOTAL=$((SUMMARY_MODIFIED_ADD_TOTAL + added_raw))
    SUMMARY_MODIFIED_DEL_TOTAL=$((SUMMARY_MODIFIED_DEL_TOTAL + deleted_raw))
  else
    SUMMARY_MODIFIED+=("$file")
  fi

  {
    echo "Status         : MODIFIED"
    echo "================================================================================"
    git diff "${SOURCE_REMOTE}..${TARGET_REMOTE}" -- "${file}"
    echo
  } >> "${DIFF_FILE}"

  log_success "Diff appended for ${file}"
done

#############################################
# Final summary
#############################################
section "FINAL SUMMARY"

log_info "Commit present on each branch:"
echo -e "  ${SOURCE_REMOTE} → ${BOLD}${SOURCE_PRESENT}${RESET}"
echo -e "  ${TARGET_REMOTE} → ${BOLD}${TARGET_PRESENT}${RESET}"

echo
log_info "Files with differences:"

total_diff_files=$((${#SUMMARY_DELETED[@]} + ${#SUMMARY_RENAMED[@]} + ${#SUMMARY_ADDED[@]} + ${#SUMMARY_MODIFIED[@]}))

if [[ "$total_diff_files" -eq 0 ]]; then
  echo -e "  ${GREEN}None${RESET}"
else
  echo -e "  ${BOLD}Total:${RESET} ${total_diff_files} file(s) differ between ${SOURCE_REMOTE} and ${TARGET_REMOTE}"

  if [[ ${#SUMMARY_DELETED[@]} -gt 0 ]]; then
    echo
    echo -e "  ${BOLD}Deleted (${#SUMMARY_DELETED[@]}):${RESET}"
    for f in "${SUMMARY_DELETED[@]}"; do
      echo -e "    - ${BOLD}${f}${RESET}"
    done
  fi

  if [[ ${#SUMMARY_RENAMED[@]} -gt 0 ]]; then
    echo
    echo -e "  ${BOLD}Renamed / moved (${#SUMMARY_RENAMED[@]}):${RESET}"
    for line in "${SUMMARY_RENAMED[@]}"; do
      echo -e "    - ${line}"
    done
  fi

  if [[ ${#SUMMARY_ADDED[@]} -gt 0 ]]; then
    echo
    echo -e "  ${BOLD}Added (${#SUMMARY_ADDED[@]}):${RESET}"
    for line in "${SUMMARY_ADDED[@]}"; do
      echo -e "    - ${line}"
    done
    if [[ "$SUMMARY_ADDED_ADD_TOTAL" -gt 0 ]]; then
      echo
      echo -e "    ${BOLD}Insertions (added, text only):${RESET} +${SUMMARY_ADDED_ADD_TOTAL}"
    fi
  fi

  if [[ ${#SUMMARY_MODIFIED[@]} -gt 0 ]]; then
    echo
    echo -e "  ${BOLD}Modified (${#SUMMARY_MODIFIED[@]}):${RESET}"
    for line in "${SUMMARY_MODIFIED[@]}"; do
      echo -e "    - ${line}"
    done
    if [[ "$SUMMARY_MODIFIED_ADD_TOTAL" -gt 0 || "$SUMMARY_MODIFIED_DEL_TOTAL" -gt 0 ]]; then
      echo
      echo -e "    ${BOLD}Line delta (modified, text only):${RESET} +${SUMMARY_MODIFIED_ADD_TOTAL} / -${SUMMARY_MODIFIED_DEL_TOTAL}"
    fi
  fi
fi

echo
log_success "Script execution completed"

log_info "All collected diffs are available at:"
echo -e "  ${BOLD}${DIFF_FILE}${RESET}"

section "END"

