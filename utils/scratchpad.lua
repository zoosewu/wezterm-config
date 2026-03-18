-- utils/scratchpad.lua
-- Toggle a scratchpad pane at the bottom of the current tab.
-- Tracks scratchpad pane IDs per tab to allow toggle behaviour.
local wezterm = require('wezterm')
local act = wezterm.action

local M = {}

-- per-tab scratchpad pane tracking: tab_id -> pane_id
local _scratchpad_panes = {}

---Find a pane's 0-based index within its tab by pane_id
---@param tab any WezTerm MuxTab
---@param target_pane_id number
---@return number|nil pane_index (0-based for ActivatePaneByIndex)
local function find_pane_index(tab, target_pane_id)
   for idx, info in ipairs(tab:panes_with_info()) do
      if info.pane:pane_id() == target_pane_id then
         return idx - 1
      end
   end
   return nil
end

M.setup = function()
   wezterm.on('scratchpad.toggle', function(window, pane)
      local tab = window:active_tab()
      local tab_id = tab:tab_id()
      local scratch_id = _scratchpad_panes[tab_id]

      if scratch_id then
         local pane_idx = find_pane_index(tab, scratch_id)
         if pane_idx then
            -- Scratchpad still exists
            if pane:pane_id() == scratch_id then
               -- Currently on scratchpad → switch to first non-scratchpad pane
               for _, info in ipairs(tab:panes_with_info()) do
                  if info.pane:pane_id() ~= scratch_id then
                     info.pane:activate()
                     return
                  end
               end
            else
               -- Focus scratchpad
               window:perform_action(act.ActivatePaneByIndex(pane_idx), pane)
            end
            return
         else
            -- Pane was closed externally — clear stale entry
            _scratchpad_panes[tab_id] = nil
         end
      end

      -- Create new scratchpad pane (25% of current pane height)
      local new_pane = pane:split({
         direction = 'Bottom',
         size = 0.25,
      })
      if new_pane then
         _scratchpad_panes[tab_id] = new_pane:pane_id()
         wezterm.log_info('scratchpad: created pane ' .. tostring(new_pane:pane_id()) .. ' for tab ' .. tostring(tab_id))
      end
   end)
end

return M
