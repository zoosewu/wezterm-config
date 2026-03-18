local wezterm = require('wezterm')
local Cells = require('utils.cells')

local nf = wezterm.nerdfonts
local attr = Cells.attr

local M = {}

local GLYPH_SEMI_CIRCLE_LEFT  = nf.ple_left_half_circle_thick
local GLYPH_SEMI_CIRCLE_RIGHT = nf.ple_right_half_circle_thick
local GLYPH_KEY_TABLE         = nf.md_table_key
local GLYPH_KEY               = nf.md_key
local GLYPH_WORKSPACE         = nf.md_layers_triple
local GLYPH_PANE              = nf.oct_terminal

-- stylua: ignore
local colors = {
   keytable  = { default = { bg = '#fab387', fg = '#1c1b19' }, scircle = { bg = 'rgba(0, 0, 0, 0.4)', fg = '#fab387' } },
   workspace = { default = { bg = '#cba6f7', fg = '#1c1b19' }, scircle = { bg = 'rgba(0, 0, 0, 0.4)', fg = '#cba6f7' } },
   pane      = { default = { bg = '#a6e3a1', fg = '#1c1b19' }, scircle = { bg = 'rgba(0, 0, 0, 0.4)', fg = '#a6e3a1' } },
}

local cells = Cells:new()
cells
   -- keytable segment (orange)
   :add_segment('kt_left',  GLYPH_SEMI_CIRCLE_LEFT,  colors.keytable.scircle, attr(attr.intensity('Bold')))
   :add_segment('kt_icon',  ' ',                      colors.keytable.default, attr(attr.intensity('Bold')))
   :add_segment('kt_text',  ' ',                      colors.keytable.default, attr(attr.intensity('Bold')))
   :add_segment('kt_right', GLYPH_SEMI_CIRCLE_RIGHT,  colors.keytable.scircle, attr(attr.intensity('Bold')))
   -- workspace segment (purple)
   :add_segment('ws_left',  GLYPH_SEMI_CIRCLE_LEFT,   colors.workspace.scircle, attr(attr.intensity('Bold')))
   :add_segment('ws_icon',  ' ' .. GLYPH_WORKSPACE,   colors.workspace.default, attr(attr.intensity('Bold')))
   :add_segment('ws_text',  ' default',               colors.workspace.default, attr(attr.intensity('Bold')))
   :add_segment('ws_right', GLYPH_SEMI_CIRCLE_RIGHT,  colors.workspace.scircle, attr(attr.intensity('Bold')))
   -- pane process segment (green)
   :add_segment('pn_left',  GLYPH_SEMI_CIRCLE_LEFT,   colors.pane.scircle, attr(attr.intensity('Bold')))
   :add_segment('pn_icon',  ' ' .. GLYPH_PANE,        colors.pane.default, attr(attr.intensity('Bold')))
   :add_segment('pn_text',  ' ',                      colors.pane.default, attr(attr.intensity('Bold')))
   :add_segment('pn_right', GLYPH_SEMI_CIRCLE_RIGHT,  colors.pane.scircle, attr(attr.intensity('Bold')))

---Remove path prefix and .exe suffix from a process name
---@param proc string
---@return string
local function clean_proc(proc)
   local name = proc:match('[/\\]([^/\\]+)$') or proc
   return name:gsub('%.exe$', '')
end

M.setup = function()
   wezterm.on('update-left-status', function(window, pane)
      local key_name  = window:active_key_table()
      local is_leader = window:leader_is_active()
      local ws_name   = wezterm.mux.get_active_workspace()
      local proc_name = clean_proc(pane:get_foreground_process_name() or '')

      local segments = {}

      -- keytable / leader segment (only when active)
      if key_name or is_leader then
         if is_leader then
            cells:update_segment_text('kt_icon', GLYPH_KEY)
            cells:update_segment_text('kt_text', ' ')
         else
            cells:update_segment_text('kt_icon', GLYPH_KEY_TABLE)
            cells:update_segment_text('kt_text', ' ' .. string.upper(key_name))
         end
         for _, s in ipairs({ 'kt_left', 'kt_icon', 'kt_text', 'kt_right' }) do
            table.insert(segments, s)
         end
      end

      -- workspace segment (always shown)
      cells:update_segment_text('ws_text', ' ' .. (ws_name ~= '' and ws_name or 'default'))
      for _, s in ipairs({ 'ws_left', 'ws_icon', 'ws_text', 'ws_right' }) do
         table.insert(segments, s)
      end

      -- pane process segment (only when process name is known)
      if proc_name ~= '' then
         cells:update_segment_text('pn_text', ' ' .. proc_name)
         for _, s in ipairs({ 'pn_left', 'pn_icon', 'pn_text', 'pn_right' }) do
            table.insert(segments, s)
         end
      end

      window:set_left_status(wezterm.format(cells:render(segments)))
   end)
end

return M
