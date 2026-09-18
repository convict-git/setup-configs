#!/usr/bin/env bash

xcode-select --install
brew install neovim node nvm cmake yazi ffmpeg sevenzip jq poppler fd ripgrep fzf zoxide resvg imagemagick chafa font-symbols-only-nerd-font


# install rust 
curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh

# path apply 
# telescope-fzf-native
# 

# yazi plugins/flavor (all declared in yazi/package.toml)
# yazi/plugins/ is gitignored: it is package-manager output, not config.
ya pkg install

# oh-my-zsh plugins
cd ~/.oh-my-zsh/custom/plugins
git clone https://github.com/zsh-users/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git
git clone https://github.com/jeffreytse/zsh-vi-mode
git clone https://github.com/zsh-users/zsh-history-substring-search


