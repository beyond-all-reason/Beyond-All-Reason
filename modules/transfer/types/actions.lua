---@meta actions

---@class TransferGrant
---@field domain string
---@field category string|nil
---@field option string|nil the modoption the grant writes instead of the domain's own; a module that varies a grant by its own dimension sets it

---@class TransferUnits : TransferGrant
---@field Constructors TransferGrant
---@field Resource TransferGrant
---@overload fun(group: MissionUnitGroup|MissionGroupRef, team: MissionTeam): MissionEffect

---@class TransferResources : TransferGrant
---@field Metal TransferGrant
---@field Energy TransferGrant

---@class TransferGive
---@overload fun(group: MissionUnitGroup|MissionGroupRef, team: MissionTeam): MissionEffect

---@class TransferActions
---@field Units TransferUnits
---@field Resources TransferResources
---@field Give TransferGive

---@type TransferActions
Transfer = {}

---@type TransferGrant
Take = {}
