 # zmodload zsh/zprof #  keep at end for perf stats  # zprof

# Linked to ~/.zshrc by install.sh (zsh intent). Each tool-specific block checks
# that its tool is installed, so this loads cleanly whichever intents were chosen.

# Homebrew: puts /opt/homebrew/bin on PATH and sets HOMEBREW_PREFIX
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

# ~/.local/bin holds fd-cache, missing-changes, tsgo and the clang-format/lldb-dap
# links; Homebrew's rustup is keg-only, so its proxies (cargo, rustc) need adding
path=(
  $HOME/.local/bin
  ${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/opt/rustup/bin}
  $HOME/.cargo/bin
  $path
)
typeset -U path

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="cypher"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# install.sh pins oh-my-zsh to a tested commit, so it never updates itself
zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
   # git
   # git-prompt
   npm # you added this
)

[[ -r $ZSH/oh-my-zsh.sh ]] && source $ZSH/oh-my-zsh.sh

# The other plugins come from Homebrew. Same order as when they were oh-my-zsh
# plugins: history-substring-search must follow syntax-highlighting
for plugin in \
  share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh \
  share/zsh-history-substring-search/zsh-history-substring-search.zsh
do
  [[ -n $HOMEBREW_PREFIX && -r $HOMEBREW_PREFIX/$plugin ]] && source $HOMEBREW_PREFIX/$plugin
done
unset plugin

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

export NVM_LAZY_LOAD=true
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh" --no-use
# This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
# This loads nvm bash_completion

# place this after nvm initialization!
# autoload -U add-zsh-hook
# load-nvmrc() {
# local node_version="$(nvm version)"
# local nvmrc_path="$(nvm_find_nvmrc)"
#
# if [ -n "$nvmrc_path" ]; then
#    local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")
#
#    if [ "$nvmrc_node_version" = "N/A" ]; then
#       nvm install
#    elif [ "$nvmrc_node_version" != "$node_version" ]; then
#       nvm use
#    fi
# elif [ "$node_version" != "$(nvm version default)" ]; then
#    echo "Reverting to nvm default version"
#    nvm use default
# fi
# }
# add-zsh-hook chpwd load-nvmrc
# load-nvmrc
[[ -e $NVM_DIR/alias/default ]] && (( $+functions[nvm] )) && nvm use default

noti() {
   if [[ $? = 0 ]]; then
      say "okay"
   else
      say "Uh"
   fi
}
# Attach notif() to the precmd hook
# precmd() {
# noti "$_"
# }
#

alias g='git'

# Fuzzy-jump into a project folder (fd-cache and fzf come with the Core CLI intent)
f() {
  cd $HOME
  result=$(fd-cache --type d --max-depth 5 \
        --exclude node_modules --exclude '.*' \
        --full-path "($HOME/code|$HOME/convict)" | sed "s|^$HOME/||" | fzf)
  cd $HOME/$result
  "$1" .
}

fme() {
  result=$(fd-cache --type d --max-depth 5 \
        --exclude node_modules --exclude '.*' \
        --full-path . | fzf)
  cd $result
  "$1" .
}

alias fcd="f cd"
alias fmecd="fme cd"
# fcd

ulimit -n 65536 2>/dev/null

function iterm2_tab_title() {
  local dir_name="${PWD##*/}"
  local cmd="${1%% *}"
  echo -ne "\033]1;${dir_name}-${cmd}\007"
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec function() {
  local cmd="${1%% *}"
  iterm2_tab_title "$cmd"
}

# zprof
