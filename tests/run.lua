-- tests/run.lua
-- Headless tests through each module's interface. Run from the repo root:
--
--   wezterm --config-file tests/run.lua ls-fonts --text a 2>&1 | grep "\[test\]"
--
-- `ls-fonts` evaluates this file as a config without opening a window. Every check
-- logs a PASS/FAIL line; any failure raises an error, so WezTerm also reports a
-- configuration error.
local wezterm = require('wezterm')

-- Repo root from this file's path (works for relative and absolute --config-file)
local ROOT = wezterm.config_file:gsub('run%.lua$', ''):gsub('[/\\]$', ''):gsub('tests$', '')
ROOT = (ROOT == '' and '.' or ROOT:gsub('[/\\]$', '')) .. '/'
package.path = ROOT .. '?.lua;' .. ROOT .. '?/init.lua;' .. package.path

-- Never silently test another copy (WezTerm also searches ~/.config/wezterm)
local resolved = package.searchpath('utils.cwd', package.path) or ''
if resolved:sub(1, #ROOT) ~= ROOT then
   error('[test] modules resolve outside the repo: ' .. resolved .. ' (ROOT=' .. ROOT .. ')')
end

local failures, total = 0, 0

---@param name string
---@param got any
---@param want any
local function eq(name, got, want)
   total = total + 1
   if got == want then
      wezterm.log_info('[test] PASS ' .. name)
   else
      failures = failures + 1
      wezterm.log_error(string.format('[test] FAIL %s: got %s, want %s', name, tostring(got), tostring(want)))
   end
end

---Concatenate the Text items of a FormatItem list
local function text_of(items)
   local out = {}
   for _, item in ipairs(items) do
      if type(item) == 'table' and item.Text then
         out[#out + 1] = item.Text
      end
   end
   return table.concat(out)
end

-- ---------------------------------------------------------------- utils.cwd
do
   local cwd = require('utils.cwd')
   local home = wezterm.home_dir:gsub('\\', '/')

   eq('cwd.shorten home', cwd.shorten(home), '~')
   eq('cwd.shorten home/', cwd.shorten(home .. '/'), '~')
   eq('cwd.shorten under home', cwd.shorten(home .. '/a/b/c'), '~/b/c')
   eq('cwd.shorten home case-insensitive', cwd.shorten(home:lower() .. '/a/b'),
      require('utils.platform').is_win and '~/a/b' or 'a/b')
   eq('cwd.shorten home-like prefix', cwd.shorten(home .. 'X/foo'), home:match('[^/]+$') .. 'X/foo')
   eq('cwd.shorten absolute', cwd.shorten('E:/Code/Projects/local/wezterm-config'), 'local/wezterm-config')
   eq('cwd.shorten backslashes', cwd.shorten('C:\\Windows\\System32'), 'Windows/System32')
   eq('cwd.shorten nil', cwd.shorten(nil), '')

   local function pane(file_path)
      return { get_current_working_dir = function() return file_path and { file_path = file_path } or nil end }
   end
   local win, posix, none = pane('/C:/Users/me/proj'), pane('/home/me/proj'), pane(nil)
   local wsl = { DomainName = 'wsl:ubuntu-fish' }
   if require('utils.platform').is_win then
      eq('cwd.for_domain win -> default', cwd.for_domain(win, 'DefaultDomain'), 'C:/Users/me/proj')
      eq('cwd.for_domain win -> wsl', cwd.for_domain(win, wsl), '/mnt/c/Users/me/proj')
      eq('cwd.for_domain posix -> default', cwd.for_domain(posix, 'DefaultDomain'), nil)
   end
   eq('cwd.for_domain posix -> current', cwd.for_domain(posix, 'CurrentPaneDomain'), '/home/me/proj')
   eq('cwd.for_domain posix -> wsl', cwd.for_domain(posix, wsl), '/home/me/proj')
   eq('cwd.for_domain -> ssh', cwd.for_domain(win, { DomainName = 'ssh:wsl' }), nil)
   eq('cwd.for_domain no cwd', cwd.for_domain(none, wsl), nil)
   eq('cwd.is_wsl_domain', cwd.is_wsl_domain('WSL:Ubuntu'), true)
   eq('cwd.is_wsl_domain nil', cwd.is_wsl_domain(nil), false)
end

-- ------------------------------------------------------- utils.process-name
do
   local process_name = require('utils.process-name')
   eq('process-name.clean windows', process_name.clean('C:\\Program Files\\PowerShell\\7\\pwsh.exe'), 'pwsh')
   eq('process-name.clean posix', process_name.clean('/usr/bin/fish'), 'fish')
   eq('process-name.clean nil', process_name.clean(nil), '')
end

-- ------------------------------------------------------------ utils.segment
do
   local items = require('utils.segment').append({}, 'x', { fg = '#fff' }, true)
   eq('segment.append resets first', items[1], 'ResetAttributes')
   eq('segment.append text last', items[#items].Text, 'x')
end

-- -------------------------------------------------------- events.tab-title
do
   local handler
   local real_on = wezterm.on
   wezterm.on = function(name, fn)
      if name == 'format-tab-title' then handler = fn end
   end
   require('events.tab-title').setup({ hide_active_tab_unseen = false, unseen_icon = 'numbered_box' })
   wezterm.on = real_on

   local function tab(title, opts)
      opts = opts or {}
      return {
         tab_id = 1, is_active = opts.active or false, tab_title = opts.tab_title or '',
         active_pane = { pane_id = 1, title = title, foreground_process_name = 'C:/x/pwsh.exe',
            domain_name = opts.domain or 'local' },
         panes = { { has_unseen_output = opts.unseen or false } },
      }
   end
   local function render(t) return text_of(handler(t, {}, {}, {}, false, 25)) end
   local admin_glyph = wezterm.nerdfonts.md_shield_half_full
   local wsl_glyph = wezterm.nerdfonts.cod_terminal_linux

   eq('tab-title plain tab has no admin icon', render(tab('htop')):find(admin_glyph, 1, true), nil)
   eq('tab-title admin tab has admin icon', render(tab('Administrator: pwsh')):find(admin_glyph, 1, true) ~= nil, true)
   eq('tab-title wsl domain icon', render(tab('fish', { domain = 'wsl:ubuntu-fish' })):find(wsl_glyph, 1, true) ~= nil, true)
   eq('tab-title manual title wins', render(tab('htop', { tab_title = 'mine' })):find('mine', 1, true) ~= nil, true)
   local w_ascii = wezterm.column_width(render(tab('htop')))
   eq('tab-title CJK same width as ascii', wezterm.column_width(render(tab('中文檔案很長很長很長很長很長'))), w_ascii)
   local t = tab('htop')
   eq('tab-title memoised', handler(t, {}, {}, {}, false, 25), handler(t, {}, {}, {}, false, 25))
end

-- --------------------------------------------------------- utils.state-file
do
   local state_file = require('utils.state-file')
   state_file.DIR = (os.getenv('TEMP') or os.getenv('TMPDIR') or '/tmp') .. '/wezterm-config-test'
   os.remove(state_file.path('t.json'))
   local data = { { cwd = 'C:/x', title = '中文' } }
   local changed, err = state_file.write('t.json', data)
   eq('state-file.write creates dir + file', changed and err == nil, true)
   changed = state_file.write('t.json', data)
   eq('state-file.write skips unchanged', changed, false)
   local back = state_file.read('t.json')
   eq('state-file.read roundtrip', back and back[1].title, '中文')
   eq('state-file.read missing', state_file.read('missing.json'), nil)
   os.remove(state_file.path('t.json'))
end

-- ------------------------------------------- state never lives in the repo
do
   local function outside_repo(path)
      local norm = function(p) return p:gsub('\\', '/'):lower() end
      local root = norm(ROOT == './' and wezterm.config_dir:gsub('[/\\]tests$', '') or ROOT)
      return norm(path):sub(1, #root) ~= root
   end
   eq('state-file.DIR outside repo', outside_repo(require('utils.state-file').DIR), true)
   eq('font-installer.FONT_DIR outside repo', outside_repo(require('utils.font-installer').FONT_DIR), true)
end

-- ---------------------------------------------------------- utils.platform
do
   local platform = require('utils.platform')
   eq('platform.mods.SUPER_REV extends SUPER', platform.mods.SUPER_REV, platform.mods.SUPER .. '|CTRL')
end

-- ------------------------------------------------- whole config must load
do
   local ok, err = pcall(dofile, ROOT .. 'wezterm.lua')
   eq('wezterm.lua evaluates' .. (ok and '' or (': ' .. tostring(err))), ok, true)
end

local summary = string.format('[test] %d/%d passed', total - failures, total)
if failures > 0 then
   error(summary)
end
wezterm.log_info(summary)
return {}
