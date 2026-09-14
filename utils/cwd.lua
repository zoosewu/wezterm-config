-- utils/cwd.lua
-- Helpers for inheriting the current pane's working directory when spawning
-- new tabs / panes / windows.
--
-- `pane:get_current_working_dir()` returns a Url object on recent WezTerm
-- versions and a plain `file://` string on older ones; on Windows the decoded
-- path may additionally carry a leading slash (`/C:/Users/...`). This module
-- normalises both cases into a path WezTerm's `cwd` field accepts.
--
-- Which getter to use depends on the domain being spawned into:
--   * same domain as the current pane  -> `get()`
--   * host/default domain              -> `get_local()`
--   * a WSL domain                     -> `to_wsl(get())`
--   * ssh/unix domains                 -> no cwd (a local path is meaningless)

local platform = require('utils.platform')

local M = {}

---Normalise a raw cwd value into a plain filesystem path
---@param raw any Url object or `file://` string returned by WezTerm
---@return string|nil
local function normalise(raw)
   if raw == nil then
      return nil
   end

   local path
   if type(raw) == 'userdata' or type(raw) == 'table' then
      path = raw.file_path
   elseif type(raw) == 'string' then
      -- legacy WezTerm returned the raw `file://host/path` string
      path = raw:gsub('^file://[^/]*', '')
   end

   if path == nil or path == '' then
      return nil
   end

   -- Windows: strip the leading slash from `/C:/Users/...`
   path = path:gsub('^/([A-Za-z]:)', '%1')

   return path
end

---Get the current working directory of a pane, as reported by the shell
---@param pane any WezTerm Pane
---@return string|nil
function M.get(pane)
   if not pane then
      return nil
   end

   local ok, raw = pcall(function()
      return pane:get_current_working_dir()
   end)
   if not ok then
      return nil
   end

   return normalise(raw)
end

---Get the pane's cwd only if the host shell can actually use it.
---A WSL/SSH pane reports a POSIX path, which a Windows shell cannot chdir to,
---so in that case fall back to nil (WezTerm then uses its own default).
---@param pane any WezTerm Pane
---@return string|nil
function M.get_local(pane)
   local path = M.get(pane)
   if path == nil then
      return nil
   end

   if platform.is_win and not path:match('^[A-Za-z]:') then
      return nil
   end

   return path
end

---Translate a Windows path into its WSL equivalent (`C:\x` -> `/mnt/c/x`)
---Paths that are already POSIX-style are returned unchanged.
---@param path string|nil
---@return string|nil
function M.to_wsl(path)
   if path == nil then
      return nil
   end

   local drive, rest = path:match('^([A-Za-z]):[/\\](.*)$')
   if not drive then
      return path
   end

   rest = rest:gsub('\\', '/')
   return '/mnt/' .. drive:lower() .. '/' .. rest
end

return M
