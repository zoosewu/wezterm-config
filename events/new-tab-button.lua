local wezterm = require('wezterm')
local launch_menu = require('config.launch').launch_menu
local domains = require('config.domains')
local Cells = require('utils.cells')
local cwd_util = require('utils.cwd')

local nf = wezterm.nerdfonts
local act = wezterm.action
local attr = Cells.attr

local M = {}

---@type table<string, Cells.SegmentColors>
-- stylua: ignore
local colors = {
   label_text   = { fg = '#CDD6F4' },
   icon_default = { fg = '#89B4FA' },
   icon_wsl     = { fg = '#FAB387' },
   icon_ssh     = { fg = '#F38BA8' },
   icon_unix    = { fg = '#CBA6F7' },
}

local cells = Cells:new()
   :add_segment('icon_default', ' ' .. nf.oct_terminal .. ' ', colors.icon_default)
   :add_segment('icon_wsl', ' ' .. nf.cod_terminal_linux .. ' ', colors.icon_wsl)
   :add_segment('icon_ssh', ' ' .. nf.md_ssh .. ' ', colors.icon_ssh)
   :add_segment('icon_unix', ' ' .. nf.dev_gnu .. ' ', colors.icon_unix)
   :add_segment('label_text', '', colors.label_text, attr(attr.intensity('Bold')))

local function build_choices()
   local choices = {}
   local choices_data = {}
   local idx = 1

   -- Add launch menu items (DefaultDomain)
   for _, v in ipairs(launch_menu) do
      cells:update_segment_text('label_text', v.label)

      table.insert(choices, {
         id = tostring(idx),
         label = wezterm.format(cells:render({ 'icon_default', 'label_text' })),
      })
      table.insert(choices_data, {
         kind = 'local',
         spawn = { args = v.args, domain = 'DefaultDomain' },
      })
      idx = idx + 1
   end

   -- Add WSL domains
   for _, v in ipairs(domains.wsl_domains) do
      cells:update_segment_text('label_text', v.name)

      table.insert(choices, {
         id = tostring(idx),
         label = wezterm.format(cells:render({ 'icon_wsl', 'label_text' })),
      })
      table.insert(choices_data, {
         kind = 'wsl',
         spawn = { domain = { DomainName = v.name } },
      })
      idx = idx + 1
   end

   -- Add SSH domains
   for _, v in ipairs(domains.ssh_domains) do
      cells:update_segment_text('label_text', v.name)
      table.insert(choices, {
         id = tostring(idx),
         label = wezterm.format(cells:render({ 'icon_ssh', 'label_text' })),
      })
      table.insert(choices_data, {
         kind = 'remote',
         spawn = { domain = { DomainName = v.name } },
      })
      idx = idx + 1
   end

   -- Add Unix domains
   for _, v in ipairs(domains.unix_domains) do
      cells:update_segment_text('label_text', v.name)
      table.insert(choices, {
         id = tostring(idx),
         label = wezterm.format(cells:render({ 'icon_unix', 'label_text' })),
      })
      table.insert(choices_data, {
         kind = 'remote',
         spawn = { domain = { DomainName = v.name } },
      })
      idx = idx + 1
   end

   return choices, choices_data
end

local choices, choices_data = build_choices()

---Build a SpawnCommand for a launch-menu entry, inheriting the pane's CWD.
---`choices_data` is shared module state, so never mutate it in place.
---@param entry table entry from `choices_data`
---@param pane any WezTerm Pane the launcher was invoked from
---@return table
local function build_spawn(entry, pane)
   local cwd
   if entry.kind == 'local' then
      cwd = cwd_util.get_local(pane)
   elseif entry.kind == 'wsl' then
      cwd = cwd_util.to_wsl(cwd_util.get(pane))
   end
   -- 'remote' (ssh/unix): a local path is meaningless there, so leave cwd unset

   return { args = entry.spawn.args, domain = entry.spawn.domain, cwd = cwd }
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
               action = wezterm.action_callback(function(_window, _pane, id, label)
                  if not id and not label then
                     return
                  else
                     wezterm.log_info('you selected ', id, label)
                     local entry = choices_data[tonumber(id)]
                     wezterm.log_info(entry)
                     window:perform_action(
                        act.SpawnCommandInNewTab(build_spawn(entry, pane)),
                        pane
                     )
                  end
               end),
            }),
            pane
         )
      end
      return false
   end)
end

return M
