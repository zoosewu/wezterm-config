local wezterm = require('wezterm')
local mux = wezterm.mux
local session = require('utils.session')
local timing = require('utils.timing')

local M = {}

M.setup = function()
   wezterm.on('gui-startup', function(cmd)
      local _T = timing.now()

      local _t = timing.now()
      local tabs_data = session.load()
      local first_cwd = tabs_data and tabs_data[1] and tabs_data[1].cwd
      timing.log('session.load()', _t, 'timing/gui-startup')

      local spawn_cmd = cmd or {}
      if first_cwd then
         spawn_cmd.cwd = first_cwd
      end

      local _t = timing.now()
      local _, _, window = mux.spawn_window(spawn_cmd)
      timing.log('mux.spawn_window()', _t, 'timing/gui-startup')

      local _t = timing.now()
      window:gui_window():maximize()
      timing.log('maximize()', _t, 'timing/gui-startup')

      if tabs_data then
         local _t = timing.now()
         session.restore_remaining(window, tabs_data)
         timing.log('session.restore_remaining()', _t, 'timing/gui-startup')
      end

      timing.log('=== gui-startup total ===', _T, 'timing/gui-startup')
   end)
end

return M
