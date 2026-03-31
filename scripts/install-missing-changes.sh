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

TARGET_DIR="$HOME/.local/bin"
TARGET_PATH="${TARGET_DIR}/missing-changes"
SOURCE_URL="https://raw.githubusercontent.com/convict-git/setup-configs/refs/heads/main/scripts/missing-changes.sh"

section "INSTALLING missing-changes"
log_info "Target Dir : ${BOLD}${TARGET_DIR}${RESET}"
log_info "Target Bin : ${BOLD}${TARGET_PATH}${RESET}"
log_info "Source URL : ${BOLD}${SOURCE_URL}${RESET}"

run_cmd "mkdir -p \"$TARGET_DIR\""
run_cmd "curl -fsSL \"$SOURCE_URL\" -o \"$TARGET_PATH\""
run_cmd "chmod +x \"$TARGET_PATH\""

log_success "Installation completed"

cat << 'EOT'

Ensure ~/.local/bin is on PATH (many distros already add it). If not:

  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc   # or ~/.bashrc

Then run from any directory:

  missing-changes --no-fetch release-A release-B abc123deadbeef...
EOT

