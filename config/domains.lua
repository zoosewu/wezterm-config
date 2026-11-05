local platform = require('utils.platform')

-- NOTE: Assumes WSL username matches the Windows USERNAME. If they differ,
-- override username and default_cwd manually in each wsl_domains entry.
local username = os.getenv('USERNAME') or os.getenv('USER') or 'user'

-- Persistent sessions: the GUI connects to a background mux server (unix domain), so
-- closing the window keeps every pane running; the next launch re-attaches to them.
-- The server is spawned automatically on first launch. Set to false for plain mode.
-- Note: WSL / SSH tabs opened from the GUI belong to the GUI and close with it.
local PERSISTENT_SESSIONS = true

local options = {
   ssh_domains = {},
   unix_domains = {},
   wsl_domains = {},
}

if PERSISTENT_SESSIONS then
   options.unix_domains = { { name = 'unix' } }
   -- behave like `wezterm connect unix` when launched without a subcommand
   options.default_gui_startup_args = { 'connect', 'unix' }
end

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
