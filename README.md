# setup-configs

My macOS setup (zsh, Neovim, yazi, git, iTerm2, VS Code) plus an interactive
installer that rebuilds it on a fresh Mac, with or without admin rights.

Apple Silicon only, macOS 14 or newer.

## Quick start

On a Mac without this repo (no git needed):

```bash
zsh -c "$(curl -fsSL https://raw.githubusercontent.com/convict-git/setup-configs/main/bootstrap.sh)"
```

It asks where to put the repo (default `~/convict/open-source/setup-configs`),
downloads it and runs `install.sh`. Once git is installed, the folder becomes a
normal git clone.

Or clone it yourself and run the installer from wherever it is:

```bash
git clone https://github.com/convict-git/setup-configs.git ~/convict/open-source/setup-configs
```

```bash
~/convict/open-source/setup-configs/install.sh
```

A run goes like this. Nothing changes before step 5.

1. **Sudo or not.** The first question. See [With or without sudo](#with-or-without-sudo).
2. **Pre-check.** Read-only: macOS version, Command Line Tools, who owns Homebrew,
   MDM/Jamf/Self Service/Santa, whether HTTPS is inspected by a proxy, whether the
   download hosts are reachable, free disk, and which files would be replaced.
3. **Choose.** A `[Y/n]` question per [intent](#intents), in dependency order.
   Declining one skips those that need it, and says why.
4. **Plan.** Everything that will happen, grouped by source, with what's already done ticked.
5. **Apply**, after you confirm. Each command is shown with its output.
6. **Summary.** What was set up, what was skipped and why, and anything worth knowing.

| Option | What it does |
|---|---|
| `--check` | Only the pre-check |
| `--dry-run` | Ask, show the plan and every command it would run, change nothing |
| `--answers FILE` | No questions: take the answers from `FILE` (same format as `~/.config/setup-configs/answers.env`) |
| `--unlink` | Remove the links and git includes it made, point iTerm2 back at its own settings (offering to import the ones it had before), and offer to restore the last backup. Installed packages stay. |
| `--docs` | Regenerate this README's intent and host sections from `intents/` (`--docs --check` fails if they're stale; `--docs --refresh` also re-reads brew dependencies and plugin URLs) |

## With or without sudo

sudo is used for exactly two things, each asked for separately, and only when missing:
installing Apple's Command Line Tools (`softwareupdate`) and installing Homebrew into
`/opt/homebrew` (its official installer). Everything else installs into your home
folder: apps to `~/Applications`, fonts to `~/Library/Fonts`, scripts and `tsgo` to
`~/.local/bin`, plus `~/.nvm`, `~/.rustup`, `~/.oh-my-zsh` and Neovim's plugin folders.

| This Mac has | With sudo | Without sudo |
|---|---|---|
| No Command Line Tools | Installed (about 1 GB) | Only Deimos font, Git config, VS Code/Cursor and an already-installed iTerm2 can be set up. Install the tools from Self Service, then run again. |
| No Homebrew | Installed into `/opt/homebrew` | Everything installed with brew is skipped |
| Homebrew owned by another user | Skipped all the same: the installer never changes its ownership or adds a second Homebrew | Same. Ask IT (or Self Service) to make `/opt/homebrew` yours. |
| Homebrew you can write to | No sudo needed | No sudo needed |

On a managed Mac, also check:

- **Software allowlists.** Every package, its source and what it pulls in is listed
  under [Intents](#intents), and every download host under [Hosts](#hosts).
- **HTTPS inspection** (Zscaler, Netskope, ...). The pre-check reports who signed
  github.com's certificate. node, npm and rustup use their own certificate store, so
  behind such a proxy, point `NODE_EXTRA_CA_CERTS` at the company's root certificate.
- **Santa in Lockdown mode** may block binaries it doesn't know, such as freshly
  installed brew tools.

## Intents

How configs are put in place:

- **Symlinked** into the repo, so edits on either side are the same file: `~/.zshrc`,
  `~/.config/nvim`, `~/.config/yazi`, the scripts in `~/.local/bin`, and the VS Code/Cursor files.
- **`~/.gitconfig`** stays your own file. The installer sets your name and email and adds
  `include.path` lines for `git/base.gitconfig` and `git/aliases.gitconfig`, so tools that
  write to your git config never edit the repo. Without git (no Command Line Tools yet) it
  writes the same lines as plain text.
- **iTerm2** loads its settings from `iterm2/` and saves changes back there.
- **Deimos** is copied into `~/Library/Fonts`; **oh-my-zsh** is cloned at a pinned commit.

Whatever a link or copy replaces is moved to `~/.setup-configs-backup/<time>/` first.

The configs adapt to what's installed: `.zshrc` only loads oh-my-zsh, Homebrew's zsh
plugins and nvm when they're there, and Neovim only installs yazi.nvim, the DAP stack,
vim-clang-format and the language-specific coc extensions when yazi, `lldb-dap`,
`clang-format`, `tsgo` or `rust-analyzer` is on `PATH`.

<!-- generated:intents -->
### Foundation

Apple's Command Line Tools (git, compilers) and Homebrew. Everything installed with brew needs both.

**Always included**

**Uses sudo** (each step asks first):
- Install the Command Line Tools with softwareupdate
- Install Homebrew into /opt/homebrew with its official installer

| Source | What |
|---|---|
| Apple | Command Line Tools (git, clang, clangd, clang-format, lldb-dap), only if missing |
| Homebrew installer | Homebrew into /opt/homebrew, only if missing |

Downloads from: `swscan.apple.com`, `swcdn.apple.com`, `raw.githubusercontent.com`, `github.com`, `formulae.brew.sh`, `ghcr.io`

### Core CLI

Fast file and text search used by the shell, Neovim, yazi and the git aliases.

**Needs:** Foundation

| Source | What |
|---|---|
| Homebrew formula | fd |
| Homebrew formula | ripgrep |
| Homebrew formula | fzf |
| Homebrew formula | bat |
| This repo | scripts/fd-cache.sh → ~/.local/bin/fd-cache (fd with a 1-minute cache) |

Downloads from: `formulae.brew.sh`, `ghcr.io`, `pkg-containers.githubusercontent.com`

<details><summary>What these Homebrew formulae pull in</summary>

- **ripgrep** → pcre2
- **bat** → ca-certificates, libgit2, libssh2, llhttp, oniguruma, openssl@4

</details>

### Deimos font

The monospace font iTerm2, VS Code and Neovim's GUI are set to.

| Source | What |
|---|---|
| This repo | fonts/DeimosRegular2.ttf → ~/Library/Fonts (copied; apps pick it up after a restart) |

### Git config

Your name and email, plus shared settings: nvimdiff for diffs and merges, main as the default branch.

**Works best with:** Neovim

| Source | What |
|---|---|
| This repo | git/base.gitconfig, included from ~/.gitconfig (which stays your own file) |

### Git aliases

Shortcuts like git s, git b, git last and git cam, and the missing-changes script.

**Needs:** Core CLI

| Source | What |
|---|---|
| This repo | git/aliases.gitconfig, included from ~/.gitconfig |
| This repo | scripts/missing-changes.sh → ~/.local/bin/missing-changes |

### zsh

oh-my-zsh with the cypher theme, plus autosuggestions, syntax highlighting, vi mode and history search.

**Needs:** Core CLI

| Source | What |
|---|---|
| git clone | ohmyzsh/ohmyzsh at 97e1105 → ~/.oh-my-zsh (auto-update off) |
| Homebrew formula | zsh-autosuggestions |
| Homebrew formula | zsh-syntax-highlighting |
| Homebrew formula | zsh-vi-mode |
| Homebrew formula | zsh-history-substring-search |
| This repo | zsh/.zshrc → ~/.zshrc |

Downloads from: `github.com`, `formulae.brew.sh`, `ghcr.io`, `pkg-containers.githubusercontent.com`

### nvm

Node version manager, with the current Node.js LTS as the default (loaded by .zshrc).

**Needs:** zsh

| Source | What |
|---|---|
| Homebrew formula | nvm |
| nvm | Node.js LTS, installed by nvm into ~/.nvm |

Downloads from: `nodejs.org`, `formulae.brew.sh`, `ghcr.io`, `pkg-containers.githubusercontent.com`

### yazi

Terminal file manager, also opened from Neovim with <C-g>. Its plugins and theme are in the repo.

**Needs:** Core CLI

| Source | What |
|---|---|
| Homebrew formula | yazi |
| Homebrew formula | zoxide |
| Homebrew cask | font-symbols-only-nerd-font |
| This repo | yazi/ → ~/.config/yazi (plugins and the nightfly flavor included) |

Downloads from: `formulae.brew.sh`, `ghcr.io`, `pkg-containers.githubusercontent.com`, `github.com`, `release-assets.githubusercontent.com`

### yazi · rich previews

Previews of video, archives, JSON, PDFs, SVGs and images inside yazi.

**Needs:** yazi

| Source | What |
|---|---|
| Homebrew formula | ffmpeg |
| Homebrew formula | sevenzip |
| Homebrew formula | jq |
| Homebrew formula | poppler |
| Homebrew formula | resvg |
| Homebrew formula | imagemagick |
| Homebrew formula | chafa |

Downloads from: `formulae.brew.sh`, `ghcr.io`, `pkg-containers.githubusercontent.com`

<details><summary>What these Homebrew formulae pull in</summary>

- **ffmpeg** → aom, aribb24, brotli, ca-certificates, cairo, cjson, dav1d, flac, fontconfig, freetype, frei0r, fribidi, gettext, giflib, glib, gmp, gnutls, graphite2, harfbuzz, highway, icu4c@77, imath, jpeg-turbo, jpeg-xl, lame, leptonica, libarchive, libass, libb2, libbluray, libdeflate, libevent, libidn2, libmicrohttpd, libnghttp2, libogg, libpng, librist, libsamplerate, libsndfile, libsodium, libsoxr, libssh, libtasn1, libtiff, libudfread, libunibreak, libunistring, libvidstab, libvmaf, libvorbis, libvpx, libx11, libxau, libxcb, libxdmcp, libxext, libxrender, little-cms2, lz4, lzo, mbedtls, mpg123, nettle, opencore-amr, openexr, openjpeg, openssl@3, opus, p11-kit, pango, pcre2, pixman, rav1e, rubberband, sdl2, snappy, speex, srt, svt-av1, tesseract, theora, unbound, webp, x264, x265, xorgproto, xvid, xz, zeromq, zimg, zstd
- **jq** → oniguruma
- **poppler** → ca-certificates, cairo, fontconfig, freetype, gettext, glib, gmp, gnupg, gnutls, gpgme, gpgmepp, jpeg-turbo, libassuan, libevent, libgcrypt, libgpg-error, libidn2, libksba, libnghttp2, libpng, libtasn1, libtiff, libunistring, libusb, libx11, libxau, libxcb, libxdmcp, libxext, libxrender, little-cms2, lz4, lzo, nettle, npth, nspr, nss, openjpeg, openssl@3, p11-kit, pcre2, pinentry, pixman, readline, unbound, xorgproto, xz, zstd
- **imagemagick** → aom, brotli, fontconfig, freetype, gettext, giflib, glib, highway, imath, jasper, jpeg-turbo, jpeg-xl, libde265, libdeflate, libheif, liblqr, libomp, libpng, libraw, libtiff, libtool, libunistring, libvmaf, little-cms2, lz4, m4, openexr, openjpeg, pcre2, shared-mime-info, webp, x265, xz, zstd
- **chafa** → aom, brotli, cairo, dav1d, fontconfig, freetype, fribidi, gdk-pixbuf, gettext, giflib, glib, graphite2, harfbuzz, highway, icu4c@78, imath, jpeg-turbo, jpeg-xl, json-c, libavif, libdatrie, libdeflate, libpng, librsvg, libthai, libtiff, libunistring, libvmaf, libx11, libxau, libxcb, libxdmcp, libxext, libxrender, little-cms2, lz4, lzo, openexr, openjph, pango, pcre2, pixman, webp, xorgproto, xz, zstd

</details>

### Neovim

Neovim with coc.nvim, Telescope, treesitter and about 40 plugins, all at the versions in nvim/lazy-lock.json.

**Needs:** Core CLI · **Works best with:** Deimos font

| Source | What |
|---|---|
| Homebrew formula | neovim |
| Homebrew formula | node (runs coc.nvim) |
| Homebrew formula | cmake (builds telescope-fzf-native) |
| Homebrew cask | font-symbols-only-nerd-font |
| This repo | nvim/ → ~/.config/nvim |
| lazy.nvim | plugins pinned in nvim/lazy-lock.json |
| nvim-treesitter | c, cpp, rust, typescript, tsx, javascript, markdown, markdown_inline |
| coc.nvim | coc-json, coc-yaml, coc-sh, coc-git, coc-floaterm, coc-docker, coc-cmake, coc-emmet |

Downloads from: `github.com`, `codeload.github.com`, `registry.npmjs.org`, `formulae.brew.sh`, `ghcr.io`, `pkg-containers.githubusercontent.com`, `release-assets.githubusercontent.com`

<details><summary>What these Homebrew formulae pull in</summary>

- **neovim** → gettext, libunistring, libuv, lpeg, luajit, luv, tree-sitter, unibilium, utf8proc
- **node** → brotli, c-ares, ca-certificates, icu4c@77, libnghttp2, libnghttp3, libngtcp2, libuv, lz4, openssl@3, readline, simdjson, sqlite, xz, zstd

</details>

<details><summary>The 49 lazy.nvim plugins (git clones from github.com)</summary>

`Bekaboo/dropbar.nvim` · `EdenEast/nightfox.nvim` · `MagicDuck/grug-far.nvim` · `MeanderingProgrammer/render-markdown.nvim` · `NLKNguyen/papercolor-theme` · `NeogitOrg/neogit` · `akinsho/bufferline.nvim` · `andythigpen/nvim-coverage` · `brenoprata10/nvim-highlight-colors` · `catppuccin/nvim` · `echasnovski/mini.nvim` · `fannheyward/telescope-coc.nvim` · `folke/flash.nvim` · `folke/lazy.nvim` · `folke/snacks.nvim` · `folke/tokyonight.nvim` · `hedyhli/outline.nvim` · `isak102/telescope-git-file-history.nvim` · `jiangmiao/auto-pairs` · `johmsalas/text-case.nvim` · `junegunn/fzf` · `junegunn/fzf.vim` · `kevinhwang91/nvim-ufo` · `kevinhwang91/promise-async` · `mfussenegger/nvim-dap` (only with its intent's tool) · `mikavilpas/yazi.nvim` (only with its intent's tool) · `neoclide/coc.nvim` · `nordtheme/vim` · `nvim-lua/plenary.nvim` · `nvim-lualine/lualine.nvim` · `nvim-neotest/nvim-nio` (only with its intent's tool) · `nvim-telescope/telescope-file-browser.nvim` · `nvim-telescope/telescope-frecency.nvim` · `nvim-telescope/telescope-fzf-native.nvim` · `nvim-telescope/telescope.nvim` · `nvim-tree/nvim-web-devicons` · `nvim-treesitter/nvim-treesitter` · `oxfist/night-owl.nvim` · `preservim/tagbar` · `projekt0n/github-nvim-theme` · `rcarriga/nvim-dap-ui` (only with its intent's tool) · `rhysd/vim-clang-format` (only with its intent's tool) · `sainnhe/everforest` · `sainnhe/gruvbox-material` · `sindrets/diffview.nvim` · `theHamsta/nvim-dap-virtual-text` (only with its intent's tool) · `tpope/vim-fugitive` · `vimichael/floatingtodo.nvim` · `voldikss/vim-floaterm`

</details>

### Neovim · TypeScript/JavaScript

tsgo (the native TypeScript language server) plus coc's tsserver, eslint and prettier extensions.

**Needs:** Neovim

| Source | What |
|---|---|
| npm | @typescript/native-preview (tsgo) → ~/.local |
| coc.nvim | coc-tsserver, coc-eslint, coc-prettier |

Downloads from: `registry.npmjs.org`

### Neovim · C/C++

clangd, clang-format and the lldb-dap debugger from the Command Line Tools, with coc-clangd.

**Needs:** Neovim

| Source | What |
|---|---|
| Apple | clangd, clang-format and lldb-dap from the Command Line Tools |
| This repo | scripts/xcrun-tool → ~/.local/bin/clang-format and ~/.local/bin/lldb-dap |
| coc.nvim | coc-clangd |

### Neovim · Rust

The stable Rust toolchain with rust-analyzer, coc-rust-analyzer, and lldb-dap for debugging.

**Needs:** Neovim

| Source | What |
|---|---|
| Homebrew formula | rustup |
| rustup | stable toolchain with rust-analyzer → ~/.rustup |
| This repo | scripts/xcrun-tool → ~/.local/bin/lldb-dap |
| coc.nvim | coc-rust-analyzer |

Downloads from: `static.rust-lang.org`, `formulae.brew.sh`, `ghcr.io`, `pkg-containers.githubusercontent.com`

<details><summary>What these Homebrew formulae pull in</summary>

- **rustup** → xz

</details>

### iTerm2

iTerm2, loading its settings from (and saving them back to) the repo's iterm2/ folder.

**Works best with:** Deimos font

| Source | What |
|---|---|
| Homebrew cask | iterm2 (skipped when iTerm2 is already installed) |
| Homebrew cask | font-meslo-for-powerlevel10k |
| Homebrew cask | font-source-code-pro |
| This repo | iterm2/ as iTerm2's settings folder |

Downloads from: `formulae.brew.sh`, `ghcr.io`, `pkg-containers.githubusercontent.com`, `iterm2.com`, `github.com`, `release-assets.githubusercontent.com`

### VS Code / Cursor

Settings, keybindings and the Vim extension's .vscodevimrc, linked into whichever of VS Code and Cursor is installed.

**Works best with:** Deimos font

| Source | What |
|---|---|
| This repo | vscode/settings.json and vscode/keybindings.json → each editor's User folder |
| This repo | vscode/.vscodevimrc → ~/.vscodevimrc |
| Homebrew cask | font-red-hat-mono |

Downloads from: `formulae.brew.sh`, `ghcr.io`, `pkg-containers.githubusercontent.com`, `github.com`, `release-assets.githubusercontent.com`
<!-- /generated:intents -->

## Hosts

Every host the installer downloads from, for a firewall or proxy allowlist. Homebrew
formulae come from `formulae.brew.sh` (metadata) and `ghcr.io` (bottles).

<!-- generated:hosts -->
| Host | Used by |
|---|---|
| `codeload.github.com` | Neovim |
| `formulae.brew.sh` | Foundation, Core CLI, zsh, nvm, yazi, yazi · rich previews, Neovim, Neovim · Rust, iTerm2, VS Code / Cursor |
| `ghcr.io` | Foundation, Core CLI, zsh, nvm, yazi, yazi · rich previews, Neovim, Neovim · Rust, iTerm2, VS Code / Cursor |
| `github.com` | Foundation, zsh, yazi, Neovim, iTerm2, VS Code / Cursor |
| `iterm2.com` | iTerm2 |
| `nodejs.org` | nvm |
| `pkg-containers.githubusercontent.com` | Core CLI, zsh, nvm, yazi, yazi · rich previews, Neovim, Neovim · Rust, iTerm2, VS Code / Cursor |
| `raw.githubusercontent.com` | Foundation |
| `registry.npmjs.org` | Neovim, Neovim · TypeScript/JavaScript |
| `release-assets.githubusercontent.com` | yazi, Neovim, iTerm2, VS Code / Cursor |
| `static.rust-lang.org` | Neovim · Rust |
| `swcdn.apple.com` | Foundation |
| `swscan.apple.com` | Foundation |
<!-- /generated:hosts -->

## Re-running, backups and undo

- **Safe to re-run.** Anything already in place shows as done, and nothing installed is
  upgraded (`HOMEBREW_NO_AUTO_UPDATE`, `HOMEBREW_NO_INSTALL_UPGRADE`).
- **Answers** are saved to `~/.config/setup-configs/answers.env` and become the defaults
  next time. Pass a copy to `--answers` to run without questions.
- **Backups** of replaced files go to `~/.setup-configs-backup/<time>/`. Before iTerm2 is
  pointed at `iterm2/`, its current settings are exported there as
  `com.googlecode.iterm2.plist`.
- **Logs** of every run go to `~/.local/state/setup-configs/<time>.log`.
- **Undo** with `install.sh --unlink`. It also offers to import iTerm2's earlier settings
  (iTerm2 must be closed for that).

## Testing in a VM

`test/sandbox.zsh` runs the installer in throwaway macOS VMs using
[Tart](https://tart.run) (Apple's Virtualization framework; free on personal machines).
The base image is about 25 GB.

| Command | What it does |
|---|---|
| `test/sandbox.zsh setup` | Installs Tart (Homebrew) and builds two base VMs: `sc-golden-fresh` (clean macOS plus a standard, non-admin user `worker`) and `sc-golden-brew` (Command Line Tools plus a Homebrew owned by `admin`) |
| `test/sandbox.zsh run <scenario>` | Clones a base VM, shares this repo into it, runs the installer there, and checks the result |
| `test/sandbox.zsh new [base] [--window\|--vnc]` / `ssh <vm>` | A VM to poke at by hand. `--window` shows its screen; `--vnc` opens it in Screen Sharing, where copy and paste work |
| `test/sandbox.zsh ls` | VMs and their disk use |
| `test/sandbox.zsh clean` | Deletes the test VMs, keeping the base ones |
| `test/sandbox.zsh purge` | Deletes everything, including the base VMs and Tart's image cache, and offers to uninstall Tart |

Scenarios: `fresh-sudo` (fresh Mac, sudo yes), `fresh-nosudo` (fresh Mac, standard
user), `brew-other` (Homebrew owned by another user, no sudo), `brew-own`
(Homebrew owned by you, no sudo), `declines` (some intents answered no, iTerm2's
among them) and `legacy-link` (`~/.gitconfig` linked to the repo's old
`git/.gitconfig`). A run fails if `install.sh` or the checks do.

To watch the installer yourself, run `test/sandbox.zsh new --window`. The VM logs in as
`admin`; in its Terminal, `ditto '/Volumes/My Shared Files/repo' ~/convict/open-source/setup-configs`
copies this checkout in, or the one-liner above installs what's pushed. The base VMs let
`admin` use sudo without a password; `sudo rm /etc/sudoers.d/admin` brings the prompt
back. The passwords are `admin` and `worker`.

## Manual steps

- **VS Code/Cursor extensions** the settings refer to: `vscodevim.vim`,
  `usernamehw.errorlens`, `iocave.customize-ui`, `pkief.material-icon-theme`,
  `esbenp.prettier-vscode`, `dbaeumer.vscode-eslint`, `eamodio.gitlens`.
- **Fonts** show up in apps that were already open only after you restart them.
- **iTerm2** must be closed when the installer points it at `iterm2/`; otherwise it
  would save its current settings over the repo's when it quits. The installer says so
  and leaves it alone.
- Work-specific settings (git `includeIf`, project eslint rules) aren't in this repo.
