local wezterm = require('wezterm')
local launch_menu = require('config.launch').launch_menu
local domains = require('config.domains')
local cwd_util = require('utils.cwd')
local segment = require('utils.segment')

local nf = wezterm.nerdfonts
local act = wezterm.action

local M = {}

-- stylua: ignore
local ICONS = {
   ['local'] = { glyph = nf.oct_terminal,       color = { fg = '#89B4FA' } },
   wsl       = { glyph = nf.cod_terminal_linux, color = { fg = '#FAB387' } },
   ssh       = { glyph = nf.md_ssh,             color = { fg = '#F38BA8' } },
   unix      = { glyph = nf.dev_gnu,            color = { fg = '#CBA6F7' } },
}
local LABEL_COLOR = { fg = '#CDD6F4' }

---@param icon string key of ICONS
---@param text string
---@return string
local function label(icon, text)
   local items = segment.append({}, ' ' .. ICONS[icon].glyph .. ' ', ICONS[icon].color)
   return wezterm.format(segment.append(items, text, LABEL_COLOR, true))
end

local function build_choices()
   local choices = {}
   local spawns = {}

   local function add(icon, text, spawn)
      table.insert(choices, { id = tostring(#choices + 1), label = label(icon, text) })
      table.insert(spawns, spawn)
   end

   for _, v in ipairs(launch_menu) do
      add('local', v.label, { args = v.args, domain = 'DefaultDomain' })
   end
   for _, v in ipairs(domains.wsl_domains) do
      add('wsl', v.name, { domain = { DomainName = v.name } })
   end
   for _, v in ipairs(domains.ssh_domains) do
      add('ssh', v.name, { domain = { DomainName = v.name } })
   end
   for _, v in ipairs(domains.unix_domains) do
      add('unix', v.name, { domain = { DomainName = v.name } })
   end

   return choices, spawns
end

local choices, spawns = build_choices()

---Build a SpawnCommand for a launch-menu entry, inheriting the pane's CWD.
---`spawns` is shared module state, so never mutate it in place.
---@param spawn table entry from `spawns`
---@param pane any WezTerm Pane the launcher was invoked from
---@return table
local function build_spawn(spawn, pane)
   return { args = spawn.args, domain = spawn.domain, cwd = cwd_util.for_domain(pane, spawn.domain) }
end

M.setup = function()
   wezterm.on('new-tab-button-click', function(window, pane, button, default_action)
      if default_action and button == 'Left' then
         window:perform_action(default_action, pane)
      end

      if default_action and button == 'Right' then
         window:perform_action(
            act.InputSelector({
               title = 'InputSelector: Launch Menu',
               choices = choices,
               fuzzy = true,
               fuzzy_description = nf.md_rocket .. ' Select a lauch item: ',
               action = wezterm.action_callback(function(_window, _pane, id)
                  local spawn = id and spawns[tonumber(id)]
                  if not spawn then
                     return
                  end
                  window:perform_action(act.SpawnCommandInNewTab(build_spawn(spawn, pane)), pane)
               end),
            }),
            pane
         )
      end
      return false
   end)
end

return M
