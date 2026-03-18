local Config = require('config')
local timing = require('utils.timing')

-- Set to true to enable startup timing logs (visible in F12 Debug Overlay)
timing.ENABLED = false

local _T = timing.now()

local _t = timing.now(); require('utils.health-check').run(); timing.log('health-check.run()', _t)

local _t = timing.now()
require('utils.backdrops')
   -- :set_focus('#000000')
   -- :set_images_dir(require('wezterm').home_dir .. '/Pictures/Wallpapers/')
   :set_images()
   :set_default_random()
timing.log('backdrops set_images+set_default_random', _t)

local _t = timing.now(); require('events.left-status').setup();  timing.log('left-status.setup()', _t)
local _t = timing.now(); require('events.right-status').setup({ date_format = '%a %H:%M:%S' }); timing.log('right-status.setup()', _t)
local _t = timing.now(); require('events.tab-title').setup({ hide_active_tab_unseen = false, unseen_icon = 'numbered_box' }); timing.log('tab-title.setup()', _t)
local _t = timing.now(); require('events.new-tab-button').setup(); timing.log('new-tab-button.setup()', _t)
local _t = timing.now(); require('events.gui-startup').setup(); timing.log('gui-startup.setup()', _t)

local _t = timing.now(); require('utils.scratchpad').setup();     timing.log('scratchpad.setup()', _t)
local _t = timing.now(); require('utils.session').setup();        timing.log('session.setup()', _t)
local _t = timing.now(); require('utils.theme-switcher').setup(); timing.log('theme-switcher.setup()', _t)

-- Cleanup window-overrides state when a window is closed
local wezterm_api = require('wezterm')
local WinOverrides = require('utils.window-overrides')
wezterm_api.on('window-closed', function(window)
   WinOverrides.remove(window:window_id())
end)

local _t = timing.now()
local cfg = Config:init()
timing.log('Config:init()', _t)
local _t = timing.now(); cfg:append(require('config.appearance')); timing.log('  append(appearance)', _t)
local _t = timing.now(); cfg:append(require('config.bindings'));   timing.log('  append(bindings)', _t)
local _t = timing.now(); cfg:append(require('config.domains'));    timing.log('  append(domains)', _t)
local _t = timing.now(); cfg:append(require('config.fonts'));      timing.log('  append(fonts)', _t)
local _t = timing.now(); cfg:append(require('config.general'));    timing.log('  append(general)', _t)
local _t = timing.now(); cfg:append(require('config.launch'));     timing.log('  append(launch)', _t)

timing.log('=== wezterm.lua total main chunk ===', _T)

return cfg.options
