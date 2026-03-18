local wezterm = require('wezterm')
local umath = require('utils.math')
local Cells = require('utils.cells')
local OptsValidator = require('utils.opts-validator')

---@alias Event.RightStatusOptions { date_format?: string }

---Setup options for the right status bar
local EVENT_OPTS = {}

---@type OptsSchema
EVENT_OPTS.schema = {
   {
      name = 'date_format',
      type = 'string',
      default = '%a %H:%M:%S',
   },
}
EVENT_OPTS.validator = OptsValidator:new(EVENT_OPTS.schema)

local nf = wezterm.nerdfonts
local attr = Cells.attr

local M = {}

local ICON_SEPARATOR = nf.oct_dash
local ICON_DATE = nf.fa_calendar
local ICON_CWD  = nf.oct_file_directory

---@type string[]
local discharging_icons = {
   nf.md_battery_10,
   nf.md_battery_20,
   nf.md_battery_30,
   nf.md_battery_40,
   nf.md_battery_50,
   nf.md_battery_60,
   nf.md_battery_70,
   nf.md_battery_80,
   nf.md_battery_90,
   nf.md_battery,
}
---@type string[]
local charging_icons = {
   nf.md_battery_charging_10,
   nf.md_battery_charging_20,
   nf.md_battery_charging_30,
   nf.md_battery_charging_40,
   nf.md_battery_charging_50,
   nf.md_battery_charging_60,
   nf.md_battery_charging_70,
   nf.md_battery_charging_80,
   nf.md_battery_charging_90,
   nf.md_battery_charging,
}

---@type table<string, Cells.SegmentColors>
-- stylua: ignore
local colors = {
   date      = { fg = '#fab387', bg = 'rgba(0, 0, 0, 0.4)' },
   battery   = { fg = '#f9e2af', bg = 'rgba(0, 0, 0, 0.4)' },
   separator = { fg = '#74c7ec', bg = 'rgba(0, 0, 0, 0.4)' },
   cwd       = { fg = '#a6e3a1', bg = 'rgba(0, 0, 0, 0.4)' },
}

local cells = Cells:new()

cells
   :add_segment('date_icon', ICON_DATE .. '  ', colors.date, attr(attr.intensity('Bold')))
   :add_segment('date_text', '', colors.date, attr(attr.intensity('Bold')))
   :add_segment('separator',  ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('cwd_icon',   ' ' .. ICON_CWD .. ' ',        colors.cwd, attr(attr.intensity('Bold')))
   :add_segment('cwd_text',   '',                             colors.cwd)
   :add_segment('separator2', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('battery_icon', '', colors.battery)
   :add_segment('battery_text', '', colors.battery, attr(attr.intensity('Bold')))

---@return string, string
local function battery_info()
   -- ref: https://wezfurlong.org/wezterm/config/lua/wezterm/battery_info.html

   local charge = ''
   local icon = ''

   for _, b in ipairs(wezterm.battery_info()) do
      local idx = umath.clamp(umath.round(b.state_of_charge * 10), 1, 10)
      charge = string.format('%.0f%%', b.state_of_charge * 100)

      if b.state == 'Charging' then
         icon = charging_icons[idx]
      else
         icon = discharging_icons[idx]
      end
   end

   return charge, icon .. ' '
end

---Get a shortened current working directory path from the active pane
---Replaces home directory prefix with ~, shows at most last 2 path components
---@param pane any WezTerm Pane
---@return string empty string when CWD is unavailable
local function get_short_cwd(pane)
   local cwd_uri = pane:get_current_working_dir()
   if not cwd_uri then return '' end

   local path = cwd_uri.file_path or ''
   if path == '' then return '' end

   -- Replace home directory with ~
   local home = os.getenv('HOME') or os.getenv('USERPROFILE') or ''
   if home ~= '' and path:sub(1, #home) == home then
      path = '~' .. path:sub(#home + 1)
   end

   -- Show at most last 2 path components
   -- For home-relative paths, keep the ~ but show only the last component
   local short
   if path:sub(1, 2) == '~/' then
      -- e.g. ~/a/b/c → ~/b/c (keep ~ + last 2 components relative to home)
      local after_home = path:sub(3)  -- 'a/b/c' or 'Documents'
      local last2 = after_home:match('([^/\\]+[/\\][^/\\]+)[/\\]?$')
      local last1 = after_home:match('([^/\\]+)[/\\]?$')
      short = '~/' .. (last2 or last1 or after_home)
   else
      -- Absolute path: last 2 components
      local last2 = path:match('([^/\\]+[/\\][^/\\]+)[/\\]?$')
      local last1 = path:match('([^/\\]+)[/\\]?$')
      short = last2 or last1 or path
   end
   return short
end

---@param opts? Event.RightStatusOptions Default: {date_format = '%a %H:%M:%S'}
M.setup = function(opts)
   local valid_opts, err = EVENT_OPTS.validator:validate(opts or {})

   if err then
      wezterm.log_error(err)
   end

   wezterm.on('update-right-status', function(window, pane)
      local battery_text, battery_icon = battery_info()
      local cwd_short = get_short_cwd(pane)

      cells
         :update_segment_text('date_text',    wezterm.strftime(valid_opts.date_format))
         :update_segment_text('cwd_text',     cwd_short)
         :update_segment_text('battery_icon', battery_icon)
         :update_segment_text('battery_text', battery_text)

      -- Build render list conditionally
      local render_ids = { 'date_icon', 'date_text' }
      if cwd_short ~= '' then
         table.insert(render_ids, 'separator')
         table.insert(render_ids, 'cwd_icon')
         table.insert(render_ids, 'cwd_text')
      end
      if battery_text ~= '' then
         table.insert(render_ids, 'separator2')
         table.insert(render_ids, 'battery_icon')
         table.insert(render_ids, 'battery_text')
      end

      window:set_right_status(wezterm.format(cells:render(render_ids)))
   end)
end

return M
