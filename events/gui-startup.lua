local wezterm = require('wezterm')
local mux = wezterm.mux
local session = require('utils.session')
local startup = require('utils.startup')
local timing = require('utils.timing')
local window_geometry = require('utils.window-geometry')

local M = {}

M.setup = function()
   wezterm.on('gui-startup', function(cmd)
      local _T = timing.now()

      local _t = timing.now()
      local tabs_data = session.load()
      timing.log('session.load()', _t, 'timing/gui-startup')

      local spawn_cmd = cmd or {}
      -- Restore tab 1 unless the user asked for something explicit (`wezterm start --cwd/-- prog`)
      if tabs_data and spawn_cmd.cwd == nil and spawn_cmd.args == nil then
         for k, v in pairs(session.spawn_args(tabs_data[1])) do
            spawn_cmd[k] = v
         end
      end

      -- Spawn at near full-screen size so maximize() doesn't visibly resize (startup flash)
      local geometry = window_geometry.for_active_screen(require('config.fonts').font_size)
      for k, v in pairs(geometry or {}) do
         if spawn_cmd[k] == nil then
            spawn_cmd[k] = v
         end
      end

      local _t = timing.now()
      local _, _, window = mux.spawn_window(spawn_cmd)
      timing.log('mux.spawn_window()', _t, 'timing/gui-startup')

      local _t = timing.now()
      local gui_window = window:gui_window()
      if gui_window then
         gui_window:maximize()
      end
      timing.log('maximize()', _t, 'timing/gui-startup')

      if tabs_data then
         local _t = timing.now()
         session.restore_remaining(window, tabs_data)
         timing.log('session.restore_remaining()', _t, 'timing/gui-startup')
      end

      startup.run_deferred()

      timing.log('=== gui-startup total ===', _T, 'timing/gui-startup')
   end)
end

return M
