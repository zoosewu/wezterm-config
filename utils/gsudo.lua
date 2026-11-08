-- utils/gsudo.lua
-- Elevation on Windows through gsudo (https://github.com/gerardog/gsudo): `gsudo <cmd>`
-- runs one command as administrator inside the current pane, and the launch menu gets a
-- "PowerShell (Admin)" entry. Only the panes that need it are elevated, which also keeps
-- the persistent-session mux server (and every other pane) unelevated.
--
-- When gsudo is missing it is installed in the background after the first window is
-- shown: scoop (per-user, no UAC prompt) when available, otherwise winget (per-machine
-- MSI, one UAC prompt). A failed attempt is not retried for a day, so a cancelled UAC
-- prompt or an offline launch does not nag on every start. Success reloads the config.
local wezterm = require('wezterm')
local platform = require('utils.platform')
local startup = require('utils.startup')
local state_file = require('utils.state-file')

local M = {}

local STATE_FILE = 'gsudo-install.json'
local RETRY_SECONDS = 24 * 3600

---@param path string
---@return boolean
local function exists(path)
   local f = io.open(path, 'rb')
   if f then
      f:close()
      return true
   end
   return false
end

---@return string scoop root
local function scoop_dir()
   return (os.getenv('SCOOP') or (wezterm.home_dir .. '/scoop')):gsub('\\', '/')
end

---Absolute path of gsudo.exe, or nil. Uses io.open only, so it is safe while the
---config is evaluated. Install locations are checked besides PATH because a running
---WezTerm keeps the PATH it started with.
---@return string|nil
function M.path()
   if not platform.is_win then
      return nil
   end
   local candidates = {
      scoop_dir() .. '/apps/gsudo/current/gsudo.exe', -- scoop adds this dir to PATH (no shim)
      (os.getenv('ProgramFiles') or 'C:/Program Files') .. '/gsudo/Current/gsudo.exe',
   }
   for dir in (os.getenv('PATH') or ''):gmatch('[^;]+') do
      table.insert(candidates, dir .. '/gsudo.exe')
   end
   for _, candidate in ipairs(candidates) do
      if exists(candidate) then
         return (candidate:gsub('\\', '/'))
      end
   end
   return nil
end

---@return string[]|nil command, string|nil manager
local function install_command()
   local scoop = scoop_dir() .. '/shims/scoop.cmd'
   if exists(scoop) then
      return { 'cmd.exe', '/c', scoop, 'install', 'gsudo' }, 'scoop'
   end
   local winget = (os.getenv('LOCALAPPDATA') or '') .. '/Microsoft/WindowsApps/winget.exe'
   if exists(winget) then
      return { winget, 'install', '-e', '--id', 'gerardog.gsudo', '--silent', '--disable-interactivity',
         '--accept-package-agreements', '--accept-source-agreements' }, 'winget'
   end
   return nil, nil
end

---@param msg string
local function notify(msg)
   wezterm.log_info('[gsudo] ' .. msg)
   local ok, windows = pcall(function() return wezterm.gui.gui_windows() end)
   if ok and windows[1] then
      windows[1]:toast_notification('WezTerm config', msg, nil, 8000)
   end
end

local function install()
   local state = state_file.read(STATE_FILE)
   local last = type(state) == 'table' and tonumber(state.last_attempt) or 0
   if os.time() - last < RETRY_SECONDS then
      wezterm.log_info('[gsudo] not installed; last attempt failed recently, retrying later')
      return
   end

   local cmd, manager = install_command()
   if not cmd then
      wezterm.log_warn('[gsudo] not installed and neither scoop nor winget is available')
      return
   end
   wezterm.log_info('[gsudo] installing with ' .. manager)
   local ok, success, stdout, stderr = pcall(wezterm.run_child_process, cmd)
   if ok and success and M.path() then
      os.remove(state_file.path(STATE_FILE))
      notify('gsudo installed (' .. manager .. '): use `gsudo <command>` or the "PowerShell (Admin)" launcher')
      wezterm.reload_configuration()
      return
   end
   state_file.write(STATE_FILE, { last_attempt = os.time() })
   -- scoop reports errors on stdout
   local output = ok and ((stderr or '') .. (stdout or '')):sub(-500) or tostring(success)
   wezterm.log_warn('[gsudo] install with ' .. manager .. ' failed: ' .. output)
end

---Install gsudo in the background when it is missing (Windows only)
---@param opts? { auto_install?: boolean }
function M.setup(opts)
   if not platform.is_win or (opts and opts.auto_install == false) or M.path() then
      return
   end
   startup.defer('gsudo', install)
end

return M
