# Spr Supercharged (Neovim)

Neovim Lua port of three features from the **Sprinklr Supercharged** VSCode extension (`sprinklr-vs-supercharged`) for the **sprinklr-ui-hub** monorepo.

| VSCode command | Neovim command | Description |
|---|---|---|
| Scan Project | `:SprinklrScan` | Scan the monorepo and build import/dependency indices |
| Show Recursive References | `:SprinklrReferences` | Show files that import the current buffer (recursive tree) |
| Find Import Hierarchy | `:SprinklrTraceImports` | Find import chains from a target file to the current buffer |
| — | `:SprinklrToggleTree` | Focus, hide, or restore the references/hierarchy tree |

No third-party Neovim plugins are required beyond your plugin manager (if you use one).

## Requirements

- **Neovim** >= 0.9
- **sprinklr-ui-hub** opened at the repository root (`cwd` must be the monorepo root when scanning)
- A plugin manager is optional but recommended ([lazy.nvim](https://github.com/folke/lazy.nvim) examples below)

## Installation

### Option A — Copy into your Neovim config (recommended)

Copy the plugin folder into your config:

```text
~/.config/nvim/
├── init.lua
└── lua/
    └── plugins/
        ├── spr-supercharged.lua          # lazy.nvim spec (see below)
        └── spr-supercharged/
            ├── plugin/
            │   └── spr-supercharged.lua
            ├── lua/
            │   └── spr-supercharged/
            │       ├── init.lua
            │       ├── config.lua
            │       └── ...
            └── README.md
```

### Option B — Symlink

```bash
ln -s /path/to/spr-supercharged ~/.config/nvim/lua/plugins/spr-supercharged
```

You still need the lazy.nvim spec file at `lua/plugins/spr-supercharged.lua` (or register the plugin manually).

### Option C — Standalone runtime path

```bash
git clone <this-plugin-repo> ~/.local/share/nvim/site/pack/spr-supercharged/start/spr-supercharged
```

Neovim will pick up `plugin/spr-supercharged.lua` automatically on startup. Call `require("spr-supercharged").setup()` from your `init.lua` if you use custom options.

---

## Setup with lazy.nvim

**1.** Place the plugin at `lua/plugins/spr-supercharged/` as shown above.

**2.** Add a spec file at `lua/plugins/spr-supercharged.lua`:

```lua
return {
  dir = vim.fn.stdpath("config") .. "/lua/plugins/spr-supercharged",
  name = "spr-supercharged",
  cmd = {
    "SprinklrScan",
    "SprinklrReferences",
    "SprinklrTraceImports",
    "SprinklrToggleTree",
  },
  config = function()
    require("spr-supercharged").setup({
      -- optional overrides (see Configuration)
    })
  end,
}
```

**3.** Register it in your lazy setup (`init.lua`):

```lua
require("lazy").setup({
  -- ...your other plugins...
  require("plugins/spr-supercharged"),
})
```

**4.** Restart Neovim (or run `:Lazy reload spr-supercharged`).

### Optional keymaps

Add inside the `config` function of the lazy spec, or in your `init.lua`:

```lua
vim.keymap.set("n", "<leader>fs", ":SprinklrScan<CR>", { desc = "Sprinklr: scan project" })
vim.keymap.set("n", "<leader>fr", ":SprinklrReferences<CR>", { desc = "Sprinklr: file references" })
vim.keymap.set("n", "<leader>ft", ":SprinklrTraceImports<CR>", { desc = "Sprinklr: trace imports" })
vim.keymap.set("n", "<leader>fT", ":SprinklrToggleTree<CR>", { desc = "Sprinklr: toggle tree" })
```

---

## Usage

### First-time workflow

1. `cd` into the **sprinklr-ui-hub** root and open Neovim there.
2. Run `:SprinklrScan`.
   - A progress notification walks through: scanning files → parsing imports → building graph → saving cache.
   - On a large monorepo this can take a few minutes.
3. Open any indexed `.ts`/`.tsx`/`.js`/`.jsx` file.
4. Run `:SprinklrReferences` or `:SprinklrTraceImports`.

Re-run `:SprinklrScan` when the codebase changes significantly or the index feels stale.

### Show Recursive References

```vim
:SprinklrReferences
```

Opens a tree of every file that imports the **current buffer**, expandable recursively. Each line shows the filename, parent folder, and a **project-relative path** on the right.

### Find Import Hierarchy

```vim
:SprinklrTraceImports
```

1. Open the **child** file (the file you are in).
2. Run the command.
3. Enter the **parent/target** path (relative to repo root, e.g. `./packages/modules/src/foo.ts`).
4. Pick a search mode: **Quick**, **Moderate**, or **Exhaustive**.

Shows one or more import chains from the target file down to the current file.

### Toggle the tree panel

```vim
:SprinklrToggleTree
```

| State | What happens |
|---|---|
| Tree hidden | Shows the tree and focuses it |
| Tree visible, editor focused | Focuses the tree and restores your cursor position |
| Tree visible and focused | Hides the tree (state preserved) |

---

## Tree panel

The panel is always **docked to the right** at **half the editor width**. Files open in the main editor, not inside the panel.

### Keymaps (inside the tree)

| Key | Action |
|---|---|
| `<CR>` | Toggle expand on a folder node, or open a file |
| `o` | Open file under cursor in the main editor |
| `l` | Expand node |
| `h` | Collapse node |
| `q` / `<Esc>` | Hide tree (keeps expanded nodes, cursor, and scroll) |
| `Q` | Close tree permanently |

---

## Cache files

Scan output is written under the project root:

```text
.nvim/
├── hashVsFile.json
├── imports.json
└── dependency.json
```

Add `.nvim/` to the repo's `.gitignore` if it is not already ignored. These files are local indices, not source code.

---

## Configuration

Pass options to `setup()`:

```lua
require("spr-supercharged").setup({
  -- Directories to scan (relative to repo root)
  directories = {
    "./apps/spr-main-web",
    "./packages/modules",
    -- ...
  },

  -- Where scan results are stored (relative to repo root)
  cache_dir = ".nvim",

  -- Skipped during directory walk
  skip_dirs = { "node_modules", ".next", "dist" },

  -- Indexed file types
  extensions = { ".js", ".ts", ".jsx", ".tsx" },

  -- Trace import search limits per mode
  trace_modes = {
    quick = {
      max_nodes_to_explore = 300000,
      max_depth_to_explore = 20,
      max_sequences_to_explore = 3,
    },
    moderate = {
      max_nodes_to_explore = 500000,
      max_depth_to_explore = 30,
      max_sequences_to_explore = 5,
    },
    exhaustive = {
      max_nodes_to_explore = 1000000,
      max_depth_to_explore = 40,
      max_sequences_to_explore = 10,
    },
  },

  default_trace_mode = "quick",
})
```

Default `directories` match the VSCode extension and cover apps, microfrontends, and packages in sprinklr-ui-hub. Override only if your checkout layout differs.

---

## Lua API

```lua
require("spr-supercharged").setup(opts)
require("spr-supercharged").scan()
require("spr-supercharged").references()
require("spr-supercharged").trace_imports()
require("spr-supercharged").toggle_tree()
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `No files found` after scan | Ensure Neovim's `cwd` is the monorepo root (`:pwd`). Check `directories` in config. |
| `No results found in .nvim` | Run `:SprinklrScan` first. |
| `File Not Found` in references tree | The open file was not part of the last scan. Re-scan or check it lives under a configured directory. |
| Progress notification does not move | Parsing is CPU-heavy; the bar updates in batches. Wait for the parse phase to finish. |
| Plugin commands missing | Confirm lazy loaded the plugin (`:Lazy`) or that `plugin/spr-supercharged.lua` is on your runtime path. |

---

## Development

Headless integration test (from sprinklr-ui-hub root):

```bash
cd /path/to/sprinklr-ui-hub

nvim --headless \
  -u ~/.config/nvim/init.lua \
  -c "lua vim.opt.rtp:append(vim.fn.stdpath('config') .. '/lua/plugins/spr-supercharged')" \
  -S ~/.config/nvim/lua/plugins/spr-supercharged/test-headless.lua
```

---

## License

Same license as the parent Sprinklr Supercharged project.
