---@meta actions

--- What combat's contribution adds to the mission context.
---@class (partial) MissionContext
---@field Protect fun(name: string) protection by roster name, counted in the mission's ledger
---@field Unprotect fun(name: string) releases one of this mission's own counts, never another holder's

--- Until arms its Unprotect trigger when the protection is applied, not at load.
---@class CombatProtect
---@overload fun(unit: MissionUnitRef): MissionProtectEffect

---@class CombatUnprotect
---@overload fun(unit: MissionUnitRef): MissionEffect

---@class MissionProtectEffect
---@field execute fun(ctx: MissionContext)
---@field Until fun(condition: MissionCondition): MissionEffect

---@class CombatActions
---@field Protect CombatProtect
---@field Unprotect CombatUnprotect

---@type CombatActions
Combat = {}
