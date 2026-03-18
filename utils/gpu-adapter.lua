local wezterm = require('wezterm')
local platform = require('utils.platform')

---@alias WeztermGPUBackend 'Vulkan'|'Metal'|'Gl'|'Dx12'
---@alias WeztermGPUDeviceType 'DiscreteGpu'|'IntegratedGpu'|'Cpu'|'Other'

---@class WeztermGPUAdapter
---@field name string
---@field backend WeztermGPUBackend
---@field device number
---@field device_type WeztermGPUDeviceType
---@field driver? string
---@field driver_info? string
---@field vendor string

---@alias AdapterMap { [WeztermGPUBackend]: WeztermGPUAdapter|nil }|nil

---@class GpuAdapters
---@field __backends WeztermGPUBackend[]
---@field __preferred_backend WeztermGPUBackend
---@field DiscreteGpu AdapterMap
---@field IntegratedGpu AdapterMap
---@field Cpu AdapterMap
---@field Other AdapterMap
local GpuAdapters = {}
GpuAdapters.__index = GpuAdapters

---See `https://github.com/gfx-rs/wgpu#supported-platforms` for more info on available backends
GpuAdapters.AVAILABLE_BACKENDS = {
   windows = { 'Dx12', 'Vulkan', 'Gl' },
   linux = { 'Vulkan', 'Gl' },
   mac = { 'Metal' },
}

-- Disk cache for GPU adapter list.
-- Avoids the ~270ms cold-start cost of wezterm.gui.enumerate_gpus() on every launch.
local CACHE_FILE = wezterm.config_dir .. '/gpu-cache.json'

---Read GPU adapter list from disk cache.
---@return WeztermGPUAdapter[]|nil
local function read_cache()
   local f = io.open(CACHE_FILE, 'r')
   if not f then return nil end
   local content = f:read('*a')
   f:close()
   local ok, data = pcall(wezterm.json_decode, content)
   if ok and type(data) == 'table' and #data > 0 then return data end
   return nil
end

---Write GPU adapter list to disk cache.
---@param gpus WeztermGPUAdapter[]
local function write_cache(gpus)
   if #gpus == 0 then return end
   local ok, json = pcall(wezterm.json_encode, gpus)
   if not ok then
      wezterm.log_warn('[gpu-adapter] encode failed: ' .. tostring(json))
      return
   end
   local f = io.open(CACHE_FILE, 'w')
   if not f then
      wezterm.log_warn('[gpu-adapter] cannot write cache: ' .. CACHE_FILE)
      return
   end
   f:write(json)
   f:close()
   wezterm.log_info('[gpu-adapter] cache updated (' .. #gpus .. ' adapter(s))')
end

-- Fast path: load from disk cache so enumerate_gpus() is skipped at startup.
-- On first launch (no cache), ENUMERATED_GPUS is empty and pick_best()/pick_manual()
-- return nil — WezTerm auto-selects the GPU for this session.
local _cached = read_cache()
GpuAdapters.ENUMERATED_GPUS = _cached or {}

if _cached then
   wezterm.log_info('[gpu-adapter] loaded ' .. #_cached .. ' adapter(s) from cache')
else
   wezterm.log_info('[gpu-adapter] no cache — WezTerm will auto-select GPU this session')
end

-- Background cache refresh: runs once per WezTerm session, 2 seconds after GUI starts.
-- Re-enumerates adapters and writes cache so the next launch uses the correct adapter.
-- wezterm.GLOBAL prevents duplicate registrations across config hot-reloads.
if not wezterm.GLOBAL._gpu_cache_refresh_registered then
   wezterm.GLOBAL._gpu_cache_refresh_registered = true
   wezterm.on('gui-startup', function()
      wezterm.time.call_after(2, function()
         local fresh = wezterm.gui.enumerate_gpus()
         write_cache(fresh)
      end)
   end)
end

---@return GpuAdapters
---@private
function GpuAdapters:init()
   local initial = {
      __backends = self.AVAILABLE_BACKENDS[platform.os],
      __preferred_backend = self.AVAILABLE_BACKENDS[platform.os][1],
      DiscreteGpu = nil,
      IntegratedGpu = nil,
      Cpu = nil,
      Other = nil,
   }

   for _, adapter in ipairs(self.ENUMERATED_GPUS) do
      if not initial[adapter.device_type] then
         initial[adapter.device_type] = {}
      end
      initial[adapter.device_type][adapter.backend] = adapter
   end

   return setmetatable(initial, self)
end

---Will pick the best adapter based on the following criteria:
---   1. Best GPU available (Discrete > Integrated > Other (for wgpu's OpenGl implementation on Discrete GPU) > Cpu)
---   2. Best graphics API available (based off my very scientific scroll a big log file in neovim test 😁)
---
---Graphics API choices are based on the platform:
---   - Windows: Dx12 > Vulkan > OpenGl
---   - Linux: Vulkan > OpenGl
---   - Mac: Metal
---@see GpuAdapters.AVAILABLE_BACKENDS
---
---If the best adapter combo is not found, it will return `nil` and lets Wezterm decide the best adapter.
---@return WeztermGPUAdapter|nil
function GpuAdapters:pick_best()
   local adapters_options = self.DiscreteGpu
   local preferred_backend = self.__preferred_backend

   if not adapters_options then
      adapters_options = self.IntegratedGpu
   end

   if not adapters_options then
      adapters_options = self.Other
      preferred_backend = 'Gl'
   end

   if not adapters_options then
      adapters_options = self.Cpu
   end

   if not adapters_options then
      wezterm.log_warn('[gpu-adapter] no adapters in cache — letting WezTerm auto-select')
      return nil
   end

   local adapter_choice = adapters_options[preferred_backend]

   if not adapter_choice then
      wezterm.log_warn('[gpu-adapter] preferred backend not in cache — letting WezTerm auto-select')
      return nil
   end

   return adapter_choice
end

---Manually pick the adapter based on the backend and device type.
---If the adapter is not found, it will return nil and lets Wezterm decide the best adapter.
---@param backend WeztermGPUBackend
---@param device_type WeztermGPUDeviceType
---@return WeztermGPUAdapter|nil
function GpuAdapters:pick_manual(backend, device_type)
   local adapters_options = self[device_type]

   if not adapters_options then
      wezterm.log_warn('[gpu-adapter] device type not in cache — letting WezTerm auto-select')
      return nil
   end

   local adapter_choice = adapters_options[backend]

   if not adapter_choice then
      wezterm.log_warn('[gpu-adapter] backend not in cache — letting WezTerm auto-select')
      return nil
   end

   return adapter_choice
end

return GpuAdapters:init()
