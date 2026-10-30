------------------------------------------------------------------------------------------
-- Inspired by https://github.com/wez/wezterm/discussions/628#discussioncomment-1874614 --
------------------------------------------------------------------------------------------
-- format-tab-title runs for every tab on every tab-bar redraw, so rendering is a pure
-- function of the tab's visible facts, memoised by those facts.
-- Manually set titles live in the mux (tab:set_title), so they survive config reloads.

local wezterm = require('wezterm')
local window_state = require('utils.window-state')
local segment = require('utils.segment')
local process_name = require('utils.process-name')
local cwd_util = require('utils.cwd')

---@alias Event.TabTitleOptions { unseen_icon: 'circle' | 'numbered_circle' | 'numbered_box', hide_active_tab_unseen: boolean }

local nf = wezterm.nerdfonts

local M = {}

local GLYPH_SCIRCLE_LEFT = nf.ple_left_half_circle_thick --[[  ]]
local GLYPH_SCIRCLE_RIGHT = nf.ple_right_half_circle_thick --[[  ]]
local GLYPH_CIRCLE = nf.fa_circle --[[  ]]
local GLYPH_ADMIN = nf.md_shield_half_full --[[ 󰞀 ]]
local GLYPH_LINUX = nf.cod_terminal_linux --[[  ]]
local GLYPH_DEBUG = nf.fa_bug --[[  ]]
local GLYPH_SEARCH = '🔭'

local GLYPH_UNSEEN = {
   numbered_box = {
      nf.md_numeric_1_box_multiple, --[[ 󰼏 ]]
      nf.md_numeric_2_box_multiple, --[[ 󰼐 ]]
      nf.md_numeric_3_box_multiple, --[[ 󰼑 ]]
      nf.md_numeric_4_box_multiple, --[[ 󰼒 ]]
      nf.md_numeric_5_box_multiple, --[[ 󰼓 ]]
      nf.md_numeric_6_box_multiple, --[[ 󰼔 ]]
      nf.md_numeric_7_box_multiple, --[[ 󰼕 ]]
      nf.md_numeric_8_box_multiple, --[[ 󰼖 ]]
      nf.md_numeric_9_box_multiple, --[[ 󰼗 ]]
      nf.md_numeric_9_plus_box_multiple, --[[ 󰼘 ]]
   },
   numbered_circle = {
      nf.md_numeric_1_circle, --[[ 󰲠 ]]
      nf.md_numeric_2_circle, --[[ 󰲢 ]]
      nf.md_numeric_3_circle, --[[ 󰲤 ]]
      nf.md_numeric_4_circle, --[[ 󰲦 ]]
      nf.md_numeric_5_circle, --[[ 󰲨 ]]
      nf.md_numeric_6_circle, --[[ 󰲪 ]]
      nf.md_numeric_7_circle, --[[ 󰲬 ]]
      nf.md_numeric_8_circle, --[[ 󰲮 ]]
      nf.md_numeric_9_circle, --[[ 󰲰 ]]
      nf.md_numeric_9_plus_circle, --[[ 󰲲 ]]
   },
}
local MAX_UNSEEN = 10

-- Columns taken by everything except the title text
local INSET = { DEFAULT = 6, ICON = 8, UNSEEN = 2, SPECIAL_TITLE = -2 }

-- stylua: ignore
local PALETTE = {
   default = { text = { bg = '#45475A', fg = '#1C1B19' }, unseen = { bg = '#45475A', fg = '#FFA066' }, scircle = { bg = 'rgba(0, 0, 0, 0.4)', fg = '#45475A' } },
   hover   = { text = { bg = '#5D87A3', fg = '#1C1B19' }, unseen = { bg = '#5D87A3', fg = '#FFA066' }, scircle = { bg = 'rgba(0, 0, 0, 0.4)', fg = '#5D87A3' } },
   active  = { text = { bg = '#74c7ec', fg = '#11111B' }, unseen = { bg = '#74c7ec', fg = '#FFA066' }, scircle = { bg = 'rgba(0, 0, 0, 0.4)', fg = '#74C7EC' } },
}

local ADMIN_TITLE_PATTERNS = { '^Administrator:%s', '%([Aa]dmin%)', '^系統管理員:', '^管理员:' }

---@param title string
---@return boolean
local function is_admin_title(title)
   for _, pattern in ipairs(ADMIN_TITLE_PATTERNS) do
      if title:match(pattern) then
         return true
      end
   end
   return false
end

---Truncate or pad `text` to exactly `width` display columns (CJK / emoji aware)
---@param text string
---@param width number
---@return string
local function fit(text, width)
   width = math.max(0, width)
   if wezterm.column_width(text) > width then
      text = wezterm.truncate_right(text, width)
   end
   return text .. string.rep(' ', width - wezterm.column_width(text))
end

---@param panes table[] PaneInformation list
---@return number count of panes with unseen output, capped at MAX_UNSEEN
local function count_unseen(panes)
   local count = 0
   for _, p in ipairs(panes) do
      if p.has_unseen_output then
         count = count + 1
         if count >= MAX_UNSEEN then
            break
         end
      end
   end
   return count
end

---@class TabTitleFacts
---@field title string raw title (before fitting)
---@field state 'default'|'hover'|'active'
---@field icon 'admin'|'wsl'|nil
---@field unseen number unseen output pane count (0 = none)
---@field max_width number

---Pure renderer: facts -> FormatItem[]
---@param f TabTitleFacts
---@param unseen_icon string
---@return table[]
local function render(f, unseen_icon)
   local title = f.title
   local inset = f.icon and INSET.ICON or INSET.DEFAULT
   if f.unseen > 0 then
      inset = inset + INSET.UNSEEN
   end
   if title == 'Debug' then
      title = GLYPH_DEBUG .. ' DEBUG'
      inset = inset + INSET.SPECIAL_TITLE
   elseif title:match('^InputSelector:') then
      title = title:gsub('^InputSelector:', GLYPH_SEARCH)
      inset = inset + INSET.SPECIAL_TITLE
   end

   local colors = PALETTE[f.state]
   local append = segment.append
   local items = {}
   append(items, GLYPH_SCIRCLE_LEFT, colors.scircle)
   if f.icon == 'wsl' then
      append(items, ' ' .. GLYPH_LINUX, colors.text)
   elseif f.icon == 'admin' then
      append(items, ' ' .. GLYPH_ADMIN, colors.text)
   end
   append(items, ' ' .. fit(title, f.max_width - inset), colors.text, true)
   if f.unseen > 0 then
      local glyphs = GLYPH_UNSEEN[unseen_icon]
      append(items, ' ' .. (glyphs and glyphs[f.unseen] or GLYPH_CIRCLE), colors.unseen)
   end
   append(items, ' ', colors.text)
   append(items, GLYPH_SCIRCLE_RIGHT, colors.scircle)
   return items
end

---Extract the facts that determine a tab's appearance
---@param tab table TabInformation
---@param hover boolean
---@param max_width number
---@param opts Event.TabTitleOptions
---@return TabTitleFacts
local function facts(tab, hover, max_width, opts)
   local pane = tab.active_pane
   local pane_title = pane.title or ''
   local process = process_name.remember(pane.pane_id, pane.foreground_process_name)

   local title
   if tab.tab_title and tab.tab_title ~= '' then
      title = tab.tab_title -- set manually via tabs.manual-update-tab-title
   elseif process ~= '' then
      title = process .. ' ~ ' .. pane_title
   else
      title = pane_title
   end

   local icon = nil
   if cwd_util.is_wsl_domain(pane.domain_name) or process:match('^wsl') then
      icon = 'wsl'
   elseif is_admin_title(pane_title) then
      icon = 'admin'
   end

   local unseen = 0
   if not (opts.hide_active_tab_unseen and tab.is_active) then
      unseen = count_unseen(tab.panes)
   end

   return {
      title = title,
      state = tab.is_active and 'active' or (hover and 'hover' or 'default'),
      icon = icon,
      unseen = unseen,
      max_width = max_width,
   }
end

-- Memo of rendered titles. Pure function of the key, so losing it on reload is harmless.
local MEMO_LIMIT = 256
local memo, memo_size = {}, 0

---@param f TabTitleFacts
---@param unseen_icon string
---@return table[]
local function render_memoised(f, unseen_icon)
   local key = table.concat({ f.state, f.icon or '', f.unseen, f.max_width, f.title }, '\0')
   local hit = memo[key]
   if hit then
      return hit
   end
   if memo_size >= MEMO_LIMIT then
      memo, memo_size = {}, 0
   end
   hit = render(f, unseen_icon)
   memo[key], memo_size = hit, memo_size + 1
   return hit
end

---@param opts? Event.TabTitleOptions Default: {unseen_icon = 'circle', hide_active_tab_unseen = true}
M.setup = function(opts)
   opts = opts or {}
   ---@type Event.TabTitleOptions
   local valid_opts = {
      unseen_icon = opts.unseen_icon or 'circle',
      hide_active_tab_unseen = opts.hide_active_tab_unseen ~= false,
   }
   if valid_opts.unseen_icon ~= 'circle' and not GLYPH_UNSEEN[valid_opts.unseen_icon] then
      wezterm.log_error('tab-title: unknown unseen_icon "' .. tostring(valid_opts.unseen_icon) .. '", using circle')
      valid_opts.unseen_icon = 'circle'
   end

   -- CUSTOM EVENT
   -- Manually set the tab name; it stays until `tabs.reset-tab-title` (or an empty name)
   wezterm.on('tabs.manual-update-tab-title', function(window, pane)
      window:perform_action(
         wezterm.action.PromptInputLine({
            description = wezterm.format({
               { Foreground = { Color = '#FFFFFF' } },
               { Attribute = { Intensity = 'Bold' } },
               { Text = 'Enter new name for tab' },
            }),
            action = wezterm.action_callback(function(win, _pane, line)
               if line ~= nil then
                  win:active_tab():set_title(line)
               end
            end),
         }),
         pane
      )
   end)

   -- CUSTOM EVENT
   -- Drop the manually set tab name
   wezterm.on('tabs.reset-tab-title', function(window, _pane)
      window:active_tab():set_title('')
   end)

   -- CUSTOM EVENT
   wezterm.on('tabs.toggle-tab-bar', function(window, _pane)
      -- Prefer the override: effective_config() lags behind set_config_overrides and builds the full config
      local current = (window:get_config_overrides() or {}).enable_tab_bar
      if current == nil then
         current = window:effective_config().enable_tab_bar
      end
      window_state.set_override(window, 'enable_tab_bar', not current)
   end)

   -- BUILTIN EVENT
   wezterm.on('format-tab-title', function(tab, _tabs, _panes, _config, hover, max_width)
      return render_memoised(facts(tab, hover, max_width, valid_opts), valid_opts.unseen_icon)
   end)
end

return M
