---@meta dsl

--- The Combat vocabulary combat contributes to the mission sandbox. Protect
--- is an effect; its Until sugar bounds the protection with a companion
--- trigger — the literal desugared When(condition).Do(Combat.Unprotect(unit)).
---@class MissionCombat
---@field Protect fun(unit: MissionUnitRef): MissionProtectEffect
---@field Unprotect fun(unit: MissionUnitRef): MissionEffect

--- Combat.Protect's return: a plain effect plus the Until lifetime sugar.
---@class MissionProtectEffect
---@field execute fun(ctx: MissionContext)
---@field Until fun(condition: MissionCondition): MissionEffect

---@type MissionCombat
Combat = {}
