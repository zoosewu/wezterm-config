local wezterm = require('wezterm')
local colors = require('colors.custom')
local WinOverrides = require('utils.window-overrides')

-- Seed random number generator
-- Known issue with lua math library: first few values are not random enough
-- see: https://stackoverflow.com/questions/20154991/generating-uniform-random-numbers-in-lua
math.randomseed(os.time())
math.random(); math.random(); math.random()

local GLOB_PATTERN = '*.{jpg,jpeg,png,gif,bmp,ico,tiff,pnm,dds,tga}'

---@class BackDrops
---@field images string[] list of backdrop image paths
---@field images_dir string directory containing backdrop images
---@field focus_color string background color for focus mode
---@field _default_idx number initial image index (used before any window exists)
---@field _window_states table<number, {current_idx: number, focus_on: boolean}>
local BackDrops = {}
BackDrops.__index = BackDrops

---Initialise backdrop controller
---@private
function BackDrops:init()
   local o = {
      images = {},
      images_dir = wezterm.config_dir .. '/backdrops/',
      focus_color = colors.background,
      _default_idx = 1,
      _window_states = {},
   }
   return setmetatable(o, self)
end

---Override the default images directory
---Default is `wezterm.config_dir .. '/backdrops/'`
---Must be called before `set_images()`
---@param path string directory path
function BackDrops:set_images_dir(path)
   self.images_dir = path
   if not path:match('/$') then
      self.images_dir = path .. '/'
   end
   return self
end

---Scan the images directory and populate the images list
---Must be called before any other BackDrops function
---Can only be called from wezterm.lua due to coroutine constraints
function BackDrops:set_images()
   self.images = wezterm.glob(self.images_dir .. GLOB_PATTERN)
   return self
end

---Override the default focus mode background color
---@param focus_color string background color in any WezTerm-supported format
function BackDrops:set_focus(focus_color)
   self.focus_color = focus_color
   return self
end

---Set a random default image index (used at startup before any window exists)
function BackDrops:set_default_random()
   if #self.images > 0 then
      self._default_idx = math.random(#self.images)
   end
   return self
end

---Get or create per-window state
---@private
---@param window any WezTerm Window
---@return {current_idx: number, focus_on: boolean}
function BackDrops:_state(window)
   local id = window:window_id()
   if not self._window_states[id] then
      self._window_states[id] = {
         current_idx = self._default_idx,
         focus_on = false,
      }
   end
   return self._window_states[id]
end

---Build background options with the given image
---@private
---@param idx number index into self.images
---@return table
function BackDrops:_img_opts(idx)
   return {
      {
         source = { File = self.images[idx] },
         horizontal_align = 'Center',
      },
      {
         source = { Color = colors.background },
         height = '120%',
         width = '120%',
         vertical_offset = '-10%',
         horizontal_offset = '-10%',
         opacity = 0.96,
      },
   }
end

---Build background options for focus mode (solid color, no image)
---@private
---@return table
function BackDrops:_focus_opts()
   return {
      {
         source = { Color = self.focus_color },
         height = '120%',
         width = '120%',
         vertical_offset = '-10%',
         horizontal_offset = '-10%',
         opacity = 1,
      },
   }
end

---Return the initial background options for use in appearance.lua
---Called during config generation before any window exists.
---Falls back to a solid color when images have not been loaded yet
---(e.g. when set_images() is deferred to gui-startup for faster cold-start).
---@param focus_on boolean? start in focus mode (default false)
---@return table
function BackDrops:initial_options(focus_on)
   focus_on = focus_on or false
   assert(type(focus_on) == 'boolean', 'BackDrops:initial_options - expected a boolean')
   if focus_on or #self.images == 0 then
      return self:_focus_opts()
   end
   return self:_img_opts(self._default_idx)
end

---Select a random background for the given window
---@param window any WezTerm Window
function BackDrops:random(window)
   local state = self:_state(window)
   state.current_idx = math.random(math.max(1, #self.images))
   WinOverrides.set(window, 'background', self:_img_opts(state.current_idx))
end

---Cycle to the next background image
---@param window any WezTerm Window
function BackDrops:cycle_forward(window)
   local state = self:_state(window)
   state.current_idx = (state.current_idx % #self.images) + 1
   WinOverrides.set(window, 'background', self:_img_opts(state.current_idx))
end

---Cycle to the previous background image
---@param window any WezTerm Window
function BackDrops:cycle_back(window)
   local state = self:_state(window)
   if state.current_idx == 1 then
      state.current_idx = #self.images
   else
      state.current_idx = state.current_idx - 1
   end
   WinOverrides.set(window, 'background', self:_img_opts(state.current_idx))
end

---Set a specific background image by index
---@param window any WezTerm Window
---@param idx number 1-based index into the images list
function BackDrops:set_img(window, idx)
   if idx < 1 or idx > #self.images then
      wezterm.log_error('BackDrops:set_img - index out of range: ' .. tostring(idx))
      return
   end
   local state = self:_state(window)
   state.current_idx = idx
   WinOverrides.set(window, 'background', self:_img_opts(idx))
end

---Toggle focus mode (show/hide background image)
---@param window any WezTerm Window
function BackDrops:toggle_focus(window)
   local state = self:_state(window)
   state.focus_on = not state.focus_on
   local opts = state.focus_on and self:_focus_opts() or self:_img_opts(state.current_idx)
   WinOverrides.set(window, 'background', opts)
end

---Generate InputSelector choices for all loaded images
---@return table choices for wezterm.action.InputSelector
function BackDrops:choices()
   local choices = {}
   for idx, file in ipairs(self.images) do
      table.insert(choices, {
         id = tostring(idx),
         label = file:match('([^/\\]+)$') or file,
      })
   end
   return choices
end

return BackDrops:init()
