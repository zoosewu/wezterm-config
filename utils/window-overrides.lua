-- utils/window-overrides.lua
-- Centralised window config-override manager.
-- All modules that need window:set_config_overrides() should go through this
-- to avoid clobbering each other's overrides.
local M = {}

-- keyed by window_id -> { background=..., colors=..., enable_tab_bar=..., ... }
local _store = {}

---Get the override table for a window (creates one if absent)
---@param window any WezTerm Window
---@return table
function M.get(window)
   local id = window:window_id()
   if not _store[id] then
      _store[id] = {}
   end
   return _store[id]
end

---Set one override key and apply all overrides to the window
---@param window any WezTerm Window
---@param key string config key name
---@param value any config value
function M.set(window, key, value)
   local overrides = M.get(window)
   overrides[key] = value
   window:set_config_overrides(overrides)
end

---Merge multiple override keys at once and apply
---@param window any WezTerm Window
---@param patch table key-value pairs to merge into overrides
function M.patch(window, patch)
   local overrides = M.get(window)
   for k, v in pairs(patch) do
      overrides[k] = v
   end
   window:set_config_overrides(overrides)
end

---Remove the stored overrides for a window (for cleanup on window close)
---@param window_id number
function M.remove(window_id)
   _store[window_id] = nil
end

return M
