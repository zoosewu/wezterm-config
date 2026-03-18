-- utils/timing.lua
-- Lightweight startup timing utility.
-- Set ENABLED = true to print timing logs to the F12 Debug Overlay.
local wezterm = require('wezterm')

local M = {}

M.ENABLED = false

---Log elapsed time since t0. No-op when ENABLED is false.
---@param label string
---@param t0 number os.clock() snapshot taken before the measured block
---@param prefix? string log prefix (default: 'timing')
function M.log(label, t0, prefix)
   if not M.ENABLED then return end
   prefix = prefix or 'timing'
   wezterm.log_info(string.format('[%s] %-40s %.2fms', prefix, label, (os.clock() - t0) * 1000))
end

---Return current clock snapshot (os.clock()).
---@return number
function M.now()
   return os.clock()
end

return M
