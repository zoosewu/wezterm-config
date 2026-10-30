-- utils/state-file.lua
-- Small JSON state files (GPU cache, saved session) kept OUTSIDE the config dir.
--
-- WezTerm watches the config dir recursively, so writing state there triggers a full
-- config reload (and re-render) on every save. Files live in a per-user state dir:
--   Windows: %LOCALAPPDATA%/wezterm-config
--   macOS:   ~/Library/Application Support/wezterm-config
--   Linux:   $XDG_STATE_HOME/wezterm-config (default ~/.local/state/wezterm-config)
-- Set WEZTERM_STATE_DIR to override (e.g. portable installs, tests).
local wezterm = require('wezterm')
local platform = require('utils.platform')

local M = {}

-- Stable builds only have json_parse/json_encode; nightly moved them to wezterm.serde
local json_decode = wezterm.json_parse or (wezterm.serde and wezterm.serde.json_decode)
local json_encode = wezterm.json_encode or (wezterm.serde and wezterm.serde.json_encode)

local function state_dir()
   local override = os.getenv('WEZTERM_STATE_DIR')
   if override and override ~= '' then
      return (override:gsub('[/\\]$', ''))
   end
   local home = wezterm.home_dir
   if platform.is_win then
      return (os.getenv('LOCALAPPDATA') or (home .. '/AppData/Local')) .. '/wezterm-config'
   elseif platform.is_mac then
      return home .. '/Library/Application Support/wezterm-config'
   end
   return (os.getenv('XDG_STATE_HOME') or (home .. '/.local/state')) .. '/wezterm-config'
end

M.DIR = state_dir()

---@param name string file name, e.g. 'session.json'
---@return string
function M.path(name)
   return M.DIR .. '/' .. name
end

---@return boolean ok, string|nil err
local function ensure_dir()
   local cmd = platform.is_win and { 'cmd.exe', '/c', 'mkdir', (M.DIR:gsub('/', '\\')) }
      or { 'mkdir', '-p', M.DIR }
   local ok, success, _, stderr = pcall(wezterm.run_child_process, cmd)
   if ok and success then
      return true
   end
   return false, tostring(ok and stderr or success)
end

---Read and decode a state file
---@param name string
---@return any|nil data, string|nil err (nil, nil when the file does not exist)
function M.read(name)
   local f = io.open(M.path(name), 'r')
   if not f then
      return nil, nil
   end
   local content = f:read('*a')
   f:close()
   local ok, data = pcall(json_decode, content)
   if not ok then
      return nil, 'invalid JSON in ' .. M.path(name) .. ': ' .. tostring(data)
   end
   return data, nil
end

---Encode and write a state file atomically; skipped when the content is unchanged.
---Creating the state dir runs a child process, so call this from an event callback.
---@param name string
---@param data any JSON-serializable value
---@return boolean changed, string|nil err
function M.write(name, data)
   local ok, json = pcall(json_encode, data)
   if not ok then
      return false, 'encode failed: ' .. tostring(json)
   end

   local path = M.path(name)
   local current = io.open(path, 'r')
   if current then
      local same = current:read('*a') == json
      current:close()
      if same then
         return false, nil
      end
   end

   local tmp = path .. '.tmp'
   local f = io.open(tmp, 'w')
   if not f then
      local dir_ok, dir_err = ensure_dir()
      if not dir_ok then
         return false, 'cannot create ' .. M.DIR .. ': ' .. dir_err
      end
      f = io.open(tmp, 'w')
      if not f then
         return false, 'cannot write ' .. tmp
      end
   end
   f:write(json)
   f:close()

   os.remove(path) -- os.rename does not overwrite on Windows
   local renamed, rename_err = os.rename(tmp, path)
   if not renamed then
      return false, 'cannot replace ' .. path .. ': ' .. tostring(rename_err)
   end
   return true, nil
end

return M
