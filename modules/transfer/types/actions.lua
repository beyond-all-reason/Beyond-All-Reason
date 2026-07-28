---@meta actions

---@class TransferGrant
---@field domain string
---@field category string|nil
---@field tier integer|nil

---@class TransferUnits : TransferGrant
---@field AtT2 TransferGrant
---@field AtT3 TransferGrant
---@field Constructors TransferGrant
---@field Resource TransferGrant
---@overload fun(group: MissionUnitGroup|MissionGroupRef, team: MissionTeam): MissionEffect

---@class TransferResources : TransferGrant
---@field Metal TransferGrant
---@field Energy TransferGrant
---@field AtT2 TransferGrant
---@field AtT3 TransferGrant

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

---@type TransferGrant
Tech = {}
