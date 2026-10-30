-- utils/theme-switcher.lua
-- Pick dark (Catppuccin Mocha) or light (Catppuccin Latte) colors from the system appearance.
-- WezTerm reloads the config whenever the system appearance changes, so evaluating this
-- in config/appearance.lua is enough; no per-window override is needed.
local wezterm = require('wezterm')

local M = {}

local dark_colors = require('colors.custom')
local light_colors = require('colors.catppuccin-latte')

---Detect current system appearance and return the appropriate color scheme.
---Falls back to dark theme when appearance detection is unavailable.
---@return table colorscheme table compatible with WezTerm colors config key
function M.get_colors()
   local ok, appearance = pcall(function()
      return wezterm.gui.get_appearance()
   end)
   if ok and type(appearance) == 'string' and appearance:find('Light') then
      return light_colors
   end
   return dark_colors
end

return M
