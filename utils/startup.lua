-- utils/startup.lua
-- Background work that must not delay the first window (health check, GPU cache
-- refresh, font download). Modules register tasks with `defer`; events/gui-startup
-- runs them once the first window is up, in registration order, each isolated so one
-- failure cannot stop the others.
local wezterm = require('wezterm')

local M = {}

-- Seconds after the first window is spawned before deferred tasks start
local DELAY = 1

---@type { name: string, fn: fun() }[]
local tasks = {}

---Run `fn` in the background after the first window is shown (GUI startup only)
---@param name string label used in logs
---@param fn fun() may call async WezTerm APIs (run_child_process, ...)
function M.defer(name, fn)
   table.insert(tasks, { name = name, fn = fn })
end

---Start the deferred tasks. Called by events/gui-startup after spawning the window.
function M.run_deferred()
   wezterm.time.call_after(DELAY, function()
      for _, task in ipairs(tasks) do
         local ok, err = pcall(task.fn)
         if not ok then
            wezterm.log_error('[startup] deferred task "' .. task.name .. '" failed: ' .. tostring(err))
         end
      end
   end)
end

return M
