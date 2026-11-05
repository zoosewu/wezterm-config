-- utils/process-name.lua
-- Foreground process name of a pane, without paying for a process snapshot.
--
-- pane:get_foreground_process_name() snapshots processes (~5-20ms on Windows, on the
-- GUI thread). format-tab-title already receives WezTerm's cached name for every
-- tab's active pane, and the tab bar redraws at least every status tick, so names
-- recorded there are fresh. Only panes never seen by the tab bar fall back to a
-- direct (rate-limited) lookup.

local M = {}

local FRESH_SECONDS = 5

-- pane_id -> { name, at }; pure cache, losing it on reload is harmless
local seen, seen_size = {}, 0
local LIMIT = 128

---Strip directories and `.exe` from a process path
---@param proc string|nil
---@return string
function M.clean(proc)
   local name = (proc or ''):gsub('^.*[/\\]', ''):gsub('%.exe$', '')
   return name
end

---@param pane_id number
---@param name string cleaned name
local function store(pane_id, name)
   if not seen[pane_id] then
      if seen_size >= LIMIT then
         seen, seen_size = {}, 0
      end
      seen_size = seen_size + 1
   end
   seen[pane_id] = { name = name, at = os.time() }
end

---Record the name WezTerm reported for a pane (call from format-tab-title)
---@param pane_id number
---@param raw_name string|nil foreground_process_name from PaneInformation
---@return string cleaned name
function M.remember(pane_id, raw_name)
   local name = M.clean(raw_name)
   store(pane_id, name)
   return name
end

---Cleaned foreground process name of a live Pane object. Panes in a mux domain (persistent
---sessions) report no process, so their title stands in: "pwsh.exe",
---"Administrator: C:\...\pwsh.exe" and "vim notes.md" become pwsh / pwsh / vim.
---@param pane any WezTerm Pane
---@return string
function M.get(pane)
   local id = pane:pane_id()
   local hit = seen[id]
   local name
   if hit and os.time() - hit.at < FRESH_SECONDS then
      name = hit.name
   else
      name = M.remember(id, pane:get_foreground_process_name())
   end
   if name == '' then
      local title = (pane:get_title() or ''):gsub('^.*: ', '')
      -- a whole executable path may contain spaces ("Program Files"); otherwise "cmd args"
      name = M.clean(title:match('%.exe$') and title or title:match('^%S*'))
   end
   return name
end

return M
