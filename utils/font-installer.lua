-- utils/font-installer.lua
-- Makes sure configured fonts exist. A missing font is downloaded in the background
-- (after the first window is shown) into `<config_dir>/fonts`, which is loaded via
-- `font_dirs`, then the config is reloaded. Until then a font bundled with WezTerm
-- is used, so a missing font never triggers WezTerm's font error.
local wezterm = require('wezterm')
local platform = require('utils.platform')

---@class FontSpec
---@field family string    font family name used in `wezterm.font()`
---@field fallback string  bundled family used while `family` is unavailable
---@field base_url string  download URL prefix, `files` are appended to it
---@field files string[]   font files; the first one is used to detect installation

local M = {}

M.FONT_DIR = wezterm.config_dir .. '/fonts'

---@type FontSpec[]
local pending = {}

---@return string[]
local function search_dirs()
   local home = wezterm.home_dir
   if platform.is_win then
      local local_appdata = os.getenv('LOCALAPPDATA') or (home .. '/AppData/Local')
      return {
         (os.getenv('WINDIR') or 'C:/Windows') .. '/Fonts',
         local_appdata .. '/Microsoft/Windows/Fonts',
      }
   elseif platform.is_mac then
      return { home .. '/Library/Fonts', '/Library/Fonts' }
   end
   return {
      home .. '/.local/share/fonts',
      home .. '/.local/share/fonts/NerdFonts',
      home .. '/.fonts',
      '/usr/share/fonts/TTF',
      '/usr/share/fonts/truetype',
      '/usr/local/share/fonts',
   }
end

---Uses io.open instead of wezterm.glob, which fails inside require() (coroutine issue)
---@param spec FontSpec
---@return boolean
local function is_installed(spec)
   local dirs = search_dirs()
   table.insert(dirs, 1, M.FONT_DIR)
   for _, dir in ipairs(dirs) do
      local f = io.open(dir .. '/' .. spec.files[1], 'rb')
      if f then
         f:close()
         return true
      end
   end
   return false
end

---Download all files of `spec` into FONT_DIR. Must run inside an event callback
---so `run_child_process` does not block the GUI.
---@param spec FontSpec
---@return boolean
local function download(spec)
   local args = { 'curl', '-fsSL', '--retry', '2', '--connect-timeout', '10', '--create-dirs' }
   for _, file in ipairs(spec.files) do
      table.insert(args, '-o')
      table.insert(args, M.FONT_DIR .. '/' .. file .. '.part')
      table.insert(args, spec.base_url .. file)
   end

   local ok, success, _, stderr = pcall(wezterm.run_child_process, args)
   for _, file in ipairs(spec.files) do
      local dest = M.FONT_DIR .. '/' .. file
      if ok and success then
         os.remove(dest)
         os.rename(dest .. '.part', dest)
      else
         os.remove(dest .. '.part')
      end
   end

   if ok and success then
      wezterm.log_info('[font-installer] installed "' .. spec.family .. '" to ' .. M.FONT_DIR)
      return true
   end
   wezterm.log_warn('[font-installer] failed to download "' .. spec.family .. '": ' .. tostring(ok and stderr or success))
   return false
end

---Return `spec.family` if it is installed, otherwise queue it for download
---and return `spec.fallback`.
---@param spec FontSpec
---@return string
function M.ensure(spec)
   if is_installed(spec) then
      return spec.family
   end
   wezterm.log_warn('[font-installer] "' .. spec.family .. '" not found — using "' .. spec.fallback .. '" until downloaded')
   table.insert(pending, spec)
   return spec.fallback
end

---Register the background download of missing fonts after GUI startup.
function M.setup()
   wezterm.on('gui-startup', function()
      if #pending == 0 then
         return
      end
      wezterm.time.call_after(0, function()
         local installed = false
         for _, spec in ipairs(pending) do
            installed = download(spec) or installed
         end
         pending = {}
         if installed then
            wezterm.reload_configuration()
         end
      end)
   end)
end

return M
