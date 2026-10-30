-- utils/session.lua
-- Save and restore tab layout (cwd, domain, manual title per tab) across WezTerm restarts.
-- Save: triggered by the 'session.save' event (keybinding SUPER_REV + s).
-- Restore: orchestrated in gui-startup (see events/gui-startup.lua).
local wezterm = require('wezterm')
local cwd_util = require('utils.cwd')
local state_file = require('utils.state-file')

local M = {}

local SESSION_FILE = 'session.json'

---@class SessionTab
---@field cwd string|nil
---@field domain string|nil domain name ('local' for the default domain)
---@field title string|nil manually set tab title ('' / nil when none)

---Serialize the current window's tabs to the session file
---@param window any WezTerm GuiWindow
function M.save(window)
   ---@type SessionTab[]
   local tabs_data = {}
   for _, tab in ipairs(window:mux_window():tabs()) do
      local pane = tab:active_pane()
      table.insert(tabs_data, {
         cwd = cwd_util.get(pane),
         domain = pane:get_domain_name(),
         title = tab:get_title(),
      })
   end

   local _, err = state_file.write(SESSION_FILE, tabs_data)
   if err then
      wezterm.log_error('session.save: ' .. err)
      return
   end
   wezterm.log_info('session.save: saved ' .. #tabs_data .. ' tab(s) to ' .. state_file.path(SESSION_FILE))
end

---Load saved session data from disk.
---@return SessionTab[]|nil nil if no session file exists or it is malformed
function M.load()
   local tabs_data, err = state_file.read(SESSION_FILE)
   if err then
      wezterm.log_warn('session.restore: ' .. err)
   end
   if type(tabs_data) ~= 'table' or #tabs_data == 0 then
      return nil
   end
   return tabs_data
end

---Spawn fields (cwd + domain) for a saved tab. Unknown domains fall back to the default.
---@param entry SessionTab
---@return table SpawnCommand fields
function M.spawn_args(entry)
   local args = { cwd = entry.cwd }
   if entry.domain and entry.domain ~= 'local' then
      if wezterm.mux.get_domain(entry.domain) then
         args.domain = { DomainName = entry.domain }
      else
         wezterm.log_warn('session.restore: domain "' .. entry.domain .. '" no longer exists, using default')
         args.cwd = nil -- a path from another domain is meaningless here
      end
   end
   return args
end

---Apply saved state to tab 1 and spawn tabs 2+ into an existing MuxWindow.
---Tab 1's cwd/domain must already be handled by the caller (via spawn_window).
---@param mux_window any WezTerm MuxWindow
---@param tabs_data SessionTab[] return value from M.load()
function M.restore_remaining(mux_window, tabs_data)
   local tabs = mux_window:tabs()
   if tabs[1] and tabs_data[1].title and tabs_data[1].title ~= '' then
      tabs[1]:set_title(tabs_data[1].title)
   end

   for i = 2, #tabs_data do
      local ok, tab = pcall(function()
         return mux_window:spawn_tab(M.spawn_args(tabs_data[i]))
      end)
      if not ok then
         wezterm.log_warn('session.restore: cannot restore tab ' .. i .. ': ' .. tostring(tab))
      elseif tabs_data[i].title and tabs_data[i].title ~= '' then
         tab:set_title(tabs_data[i].title)
      end
   end

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
