-- utils/updater.lua
-- Keeps a git-cloned config up to date. After the first window is shown (at most once
-- per `interval_hours`, across WezTerm processes) it fetches the update source and
-- fast-forwards when that is safe. The merge rewrites files in the watched config
-- dir, so WezTerm reloads the new config by itself.
--
-- Update source (see `setup` options):
--   repo = nil         the current branch's upstream (`git clone` default)
--   repo = url|remote  any repo, e.g. your own fork; `branch` defaults to its HEAD
--
-- Never touches local work: a dirty working tree (mode-only changes are ignored) or
-- local commits are reported via toast + log and left alone. A config dir that is not
-- a git repo, or a branch without upstream (and no `repo`), is skipped silently.
-- Command palette (F2) "Config: 檢查更新" checks immediately, ignoring the interval.
local wezterm = require('wezterm')
local startup = require('utils.startup')
local state_file = require('utils.state-file')

local M = {}

local STATE_FILE = 'updater.json'

---@class UpdaterOptions
---@field repo? string    URL, local path or remote name to update from (default: upstream)
---@field branch? string  branch of `repo` (default: its HEAD); ignored without `repo`
---@field dir? string     repo to update (default: wezterm.config_dir)
---@field interval_hours? number  minimum hours between automatic checks (default: 6)
---@field enabled? boolean  false disables the automatic check (palette still works)

---@type UpdaterOptions
local settings = { interval_hours = 6, enabled = true }

---@param dir string
---@param args string[]
---@return boolean ok, string stdout, string stderr
local function git(dir, args)
   -- mode-only diffs (files touched from WSL) are not real local changes
   local cmd = { 'git', '-C', dir, '-c', 'core.fileMode=false' }
   for _, a in ipairs(args) do
      table.insert(cmd, a)
   end
   local ok, success, stdout, stderr = pcall(wezterm.run_child_process, cmd)
   if not ok then
      return false, '', tostring(success)
   end
   return success, stdout or '', stderr or ''
end

---@param s string
---@return string
local function trim(s)
   return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

---Fetch without ever waiting for a password, passphrase or host-key prompt
---@param dir string
---@param source string[] e.g. {} (upstream) or { url, branch }
---@return boolean ok, string err
local function fetch(dir, source)
   local args = { '-c', 'credential.interactive=never',
      '-c', 'http.lowSpeedLimit=1000', '-c', 'http.lowSpeedTime=15' }
   local has_ssh_cmd = trim(select(2, git(dir, { 'config', '--get', 'core.sshCommand' }))) ~= ''
   if not has_ssh_cmd and not os.getenv('GIT_SSH_COMMAND') then
      table.insert(args, '-c')
      table.insert(args, 'core.sshCommand=ssh -o BatchMode=yes -o ConnectTimeout=10')
   end
   for _, a in ipairs({ 'fetch', '--quiet', '--no-tags', table.unpack(source) }) do
      table.insert(args, a)
   end
   local ok, _, stderr = git(dir, args)
   return ok, trim(stderr)
end

---Log, and show a toast in the first GUI window when there is one
---@param level 'info'|'warn'
---@param msg string
local function notify(level, msg)
   if level == 'warn' then
      wezterm.log_warn('[updater] ' .. msg)
   else
      wezterm.log_info('[updater] ' .. msg)
   end
   local ok, windows = pcall(function() return wezterm.gui.gui_windows() end)
   if ok and windows[1] then
      windows[1]:toast_notification('WezTerm config', msg, nil, 8000)
   end
end

---@alias UpdateStatus 'not-repo'|'no-upstream'|'throttled'|'fetch-failed'|'up-to-date'|'diverged'|'dirty'|'updated'|'merge-failed'

---Check `dir` for new commits on the update source and fast-forward when safe.
---Runs child processes: call it from an event callback, not while building the config.
---Options default to the ones given to `setup`.
---@param opts? { dir?: string, repo?: string, branch?: string, force?: boolean }
---@return UpdateStatus status, string message
function M.check(opts)
   opts = opts or {}
   local dir = opts.dir or settings.dir or wezterm.config_dir
   local repo = opts.repo or settings.repo
   local branch = opts.branch or (not opts.repo and settings.branch) or nil

   local inside = select(2, git(dir, { 'rev-parse', '--is-inside-work-tree' }))
   if trim(inside) ~= 'true' then
      return 'not-repo', dir .. ' is not a git repository'
   end

   -- source: what to fetch; target: the ref it lands on; label: for messages
   local source, target, label
   if repo then
      source, target = { repo, branch }, 'FETCH_HEAD'
      label = repo .. (branch and (' ' .. branch) or '')
   else
      local up_ok, upstream = git(dir, { 'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}' })
      upstream = trim(upstream)
      if not up_ok or upstream == '' then
         return 'no-upstream', 'current branch has no upstream (set `repo` in updater.setup)'
      end
      source, target, label = {}, '@{u}', upstream
   end

   if not opts.force then
      local state = state_file.read(STATE_FILE)
      local last = type(state) == 'table' and tonumber(state.last_check) or 0
      if os.time() - last < (settings.interval_hours or 6) * 3600 then
         return 'throttled', 'checked recently'
      end
   end

   local fetch_ok, fetch_err = fetch(dir, source)
   if not fetch_ok then
      return 'fetch-failed', 'fetch ' .. label .. ' failed: ' .. fetch_err
   end
   state_file.write(STATE_FILE, { last_check = os.time() })

   local counts = select(2, git(dir, { 'rev-list', '--left-right', '--count', 'HEAD...' .. target }))
   local ahead, behind = counts:match('(%d+)%s+(%d+)')
   ahead, behind = tonumber(ahead) or 0, tonumber(behind) or 0
   if behind == 0 then
      return 'up-to-date', 'already up to date with ' .. label
   end
   if ahead > 0 then
      return 'diverged', string.format('%d local commit(s) not on %s; update skipped', ahead, label)
   end
   local status = select(2, git(dir, { 'status', '--porcelain', '--untracked-files=no' }))
   if trim(status) ~= '' then
      return 'dirty', string.format('%d new commit(s) on %s, but local changes exist; update skipped', behind, label)
   end

   local merge_ok, _, merge_err = git(dir, { 'merge', '--ff-only', '--quiet', target })
   if not merge_ok then
      return 'merge-failed', 'fast-forward failed: ' .. trim(merge_err)
   end
   return 'updated', string.format('updated %d commit(s) from %s, reloading', behind, label)
end

-- statuses worth interrupting the user for (others only go to the log)
local NOTIFY = { updated = 'info', diverged = 'warn', dirty = 'warn', ['merge-failed'] = 'warn' }

---@param force boolean
local function run(force)
   local status, msg = M.check({ force = force })
   local level = NOTIFY[status] or (force and status ~= 'throttled' and 'info')
   if level then
      notify(level, msg)
   else
      wezterm.log_info('[updater] ' .. status .. ': ' .. msg)
   end
end

---@param opts? UpdaterOptions
function M.setup(opts)
   for k, v in pairs(opts or {}) do
      settings[k] = v
   end

   if settings.enabled then
      startup.defer('updater', function() run(false) end)
   end

   wezterm.on('updater.check', function() run(true) end)
   wezterm.on('augment-command-palette', function()
      return {
         { brief = 'Config: 檢查更新', icon = 'md_update', action = wezterm.action.EmitEvent('updater.check') },
      }
   end)
end

return M
