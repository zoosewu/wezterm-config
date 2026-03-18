-- utils/health-check.lua
-- Startup self-diagnostics. Results are visible in the WezTerm Debug Overlay (F12).
-- Runs deferred (after gui-startup) to avoid blocking WezTerm's startup.
local wezterm = require('wezterm')
local platform = require('utils.platform')
local timing = require('utils.timing')

local M = {}

---Check if an absolute path exists using io.open.
---Relative commands (e.g. 'pwsh', 'fish') are not checked — they rely on PATH
---and verifying them requires os.execute which blocks startup.
---@param prog string
---@return boolean
local function check_prog(prog)
   if prog:match('^/') or prog:match('^%a:\\') or prog:match('^%a:/') then
      local f = io.open(prog, 'r')
      if f then
         f:close()
         return true
      end
      return false
   end
   return true
end

---Run all startup health checks and log the results.
---Open F12 Debug Overlay to view them.
---@private
local function _run()
   local _T = timing.now()
   local launch = require('config.launch')
   local issues = {}
   local ok_count = 0

   -- Check default shell
   local _t = timing.now()
   if launch.default_prog and #launch.default_prog > 0 then
      local prog = launch.default_prog[1]
      if check_prog(prog) then
         ok_count = ok_count + 1
         wezterm.log_info('[health] ✓ default_prog: ' .. prog)
      else
         table.insert(issues, 'default_prog not found: ' .. prog)
         wezterm.log_warn('[health] ✗ default_prog not found: ' .. prog)
      end
   end
   timing.log('default_prog check', _t, 'timing/health')

   -- Check launch_menu entries (absolute paths only)
   local _t = timing.now()
   for _, entry in ipairs(launch.launch_menu or {}) do
      if entry.args and #entry.args > 0 then
         local prog = entry.args[1]
         local is_absolute = prog:match('^/') or prog:match('^%a:[/\\]')
         if is_absolute and not check_prog(prog) then
            wezterm.log_warn('[health] ⚠ launch_menu "' .. entry.label .. '" not found: ' .. prog)
         else
            ok_count = ok_count + 1
         end
      end
   end
   timing.log('launch_menu check', _t, 'timing/health')

   -- Check backdrops directory
   local _t = timing.now()
   local backdrops_dir = wezterm.config_dir .. '/backdrops/'
   local backdrop_files = wezterm.glob(backdrops_dir .. '*.{jpg,jpeg,png,gif,bmp,ico,tiff,pnm,dds,tga}')
   if #backdrop_files > 0 then
      ok_count = ok_count + 1
      wezterm.log_info('[health] ✓ backdrops: ' .. #backdrop_files .. ' image(s) found')
   else
      wezterm.log_warn('[health] ⚠ backdrops: no images found in ' .. backdrops_dir)
   end
   timing.log('backdrops glob', _t, 'timing/health')

   -- Check Nerd Font icons (basic availability test)
   local _t = timing.now()
   if wezterm.nerdfonts and wezterm.nerdfonts.oct_terminal then
      ok_count = ok_count + 1
      wezterm.log_info('[health] ✓ Nerd Font icons available')
   else
      table.insert(issues, 'Nerd Font icons unavailable — check font installation')
      wezterm.log_warn('[health] ✗ Nerd Font icons unavailable')
   end
   timing.log('nerdfonts check', _t, 'timing/health')

   -- Check WSL domains (Windows only)
   local _t = timing.now()
   if platform.is_win then
      local domains = require('config.domains')
      if domains.wsl_domains and #domains.wsl_domains > 0 then
         ok_count = ok_count + 1
         wezterm.log_info('[health] ✓ WSL domains configured: ' .. #domains.wsl_domains)
      end
   end
   timing.log('wsl domains check', _t, 'timing/health')

   -- Summary
   if #issues == 0 then
      wezterm.log_info('[health] All checks passed (' .. ok_count .. ' ok) — press F12 for details')
   else
      wezterm.log_warn('[health] ' .. #issues .. ' issue(s) found — press F12 (Debug Overlay) for details')
      for _, issue in ipairs(issues) do
         wezterm.log_error('[health] ISSUE: ' .. issue)
      end
   end
   timing.log('=== health-check _run() total ===', _T, 'timing/health')
end

---Register health check to run after gui-startup (non-blocking).
function M.run()
   wezterm.on('gui-startup', function()
      _run()
   end)
end

return M
