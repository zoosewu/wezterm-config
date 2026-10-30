-- utils/cwd.lua
-- A pane's working directory: reading it, translating it for the domain a new
-- tab / pane / window is spawned into, and shortening it for display.
--
-- `pane:get_current_working_dir()` returns a Url object on recent WezTerm
-- versions and a plain `file://` string on older ones; on Windows the decoded
-- path may additionally carry a leading slash (`/C:/Users/...`). This module
-- normalises both cases into a path WezTerm's `cwd` field accepts.
--
-- `for_domain()` picks the right translation for the target domain:
--   * same domain as the current pane  -> path as reported
--   * host/default domain              -> path only if the host shell can use it
--   * a WSL domain                     -> Windows path mapped to /mnt/<drive>/...
--   * ssh/unix domains                 -> no cwd (a local path is meaningless)

local wezterm = require('wezterm')
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
local function get_local(pane)
   local path = M.get(pane)
   if path == nil then
      return nil
   end

   if platform.is_win and not path:match('^[A-Za-z]:') then
      return nil
   end

   return path
end

-- Home directory with forward slashes (WezTerm reports cwd paths that way on Windows too)
local HOME = (wezterm.home_dir or ''):gsub('\\', '/'):gsub('/$', '')

---Shorten a path for display: home prefix -> `~`, keep at most the last 2 components
---@param path string|nil
---@return string empty string when path is nil/empty
function M.shorten(path)
   if path == nil or path == '' then
      return ''
   end
   path = path:gsub('\\', '/')

   local prefix = ''
   local head = path:sub(1, #HOME)
   -- Windows paths are case-insensitive (`c:/users` vs `C:/Users`)
   if HOME ~= '' and (head == HOME or (platform.is_win and head:lower() == HOME:lower())) then
      local rest = path:sub(#HOME + 1)
      if rest == '' or rest:sub(1, 1) == '/' then
         prefix, path = '~/', rest:gsub('^/', '')
         if path == '' then
            return '~'
         end
      end
   end

   local last2 = path:match('([^/]+/[^/]+)/?$')
   return prefix .. (last2 or path:match('([^/]+)/?$') or path)
end

---Translate a Windows path into its WSL equivalent (`C:\x` -> `/mnt/c/x`)
---Paths that are already POSIX-style are returned unchanged.
---@param path string|nil
---@return string|nil
local function to_wsl(path)
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

---@param name string|nil domain name
---@return boolean
function M.is_wsl_domain(name)
   return type(name) == 'string' and name:lower():match('^wsl') ~= nil
end

---The pane's cwd translated for spawning into `domain`
---@param pane any WezTerm Pane the new tab/pane/window inherits from
---@param domain any SpawnCommand domain: 'DefaultDomain' | 'CurrentPaneDomain' | { DomainName = name }
---@return string|nil cwd (nil lets WezTerm use the domain's default)
function M.for_domain(pane, domain)
   if domain == nil or domain == 'CurrentPaneDomain' then
      return M.get(pane)
   elseif domain == 'DefaultDomain' then
      return get_local(pane)
   end
   local name = type(domain) == 'table' and domain.DomainName
   if name == 'local' then
      return get_local(pane)
   elseif M.is_wsl_domain(name) then
      return to_wsl(M.get(pane))
   end
   return nil -- ssh / unix: a local path is meaningless there
end

return M
