---@meta actions

--- What transfer's contribution adds to the mission context.
---@class (partial) MissionContext
---@field TransferGroup fun(groupName: string, teamID: integer, fiat: boolean|nil) a roster group changes hands; fiat skips the mode's say

--- Not callable: a mission performs the action, not a slice of it.
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
