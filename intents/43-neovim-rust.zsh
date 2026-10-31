id=neovim-rust
title="Neovim · Rust"
why="The stable Rust toolchain with rust-analyzer, coc-rust-analyzer, and lldb-dap for debugging."
requires=(neovim)
packages=(
  "brew rustup"
  "rustup stable toolchain with rust-analyzer → ~/.rustup"
  "repo scripts/xcrun-tool → ~/.local/bin/lldb-dap"
  "coc coc-rust-analyzer"
)
hosts=(static.rust-lang.org)
targets=($HOME/.local/bin/lldb-dap)

apply() {
  install_packages || return 1
  local toolchains=($HOME/.rustup/toolchains/stable-*(N/)) done=0
  (( $#toolchains )) && [[ -e $toolchains[1]/bin/rust-analyzer ]] && done=1
  task "rustup" "Install the stable Rust toolchain with rust-analyzer" $done rust_install_stable || return 1
  link scripts/xcrun-tool $HOME/.local/bin/lldb-dap
}

rust_install_stable() {
  run $BREW_PREFIX/opt/rustup/bin/rustup default stable &&
    run $BREW_PREFIX/opt/rustup/bin/rustup component add rust-analyzer
}
