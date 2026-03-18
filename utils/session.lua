-- utils/session.lua
-- Save and restore tab layout (CWD per tab) across WezTerm restarts.
-- Save: triggered by the 'session.save' event (keybinding SUPER_REV + s).
-- Restore: orchestrated in gui-startup (see events/gui-startup.lua).
local wezterm = require('wezterm')

local M = {}

local SESSION_FILE = wezterm.config_dir .. '/session.json'

---Serialize the current window's tab CWDs to a JSON file
---@param window any WezTerm Window
function M.save(window)
   local tabs_data = {}

   for _, tab in ipairs(window:tabs()) do
      local active_pane = tab:active_pane()
      local cwd_uri = active_pane:get_current_working_dir()
      table.insert(tabs_data, {
         cwd = cwd_uri and cwd_uri.file_path or nil,
         title = tab:get_title(),
      })
   end

   local ok, json = pcall(wezterm.json_encode, tabs_data)
   if not ok then
      wezterm.log_error('session.save: json_encode failed: ' .. tostring(json))
      return
   end

   local f, err = io.open(SESSION_FILE, 'w')
   if not f then
      wezterm.log_error('session.save: cannot write to ' .. SESSION_FILE .. ': ' .. tostring(err))
      return
   end
   f:write(json)
   f:close()
   wezterm.log_info('session.save: saved ' .. #tabs_data .. ' tab(s) to ' .. SESSION_FILE)
end

---Load saved session data from disk.
---Returns nil if no session file exists or it is malformed.
---@return table|nil tabs_data array of {cwd, title} entries
function M.load()
   local f = io.open(SESSION_FILE, 'r')
   if not f then return nil end

   local content = f:read('*a')
   f:close()

   local ok, tabs_data = pcall(wezterm.json_decode, content)
   if not ok or type(tabs_data) ~= 'table' or #tabs_data == 0 then
      wezterm.log_warn('session.restore: invalid or empty session file, skipping')
      return nil
   end
   return tabs_data
end

---Spawn tabs 2+ from saved session data into an existing MuxWindow.
---Tab 1's CWD must already be handled by the caller (via spawn_window cwd).
---@param mux_window any WezTerm MuxWindow
---@param tabs_data table return value from M.load()
function M.restore_remaining(mux_window, tabs_data)
   for i = 2, #tabs_data do
      mux_window:spawn_tab({ cwd = tabs_data[i].cwd })
   end
   -- Return focus to first tab
   local tabs = mux_window:tabs()
   if tabs[1] then
      tabs[1]:activate()
   end
   wezterm.log_info('session.restore: restored ' .. #tabs_data .. ' tab(s)')
end

M.setup = function()
   wezterm.on('session.save', function(window, _pane)
      M.save(window)
   end)
end

return M
