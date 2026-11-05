-- events/gui-startup.lua
-- Startup orchestration for both launch modes (see PERSISTENT_SESSIONS in config/domains.lua):
--   plain (`wezterm start`)      gui-startup spawns the first window (session tab 1 + near
--                                full-screen geometry) and restores the remaining tabs
--   persistent (`connect unix`)  gui-startup does not fire; mux-startup restores the local
--                                tabs inside the mux server, only when the server itself starts
--                                (re-attaching to a running server keeps its live panes), and
--                                hands WSL / SSH tabs to the GUI (see session.partition)
-- Once the GUI has its windows (end of gui-startup, or gui-attached; this WezTerm version
-- only fires gui-attached for `connect`): maximize, restore handed-over tabs, deferred tasks.
local wezterm = require('wezterm')
local mux = wezterm.mux
local session = require('utils.session')
local startup = require('utils.startup')
local timing = require('utils.timing')
local window_geometry = require('utils.window-geometry')

local M = {}

---Spawn the first window, restoring saved tabs into it when there are any
---@param spawn_cmd table SpawnCommand for the first window (mutated)
---@param tabs_data SessionTab[]|nil
local function spawn_with_session(spawn_cmd, tabs_data)
   -- Restore tab 1 unless the user asked for something explicit (`wezterm start --cwd/-- prog`)
   if tabs_data and spawn_cmd.cwd == nil and spawn_cmd.args == nil then
      for k, v in pairs(session.spawn_args(tabs_data[1])) do
         spawn_cmd[k] = v
      end
   end

   local _t = timing.now()
   local _, _, window = mux.spawn_window(spawn_cmd)
   timing.log('mux.spawn_window()', _t, 'timing/gui-startup')

   if tabs_data then
      session.restore_remaining(window, tabs_data)
   end
end

-- gui-startup and gui-attached may both fire (newer WezTerm); finish startup only once
local ready = false

local function on_gui_ready()
   if ready then
      return
   end
   ready = true

   local windows = mux.all_windows()
   for _, window in ipairs(windows) do
      local gui_window = window:gui_window()
      if gui_window then
         gui_window:maximize()
      end
   end

   local first = windows[1]
   local handed = first and session.take_from_server()
   if handed then
      local active = 0
      for _, info in ipairs(first:tabs_with_info()) do
         if info.is_active then
            active = info.index
         end
      end
      session.spawn_tabs(first, handed)
      -- The GUI activates each new tab once it processes the spawn, after this callback;
      -- switch back to the tab the server restored as active after that
      wezterm.time.call_after(0.5, function()
         local gui_window = first:gui_window()
         if gui_window then
            gui_window:perform_action(wezterm.action.ActivateTab(active), gui_window:active_pane())
         end
      end)
   end

   startup.run_deferred()
end

M.setup = function()
   wezterm.on('gui-startup', function(cmd)
      local spawn_cmd = cmd or {}
      -- Spawn at near full-screen size so maximize() doesn't visibly resize (startup flash)
      local geometry = window_geometry.for_active_screen(require('config.fonts').font_size)
      for k, v in pairs(geometry or {}) do
         if spawn_cmd[k] == nil then
            spawn_cmd[k] = v
         end
      end
      spawn_with_session(spawn_cmd, session.load())
      on_gui_ready()
   end)

   wezterm.on('mux-startup', function()
      local tabs_data = session.load()
      if not tabs_data then
         return -- the attaching GUI spawns the default program itself
      end
      local local_tabs, gui_tabs = session.partition(tabs_data)
      if #gui_tabs > 0 then
         session.hand_to_gui(gui_tabs)
      end
      if #local_tabs > 0 then
         spawn_with_session({}, local_tabs)
      end
   end)

   wezterm.on('gui-attached', function(_domain)
      on_gui_ready()
   end)
end

return M
