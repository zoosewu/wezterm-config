-- events/status.lua
-- Left status (key table / leader, workspace, pane process) and right status
-- (date, cwd, battery) from a single `update-status` handler, which WezTerm calls
-- every `status_update_interval` ms per window.
--
-- The process name comes from utils/process-name (no process snapshot), cwd is cached
-- per pane for a few seconds, and a status string is only sent when it changed.

local wezterm = require('wezterm')
local cwd_util = require('utils.cwd')
local segment = require('utils.segment')
local process_name = require('utils.process-name')

---@alias Event.StatusOptions { date_format?: string }

local nf = wezterm.nerdfonts
local append = segment.append

local M = {}

local GLYPH_SCIRCLE_LEFT = nf.ple_left_half_circle_thick
local GLYPH_SCIRCLE_RIGHT = nf.ple_right_half_circle_thick
local GLYPH_KEY_TABLE = nf.md_table_key
local GLYPH_KEY = nf.md_key
local GLYPH_WORKSPACE = nf.md_layers_triple
local GLYPH_PANE = nf.oct_terminal
local GLYPH_SEPARATOR = nf.oct_dash
local GLYPH_DATE = nf.fa_calendar
local GLYPH_CWD = nf.oct_file_directory

-- stylua: ignore
local BATTERY_ICONS = {
   Charging = {
      nf.md_battery_charging_10, nf.md_battery_charging_20, nf.md_battery_charging_30, nf.md_battery_charging_40,
      nf.md_battery_charging_50, nf.md_battery_charging_60, nf.md_battery_charging_70, nf.md_battery_charging_80,
      nf.md_battery_charging_90, nf.md_battery_charging,
   },
   Discharging = {
      nf.md_battery_10, nf.md_battery_20, nf.md_battery_30, nf.md_battery_40, nf.md_battery_50,
      nf.md_battery_60, nf.md_battery_70, nf.md_battery_80, nf.md_battery_90, nf.md_battery,
   },
}

local DIM = 'rgba(0, 0, 0, 0.4)'
-- stylua: ignore
local COLORS = {
   keytable  = { fill = { bg = '#fab387', fg = '#1c1b19' }, edge = { bg = DIM, fg = '#fab387' } },
   workspace = { fill = { bg = '#cba6f7', fg = '#1c1b19' }, edge = { bg = DIM, fg = '#cba6f7' } },
   pane      = { fill = { bg = '#a6e3a1', fg = '#1c1b19' }, edge = { bg = DIM, fg = '#a6e3a1' } },
   date      = { fg = '#fab387', bg = DIM },
   battery   = { fg = '#f9e2af', bg = DIM },
   separator = { fg = '#74c7ec', bg = DIM },
   cwd       = { fg = '#a6e3a1', bg = DIM },
}

-- Seconds a cached lookup stays valid
local TTL = { cwd = 2, battery = 30 }

-- key -> { value, expires }; pure cache, losing it on reload is harmless
local cache, cache_size = {}, 0
local CACHE_LIMIT = 128

---@param key string
---@param ttl number seconds
---@param fetch fun(): any
local function cached(key, ttl, fetch)
   local now = os.time()
   local hit = cache[key]
   if hit and hit.expires > now then
      return hit.value
   end
   if not hit then
      if cache_size >= CACHE_LIMIT then
         cache, cache_size = {}, 0
      end
      cache_size = cache_size + 1
   end
   local value = fetch()
   cache[key] = { value = value, expires = now + ttl }
   return value
end

---@return string text, string icon ('' when there is no battery)
local function battery()
   local text, icon = '', ''
   for _, b in ipairs(wezterm.battery_info()) do
      local idx = math.max(1, math.min(10, math.floor(b.state_of_charge * 10 + 0.5)))
      text = string.format('%.0f%%', b.state_of_charge * 100)
      icon = (BATTERY_ICONS[b.state] or BATTERY_ICONS.Discharging)[idx] .. ' '
   end
   return text, icon
end

---@param items table[]
---@param colors table { fill, edge }
---@param icon string
---@param text string
local function pill(items, colors, icon, text)
   append(items, GLYPH_SCIRCLE_LEFT, colors.edge, true)
   append(items, icon, colors.fill, true)
   append(items, text, colors.fill, true)
   append(items, GLYPH_SCIRCLE_RIGHT, colors.edge, true)
end

---@param window any GuiWindow
---@param pane any Pane
---@return string
local function left_status(window, pane)
   local items = {}
   local key_table = window:active_key_table()
   if window:leader_is_active() then
      pill(items, COLORS.keytable, GLYPH_KEY, ' ')
   elseif key_table then
      pill(items, COLORS.keytable, GLYPH_KEY_TABLE, ' ' .. key_table:upper())
   end

   local workspace = wezterm.mux.get_active_workspace()
   pill(items, COLORS.workspace, ' ' .. GLYPH_WORKSPACE, ' ' .. (workspace ~= '' and workspace or 'default'))

   local process = process_name.get(pane)
   if process ~= '' then
      pill(items, COLORS.pane, ' ' .. GLYPH_PANE, ' ' .. process)
   end
   return wezterm.format(items)
end

---@param pane any Pane
---@param date_format string
---@return string
local function right_status(pane, date_format)
   local items = {}
   append(items, GLYPH_DATE .. '  ', COLORS.date, true)
   append(items, wezterm.strftime(date_format), COLORS.date, true)

   local cwd = cached('cwd:' .. pane:pane_id(), TTL.cwd, function()
      return cwd_util.shorten(cwd_util.get(pane))
   end)
   if cwd ~= '' then
      append(items, ' ' .. GLYPH_SEPARATOR .. '  ', COLORS.separator)
      append(items, ' ' .. GLYPH_CWD .. ' ', COLORS.cwd, true)
      append(items, cwd, COLORS.cwd)
   end

   local bat = cached('battery', TTL.battery, function()
      local text, icon = battery()
      return { text = text, icon = icon }
   end)
   if bat.text ~= '' then
      append(items, ' ' .. GLYPH_SEPARATOR .. '  ', COLORS.separator)
      append(items, bat.icon, COLORS.battery)
      append(items, bat.text, COLORS.battery, true)
   end
   append(items, '   ')
   return wezterm.format(items)
end

-- window_id -> { left, right } last strings sent
local last_sent = {}

---@param opts? Event.StatusOptions Default: {date_format = '%a %H:%M:%S'}
M.setup = function(opts)
   local date_format = (opts and opts.date_format) or '%a %H:%M:%S'

   wezterm.on('update-status', function(window, pane)
      local id = window:window_id()
      local sent = last_sent[id] or {}
      last_sent[id] = sent

      local left = left_status(window, pane)
      if left ~= sent.left then
         window:set_left_status(left)
         sent.left = left
      end

      local right = right_status(pane, date_format)
      if right ~= sent.right then
         window:set_right_status(right)
         sent.right = right
      end
   end)
end

return M
