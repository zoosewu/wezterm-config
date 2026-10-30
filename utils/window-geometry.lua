-- utils/window-geometry.lua
-- Estimates an initial window geometry that already covers the active screen,
-- so the `maximize()` in gui-startup barely resizes the window (no startup flash).
local wezterm = require('wezterm')
local platform = require('utils.platform')

local M = {}

-- Approximate monospace cell size as a ratio of the font pixel size.
-- Rounded up below so the estimate undershoots the screen rather than overflowing it.
local CELL_W_RATIO = 0.6
local CELL_H_RATIO = 1.35

-- Pixels (at scale 1) not available to cells: title bar, tab bar, padding, taskbar, scrollbar
local RESERVED_W = 24
local RESERVED_H = 130

---Return `width`/`height` (in cells) and `position` for `mux.spawn_window`,
---or nil when screen info is unavailable.
---@param font_size number
---@return { width: integer, height: integer, position: table }|nil
function M.for_active_screen(font_size)
   if not wezterm.gui then
      return nil -- mux server / CLI: no GUI screens
   end
   local ok, screens = pcall(wezterm.gui.screens)
   if not ok or not screens or not screens.active then
      return nil
   end

   local screen = screens.active
   local scale = screen.scale or 1
   local font_px = font_size * scale * (platform.is_mac and 1 or 96 / 72)
   local cell_w = math.ceil(font_px * CELL_W_RATIO)
   local cell_h = math.ceil(font_px * CELL_H_RATIO)

   return {
      width = math.max(80, math.floor((screen.width - RESERVED_W * scale) / cell_w)),
      height = math.max(24, math.floor((screen.height - RESERVED_H * scale) / cell_h)),
      position = { x = screen.x, y = screen.y, origin = 'ScreenCoordinateSystem' },
   }
end

return M
