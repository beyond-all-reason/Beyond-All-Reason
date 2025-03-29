---@meta

---@class Addon
local Addon = {}

---Get info about an addon.
---@return AddonInfo
function Addon:GetInfo() end

---@class AddonInfo
---@field name string?
---@field desc string?
---@field author string?
---@field date string?
---@field license string?
---@field layer number?
---@field enabled boolean?
