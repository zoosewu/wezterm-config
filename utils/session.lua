-- utils/session.lua
-- Save and restore tab layout (cwd, domain, manual title per tab) across WezTerm restarts.
-- Save: triggered by the 'session.save' event (keybinding SUPER_REV + s).
-- Restore: orchestrated in events/gui-startup.lua — by the mux server when it starts
-- (persistent sessions), otherwise by the GUI's gui-startup.
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

---Domains whose panes run on this machine. Restoring happens inside the mux server,
---where a unix domain (the server itself) is just its local domain.
---@param name string
---@return boolean
local function is_local_domain(name)
   if name == 'local' then
      return true
   end
   for _, d in ipairs(require('config.domains').unix_domains) do
      if d.name == name then
         return true
      end
   end
   return false
end

---Spawn fields (cwd + domain) for a saved tab. Unknown domains fall back to the default.
---@param entry SessionTab
---@return table SpawnCommand fields
function M.spawn_args(entry)
   local args = { cwd = entry.cwd }
   if entry.domain and not is_local_domain(entry.domain) then
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

   M.spawn_tabs(mux_window, { table.unpack(tabs_data, 2) })

   if tabs[1] then
      tabs[1]:activate()
   end
   wezterm.log_info('session.restore: restored ' .. #tabs_data .. ' tab(s)')
end

---Spawn saved tabs into an existing MuxWindow (failures are logged and skipped)
---@param mux_window any WezTerm MuxWindow
---@param tabs_data SessionTab[]
function M.spawn_tabs(mux_window, tabs_data)
   for _, entry in ipairs(tabs_data) do
      local ok, tab = pcall(function()
         return mux_window:spawn_tab(M.spawn_args(entry))
      end)
      if not ok then
         wezterm.log_warn('session.restore: cannot restore tab: ' .. tostring(tab))
      elseif entry.title and entry.title ~= '' then
         tab:set_title(entry.title)
      end
   end
end

---Split saved tabs into those that run on this machine (restored inside the mux server,
---so they survive closing the GUI) and the rest (WSL / SSH: the GUI must own them, or
---their domain, splits and tab icon would all look like the server's).
---@param tabs_data SessionTab[]
---@return SessionTab[] local_tabs, SessionTab[] gui_tabs
function M.partition(tabs_data)
   local local_tabs, gui_tabs = {}, {}
   for _, entry in ipairs(tabs_data) do
      table.insert((entry.domain == nil or is_local_domain(entry.domain)) and local_tabs or gui_tabs, entry)
   end
   return local_tabs, gui_tabs
end

-- Tabs the mux server leaves for the next attaching GUI to restore
local PENDING_FILE = 'session-pending.json'

---@param tabs_data SessionTab[]
function M.hand_to_gui(tabs_data)
   local _, err = state_file.write(PENDING_FILE, tabs_data)
   if err then
      wezterm.log_error('session.restore: ' .. err)
   end
end

---Tabs handed over by the mux server, removed once taken (each restore happens once)
---@return SessionTab[]|nil
function M.take_from_server()
   local tabs_data = state_file.read(PENDING_FILE)
   os.remove(state_file.path(PENDING_FILE))
   if type(tabs_data) ~= 'table' or #tabs_data == 0 then
      return nil
   end
   return tabs_data
end

M.setup = function()
   wezterm.on('session.save', function(window, _pane)
      M.save(window)
   end)
end

return M
