-- utils/segment.lua
-- Build wezterm.format() item lists. Pure: no shared state between callers.

local M = {}

---@class SegmentColor
---@field fg? string
---@field bg? string

---Append one styled text run to a FormatItem list
---@param items table[] FormatItem list being built
---@param text string
---@param color? SegmentColor
---@param bold? boolean
---@return table[] items (for chaining)
function M.append(items, text, color, bold)
   color = color or {}
   -- Reset first so colors/intensity never bleed in from the previous run
   items[#items + 1] = 'ResetAttributes'
   if color.bg then
      items[#items + 1] = { Background = { Color = color.bg } }
   end
   if color.fg then
      items[#items + 1] = { Foreground = { Color = color.fg } }
   end
   if bold then
      items[#items + 1] = { Attribute = { Intensity = 'Bold' } }
   end
   items[#items + 1] = { Text = text }
   return items
end

return M
