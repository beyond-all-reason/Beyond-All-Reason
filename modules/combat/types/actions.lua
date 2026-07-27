---@meta actions

--- Combat's actions, declared once for every grammar that names them. Each is
--- a class that is callable where it can be performed; a mode facet (a domain
--- a grant is written against) can be added to any of them without a second
--- declaration somewhere else.

--- Protect a unit. Its .Until sugar bounds that protection's LIFETIME with a
--- companion trigger — the desugared When(condition).Do(Combat.Unprotect(unit)),
--- armed when the protection is applied, not at load.
---@class CombatProtect
---@overload fun(unit: MissionUnitRef): MissionProtectEffect

---@class CombatUnprotect
---@overload fun(unit: MissionUnitRef): MissionEffect

--- Protect's return: a plain effect plus the Until lifetime sugar.
---@class MissionProtectEffect
---@field execute fun(ctx: MissionContext)
---@field Until fun(condition: MissionCondition): MissionEffect

---@class CombatActions
---@field Protect CombatProtect
---@field Unprotect CombatUnprotect

---@type CombatActions
Combat = {}
