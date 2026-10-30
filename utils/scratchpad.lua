-- utils/scratchpad.lua
-- Toggle a scratchpad pane at the bottom of the current tab.
-- Tracks scratchpad pane IDs per tab to allow toggle behaviour.
local wezterm = require('wezterm')
local cwd_util = require('utils.cwd')
local window_state = require('utils.window-state')
local act = wezterm.action

local M = {}

-- per-tab {pane_id}; survives config reloads so toggle never spawns a duplicate
local scratchpads = window_state.namespace('scratchpad', 'tab')

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
      local entry = scratchpads:get(tab_id)
      local scratch_id = entry and entry.pane_id

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
            scratchpads:set(tab_id, nil)
         end
      end

      -- Create new scratchpad pane (25% of current pane height, same CWD)
      local new_pane = pane:split({
         direction = 'Bottom',
         size = 0.25,
         cwd = cwd_util.get(pane),
      })
      if new_pane then
         scratchpads:set(tab_id, { pane_id = new_pane:pane_id() })
         wezterm.log_info('scratchpad: created pane ' .. tostring(new_pane:pane_id()) .. ' for tab ' .. tostring(tab_id))
      end
   end)
end

return M
