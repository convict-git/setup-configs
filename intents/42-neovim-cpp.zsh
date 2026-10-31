id=neovim-cpp
title="Neovim · C/C++"
why="clangd, clang-format and the lldb-dap debugger from the Command Line Tools, with coc-clangd."
requires=(neovim)
packages=(
  "apple clangd, clang-format and lldb-dap from the Command Line Tools"
  "repo scripts/xcrun-tool → ~/.local/bin/clang-format and ~/.local/bin/lldb-dap"
  "coc coc-clangd"
)
targets=($HOME/.local/bin/clang-format $HOME/.local/bin/lldb-dap)

apply() {
  link scripts/xcrun-tool $HOME/.local/bin/clang-format || return 1
  link scripts/xcrun-tool $HOME/.local/bin/lldb-dap
}
