local platform = require('utils.platform')

-- NOTE: Assumes WSL username matches the Windows USERNAME. If they differ,
-- override username and default_cwd manually in each wsl_domains entry.
local username = os.getenv('USERNAME') or os.getenv('USER') or 'user'

local options = {
   ssh_domains = {},
   unix_domains = {},
   wsl_domains = {},
}

if platform.is_win then
   options.ssh_domains = {
      {
         name = 'ssh:wsl',
         remote_address = 'localhost',
         multiplexing = 'None',
         default_prog = { 'fish', '-l' },
         assume_shell = 'Posix',
      },
   }

   options.wsl_domains = {
      {
         name = 'wsl:ubuntu-fish',
         distribution = 'Ubuntu',
         username = username,
         default_cwd = '/home/' .. username,
         default_prog = { 'fish', '-l' },
      },
      {
         name = 'wsl:ubuntu-bash',
         distribution = 'Ubuntu',
         username = username,
         default_cwd = '/home/' .. username,
         default_prog = { 'bash', '-l' },
      },
   }
end

return options
