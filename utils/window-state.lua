-- utils/window-state.lua
-- Per-window / per-tab state that survives config reloads.
--
-- Every reload replaces the Lua state, so module-local tables are wiped while the
-- windows (and their overrides) live on. This module keeps all such state in places
-- that outlive the Lua state:
--   * config overrides: read back from the window itself before merging
--   * other state: JSON in `wezterm.GLOBAL`, pruned of closed windows/tabs on every write
--     (WezTerm has no window-closed event to clean up on)
local wezterm = require('wezterm')

local M = {}

---Set one config override key without clobbering overrides set elsewhere
---@param window any WezTerm Window
---@param key string config key name
---@param value any config value (nil removes the override)
function M.set_override(window, key, value)
   local overrides = window:get_config_overrides() or {}
   overrides[key] = value
   window:set_config_overrides(overrides)
end

local ALIVE = {
   window = function(id) return wezterm.mux.get_window(id) ~= nil end,
   tab = function(id) return wezterm.mux.get_tab(id) ~= nil end,
}

-- Stable builds only have json_parse/json_encode; nightly moved them to wezterm.serde
local json_decode = wezterm.json_parse or (wezterm.serde and wezterm.serde.json_decode)
local json_encode = wezterm.json_encode or (wezterm.serde and wezterm.serde.json_encode)

---@class WindowStateNamespace
---@field private _key string
---@field private _alive fun(id: number): boolean
local Namespace = {}
Namespace.__index = Namespace

-- Each namespace is one JSON string at the top level of wezterm.GLOBAL: nested GLOBAL
-- values come back as opaque `Value` userdata (no arithmetic / equality with numbers),
-- and GLOBAL does not drop keys assigned nil.
---@private
---@return table<string, table>
function Namespace:_load()
   local raw = wezterm.GLOBAL[self._key]
   local ok, all = pcall(json_decode, raw or '{}')
   return (ok and type(all) == 'table') and all or {}
end

---@param id number window_id or tab_id
---@return table|nil state plain table; mutate it and pass back to `set`
function Namespace:get(id)
   return self:_load()[tostring(id)]
end

---@param id number window_id or tab_id
---@param value table|nil JSON-serializable table; nil removes it
function Namespace:set(id, value)
   local key = tostring(id)
   local next_all = {}
   for k, v in pairs(self:_load()) do
      if k ~= key and self._alive(tonumber(k)) then
         next_all[k] = v
      end
   end
   next_all[key] = value
   wezterm.GLOBAL[self._key] = json_encode(next_all)
end

---Get a state namespace whose entries are keyed by window or tab id
---@param name string unique namespace name
---@param kind 'window'|'tab' what the ids refer to (used to prune closed ones)
---@return WindowStateNamespace
function M.namespace(name, kind)
   assert(ALIVE[kind], 'window-state: kind must be "window" or "tab"')
   return setmetatable({ _key = 'window_state.' .. name, _alive = ALIVE[kind] }, Namespace)
end

return M
