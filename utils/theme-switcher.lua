-- utils/theme-switcher.lua
-- Automatically switch between dark (Catppuccin Mocha) and light (Catppuccin Latte)
-- based on system appearance. Uses window-overrides to avoid clobbering other overrides.
local wezterm = require('wezterm')
local WinOverrides = require('utils.window-overrides')

local M = {}

local dark_colors  = require('colors.custom')
local light_colors = require('colors.catppuccin-latte')

-- Detect appearance once at module load time.
-- config/appearance.lua calls M.get_colors() during this same load phase,
-- so _compiled_appearance reflects what was baked into the static config.
local _ok_init, _init = pcall(function() return wezterm.gui.get_appearance() end)
local _compiled_appearance = (_ok_init and type(_init) == 'string') and _init or 'Dark'

-- Per-window tracking: window_id -> appearance string last applied via override.
-- nil means no override has been set for that window yet.
local _window_appearance = {}

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

---Register handlers for dynamic theme switching.
---Skips the redundant override on first window-config-reloaded at startup,
---preventing the re-render flash when appearance matches the compiled static config.
function M.setup()
   wezterm.on('window-config-reloaded', function(window, _pane)
      local id = window:window_id()
      local ok, appearance = pcall(function()
         return wezterm.gui.get_appearance()
      end)
      local current = (ok and type(appearance) == 'string') and appearance or 'Dark'

      -- Already applied this appearance to this window — nothing to do
      if _window_appearance[id] == current then return end

      -- First event for this window AND appearance matches compiled static config:
      -- static config already has correct colors, skip override to avoid re-render flash
      if _window_appearance[id] == nil and current == _compiled_appearance then
         _window_appearance[id] = current
         return
      end

      -- Appearance changed (or new window opened after appearance switch): apply override
      _window_appearance[id] = current
      WinOverrides.set(window, 'colors', M.get_colors())
   end)

   -- Clean up per-window state when a window closes
   wezterm.on('window-closed', function(window)
      _window_appearance[window:window_id()] = nil
   end)
end

return M
