local platform = require('utils.platform')
-- Note: wezterm.glob cannot be used here (coroutine issue during require())

---Check if a file exists at the given path
---Uses io.open instead of wezterm.glob to avoid coroutine issues during require()
---@param path string
---@return boolean
local function file_exists(path)
   local f = io.open(path, 'r')
   if f then
      f:close()
      return true
   end
   return false
end

---Find Git Bash executable path (Windows only)
---Searches common installation locations in order
---@return string|nil
local function find_git_bash()
   local candidates = {}

   -- Scoop user-level
   local userprofile = os.getenv('USERPROFILE')
   if userprofile then
      table.insert(candidates, userprofile .. '\\scoop\\apps\\git\\current\\bin\\bash.exe')
   end

   -- Scoop custom SCOOP env
   local scoop = os.getenv('SCOOP')
   if scoop then
      table.insert(candidates, scoop .. '\\apps\\git\\current\\bin\\bash.exe')
   end

   -- Official installer default paths
   table.insert(candidates, 'C:\\Program Files\\Git\\bin\\bash.exe')

   local pf = os.getenv('ProgramFiles')
   if pf and pf ~= 'C:\\Program Files' then
      table.insert(candidates, pf .. '\\Git\\bin\\bash.exe')
   end

   local pf86 = os.getenv('ProgramFiles(x86)')
   if pf86 then
      table.insert(candidates, pf86 .. '\\Git\\bin\\bash.exe')
   end

   for _, path in ipairs(candidates) do
      if file_exists(path) then
         return path
      end
   end
   return nil
end

local options = {
   default_prog = {},
   launch_menu = {},
}

if platform.is_win then
   options.default_prog = { 'pwsh', '-NoLogo' }
   options.launch_menu = {
      { label = 'PowerShell Core',    args = { 'pwsh', '-NoLogo' } },
      { label = 'PowerShell Desktop', args = { 'powershell' } },
      { label = 'Command Prompt',     args = { 'cmd' } },
      { label = 'Nushell',            args = { 'nu' } },
      { label = 'Msys2',              args = { 'ucrt64.cmd' } },
   }

   local git_bash = find_git_bash()
   if git_bash then
      table.insert(options.launch_menu, { label = 'Git Bash', args = { git_bash } })
   end
elseif platform.is_mac then
   options.default_prog = { '/opt/homebrew/bin/fish', '-l' }
   options.launch_menu = {
      { label = 'Bash',    args = { 'bash', '-l' } },
      { label = 'Fish',    args = { '/opt/homebrew/bin/fish', '-l' } },
      { label = 'Nushell', args = { '/opt/homebrew/bin/nu', '-l' } },
      { label = 'Zsh',     args = { 'zsh', '-l' } },
   }
elseif platform.is_linux then
   options.default_prog = { 'fish', '-l' }
   options.launch_menu = {
      { label = 'Bash', args = { 'bash', '-l' } },
      { label = 'Fish', args = { 'fish', '-l' } },
      { label = 'Zsh',  args = { 'zsh', '-l' } },
   }
end

return options
