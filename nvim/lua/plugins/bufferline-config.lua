-- Bufferline (tabline) -- replaces vim-airline's tabline extension.
--
-- separator_style must be one of bufferline's named presets ('slant',
-- 'slope', 'padded_slant', 'padded_slope', 'thick', 'thin'), not a custom
-- {left, right} glyph pair: bufferline's add_separators() only gives the
-- per-tab background-matched highlight (the thing that makes the curve
-- read as a smooth pill instead of a flat block of one fixed color) to
-- those named presets -- see is_slant() in bufferline/ui.lua. 'slope' uses
-- the roundest of the built-in glyphs.
require('bufferline').setup({
  options = {
    mode = 'buffers',
    separator_style = 'slope',
    diagnostics = 'coc',
    show_buffer_close_icons = true,
    show_close_icon = false,
    always_show_bufferline = true,
  },
})
