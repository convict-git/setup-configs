-- Lualine (statusline) -- replaces vim-airline.
--
-- 'branch' just reads .git/HEAD (cheap) and is kept. The 'diff' component
-- (gitsigns-backed hunk counts) is deliberately left out: this repo's
-- `git status` is slow (~0.85s+), and airline's 'branch'/'hunks' extensions
-- were dropped earlier for the same reason -- keep the statusline off the
-- git-status hot path.
require('lualine').setup({
  options = {
    -- 'auto' re-derives colors from whatever colorscheme is active (lualine
    -- hooks the ColorScheme autocmd and re-runs setup()), so it stays in
    -- sync with manual :colorscheme changes and the <F5> random-colorscheme
    -- keymap. A named theme like 'duskfox' is a static color table from
    -- that one colorscheme's palette -- it looked better for duskfox
    -- specifically, but silently stops matching the moment you switch away
    -- from duskfox, which is exactly the mismatch this was.
    theme = 'auto',
    -- Built via nr2char (codepoint -> utf8 string) instead of pasting the
    -- glyphs literally: the literal Private-Use-Area characters silently
    -- turned into empty strings on a previous edit of this file, which is
    -- why separators were missing entirely. Codepoints are Nerd Fonts'
    -- "Powerline Extra Symbols" (E0B4-E0B7), confirmed present in
    -- MesloLGS NF (the iTerm2 non-ASCII fallback font).
    component_separators = { left = vim.fn.nr2char(0xE0B7, true), right = vim.fn.nr2char(0xE0B5, true) },
    section_separators = { left = vim.fn.nr2char(0xE0B6, true), right = vim.fn.nr2char(0xE0B4, true) },
    globalstatus = true,
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'branch' },
    -- path = 0 (just the filename): dropbar.nvim already renders the full
    -- breadcrumb path in the winbar, so the statusline showing it too (path
    -- = 1, relative to cwd) was just a long string of text eating most of
    -- the bar's width and crowding out the pills on either side.
    lualine_c = {
      {
        'filename',
        path = 0,
        symbols = { modified = ' ●', readonly = ' ', unnamed = '[No Name]' },
      },
    },
    lualine_x = { { 'diagnostics', sources = { 'coc' } }, 'filetype' },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },
})
