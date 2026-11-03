-- utils/keymap-help.lua
-- Searchable keybinding cheat sheet (InputSelector), generated from config/bindings.lua
-- so it never drifts from the real bindings. Two bindings per row (same section) to use
-- the width; fuzzy search matches either one.
-- Descriptions below are display-only; bindings without one fall back to the action name.
local wezterm = require('wezterm')
local platform = require('utils.platform')
local act = wezterm.action

local M = {}

local SUPER = platform.mods.SUPER
local SUPER_REV = platform.mods.SUPER_REV

-- stylua: ignore
local SECTIONS = {
   { '功能鍵', {
      { 'F1', 'Copy Mode' }, { 'F2', 'Command Palette' }, { 'F3', 'Launcher' },
      { 'F4', 'Launcher (Tabs)' }, { 'F5', 'Launcher (Workspaces)' }, { 'F11', 'Toggle FullScreen' },
      { 'F12', 'Debug Overlay' }, { 'SUPER+F1', '快捷鍵速查' },
   } },
   { '常用操作', {
      { 'SUPER+f', '搜尋文字' }, { 'SUPER_REV+u', '開啟 URL' },
      { 'Ctrl+Shift+c', '複製' }, { 'Ctrl+Shift+v', '貼上' },
      { 'SUPER+←', '游標移至行首' }, { 'SUPER+→', '游標移至行尾' }, { 'SUPER+BS', '清除整行' },
   } },
   { 'Tab', {
      { 'SUPER+t', '新 Tab (預設)' }, { 'SUPER_REV+t', '新 Tab (WSL)' }, { 'SUPER_REV+w', '關閉 Tab' },
      { 'SUPER+[', '上一個 Tab' }, { 'SUPER+]', '下一個 Tab' },
      { 'SUPER_REV+[', 'Tab 左移' }, { 'SUPER_REV+]', 'Tab 右移' },
      { 'SUPER+0', '重新命名 Tab' }, { 'SUPER_REV+0', '取消命名' }, { 'SUPER+9', '顯示/隱藏 Tab Bar' },
   } },
   { 'Pane', {
      { 'SUPER+\\', '垂直分割' }, { 'SUPER_REV+\\', '水平分割' },
      { 'SUPER+Enter', 'Zoom Pane' }, { 'SUPER+w', '關閉 Pane' },
      { 'SUPER_REV+h', '切換左側 Pane' }, { 'SUPER_REV+l', '切換右側 Pane' },
      { 'SUPER_REV+k', '切換上方 Pane' }, { 'SUPER_REV+j', '切換下方 Pane' },
      { 'SUPER_REV+p', 'Swap Pane' },
      { 'SUPER+u', '捲動 5 行上' }, { 'SUPER+d', '捲動 5 行下' },
      { 'PageUp', '捲動 0.75 頁上' }, { 'PageDown', '捲動 0.75 頁下' },
   } },
   { '視窗', {
      { 'SUPER+n', '開新視窗' }, { 'SUPER_REV+Enter', '最大化視窗' },
      { 'SUPER+=', '視窗放大 50px' }, { 'SUPER+-', '視窗縮小 50px' },
   } },
   { '背景圖片', {
      { 'SUPER+/', '隨機背景' }, { 'SUPER_REV+/', 'Fuzzy 選背景' },
      { 'SUPER+,', '上一張' }, { 'SUPER+.', '下一張' }, { 'SUPER+b', 'BG Focus 淡化' },
   } },
   { 'Scratchpad', { { 'SUPER_REV+`', 'Toggle Scratchpad' } } },
   { 'Session', { { 'SUPER_REV+s', '儲存 Session' } } },
   { 'Key Table', {
      { 'LEADER+f', 'resize_font 模式' }, { 'LEADER+p', 'resize_pane 模式' }, { 'LEADER+w', 'workspace 模式' },
      { 'resize_font k', '字型放大' }, { 'resize_font j', '字型縮小' }, { 'resize_font r', '字型重置' },
      { 'resize_pane k', 'Pane 向上擴大' }, { 'resize_pane j', 'Pane 向下擴大' },
      { 'resize_pane h', 'Pane 向左擴大' }, { 'resize_pane l', 'Pane 向右擴大' },
      { 'workspace n', '新建 workspace' }, { 'workspace r', '重新命名 workspace' },
   } },
}

local KEY_NAMES = { LeftArrow = '←', RightArrow = '→', UpArrow = '↑', DownArrow = '↓', Backspace = 'BS' }

local COLORS = { section = '#cba6f7', key = '#f9e2af', desc = '#cdd6f4', sep = '#45475a' }
local COLUMNS = 2
local SECTION_W = 12
local KEY_W = 17
local DESC_W = 24
local GAP = '  │  '

---Display width aware of CJK double-width characters
---@param s string
---@return integer
local function width(s)
   local ok, w = pcall(wezterm.column_width, s)
   return ok and w or utf8.len(s) or #s
end

---Truncate to `w` columns, then pad to exactly `w`
---@param s string
---@param w integer
---@return string
local function fit(s, w)
   if width(s) > w then
      s = wezterm.truncate_right(s, w - 1) .. '…'
   end
   return s .. string.rep(' ', math.max(0, w - width(s)))
end

---Normalize a binding to the same notation used by the PS profile cheat sheet
---@param binding table
---@return string
local function combo(binding)
   local mods = binding.mods or 'NONE'
   local key = KEY_NAMES[binding.key] or binding.key
   if mods == 'NONE' then
      return key
   elseif mods == SUPER then
      return 'SUPER+' .. key
   elseif mods == SUPER_REV then
      return 'SUPER_REV+' .. key
   end
   local parts = {}
   for m in mods:gmatch('[^|]+') do
      table.insert(parts, m == 'LEADER' and 'LEADER' or (m:sub(1, 1) .. m:sub(2):lower()))
   end
   return table.concat(parts, '+') .. '+' .. key
end

---@param action any
---@return string
local function action_name(action)
   local s = type(action) == 'string' and action or wezterm.to_string(action)
   return (s:gsub('%s+', ' '))
end

---One row: the section name, then up to COLUMNS { key, desc } cells
---@param section string
---@param cells { [1]: string, [2]: string }[]
---@return string
local function label(section, cells)
   local items = {
      { Foreground = { Color = COLORS.section } },
      { Text = fit(section, SECTION_W) },
   }
   for i, cell in ipairs(cells) do
      if i > 1 then
         table.insert(items, { Foreground = { Color = COLORS.sep } })
         table.insert(items, { Text = GAP })
      end
      table.insert(items, { Foreground = { Color = COLORS.key } })
      table.insert(items, { Text = fit(cell[1], KEY_W) })
      table.insert(items, { Foreground = { Color = COLORS.desc } })
      -- no trailing padding after the last cell
      table.insert(items, { Text = i < #cells and fit(cell[2], DESC_W) or cell[2] })
   end
   return wezterm.format(items)
end

---Build selector rows, grouped by section, COLUMNS bindings per row
---@return table choices
local function build()
   local bindings = require('config.bindings')
   local by_combo, seen = {}, {}

   for _, b in ipairs(bindings.keys or {}) do
      by_combo[combo(b)] = b
   end
   for name, entries in pairs(bindings.key_tables or {}) do
      for _, b in ipairs(entries) do
         by_combo[name .. ' ' .. (KEY_NAMES[b.key] or b.key)] = b
      end
   end

   ---@type { [1]: string, [2]: { [1]: string, [2]: string }[] }[]
   local groups = {}
   local function add(group, key, desc)
      local b = by_combo[key]
      if not b then
         wezterm.log_warn('[keymap-help] no binding for described key: ' .. key)
         return
      end
      seen[key] = true
      table.insert(group[2], { key, desc or action_name(b.action) })
   end

   for _, section in ipairs(SECTIONS) do
      local group = { section[1], {} }
      for _, entry in ipairs(section[2]) do
         add(group, entry[1], entry[2])
      end
      table.insert(groups, group)
   end

   -- Bindings without a description (e.g. newly added ones) still show up
   local rest = {}
   for key in pairs(by_combo) do
      if not seen[key] and not key:find(' Escape$') and not key:find(' q$') then
         table.insert(rest, key)
      end
   end
   table.sort(rest)
   local other = { '其他', {} }
   for _, key in ipairs(rest) do
      add(other, key, nil)
   end
   table.insert(groups, other)
   table.insert(groups, { '滑鼠', { { 'Ctrl+左鍵', '開啟游標下連結' } } })

   local choices = {}
   for _, group in ipairs(groups) do
      local cells = group[2]
      for i = 1, #cells, COLUMNS do
         table.insert(choices, { id = tostring(#choices + 1), label = label(group[1], { table.unpack(cells, i, math.min(i + COLUMNS - 1, #cells)) }) })
      end
   end
   return choices
end

---KeyAssignment that opens the cheat sheet
M.show = wezterm.action_callback(function(window, pane)
   window:perform_action(
      act.InputSelector({
         title = 'Keybindings  (SUPER = ' .. SUPER .. ', SUPER_REV = ' .. SUPER_REV:gsub('|', '+') .. ')',
         choices = build(),
         fuzzy = true,
         fuzzy_description = '搜尋快捷鍵: ',
         action = wezterm.action_callback(function() end),
      }),
      pane
   )
end)


return M
