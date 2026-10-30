local wezterm = require('wezterm')
local platform = require('utils.platform')
local font_installer = require('utils.font-installer')

-- local font_family = 'Maple Mono NF'
-- local font_family = 'CartographCF Nerd Font'
-- Auto-downloaded to `fonts/` if not installed (see utils/font-installer.lua)
local font_family = font_installer.ensure({
   family = 'JetBrainsMono Nerd Font',
   fallback = 'JetBrains Mono', -- bundled with WezTerm
   base_url = 'https://github.com/ryanoasis/nerd-fonts/raw/v3.5.1/patched-fonts/JetBrainsMono/Ligatures/',
   files = {
      'JetBrainsMonoNerdFont-Medium.ttf',
      'JetBrainsMonoNerdFont-MediumItalic.ttf',
      'JetBrainsMonoNerdFont-Bold.ttf',
      'JetBrainsMonoNerdFont-BoldItalic.ttf',
   },
})

local font_size = platform.is_mac and 12 or 9.75

return {
   font = wezterm.font({
      family = font_family,
      weight = 'Medium',
   }),
   font_size = font_size,
   font_dirs = { font_installer.FONT_DIR },

   --ref: https://wezfurlong.org/wezterm/config/lua/config/freetype_pcf_long_family_names.html#why-doesnt-wezterm-use-the-distro-freetype-or-match-its-configuration
   freetype_load_target = 'Normal', ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
   freetype_render_target = 'Normal', ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
}
