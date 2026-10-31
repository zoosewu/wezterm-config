local wezterm = require('wezterm')

local function is_found(str, pattern)
   return string.find(str, pattern) ~= nil
end

---@alias PlatformType 'windows' | 'linux' | 'mac'

---@return {os: PlatformType, is_win: boolean, is_linux: boolean, is_mac: boolean, mods: {SUPER: string, SUPER_REV: string}}
local function platform()
   local is_win = is_found(wezterm.target_triple, 'windows')
   local is_linux = is_found(wezterm.target_triple, 'linux')
   local is_mac = is_found(wezterm.target_triple, 'apple')
   local os

   if is_win then
      os = 'windows'
   elseif is_linux then
      os = 'linux'
   elseif is_mac then
      os = 'mac'
   else
      error('Unknown platform')
   end

   -- Modifier aliases used by config/bindings.lua (and shown by utils/keymap-help.lua).
   -- Windows/Linux use ALT so bindings don't conflict with Windows-key shortcuts.
   local super = is_mac and 'SUPER' or 'ALT'

   return {
      os = os,
      is_win = is_win,
      is_linux = is_linux,
      is_mac = is_mac,
      mods = { SUPER = super, SUPER_REV = super .. '|CTRL' },
   }
end

local _platform = platform()

return _platform
