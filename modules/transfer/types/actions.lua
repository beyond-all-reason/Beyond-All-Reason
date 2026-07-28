---@meta actions

--- Transfer's actions, declared once for both grammars. A mode names one to
--- grant it, a mission calls one to perform it, and this is the declaration
--- both read — an action cannot mean one thing to a mode file and another to
--- a trigger file, because there is only the one entry.
---
--- An action is callable where it can be performed (@overload) and carries
--- variants where a grant can be narrowed (.AtT2, .Constructors). Either
--- facet may be absent: Give cannot be granted, Assist cannot be performed.

--- Narrowing a grant: the same action, said of one unit category or one tech
--- tier. Not callable — a mission performs the action, not a slice of it.
---@class TransferGrant
---@field domain string
---@field category string|nil
---@field tier integer|nil

--- Units: grantable, narrowable, and performable.
---@class TransferUnits : TransferGrant
---@field AtT2 TransferGrant
---@field AtT3 TransferGrant
---@field Constructors TransferGrant
---@field Resource TransferGrant
---@overload fun(group: MissionUnitGroup, team: MissionTeam): MissionEffect

--- Resources: grantable and narrowable; nothing performs it from a trigger.
---@class TransferResources : TransferGrant
---@field Metal TransferGrant
---@field Energy TransferGrant
---@field AtT2 TransferGrant
---@field AtT3 TransferGrant

--- Fiat: performable, and deliberately not grantable — a mode has no say, so
--- there is no domain for a grant to be written against.
---@class TransferGive
---@overload fun(group: MissionUnitGroup, team: MissionTeam): MissionEffect

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
