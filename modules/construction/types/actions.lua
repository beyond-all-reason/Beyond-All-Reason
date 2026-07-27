---@meta actions

--- Construction's actions, declared once for both grammars. Each names
--- something a builder may do for an ally; a mode grants or denies it, and
--- parameterises it where the verb takes terms (a build delay, in seconds).

--- A grant written against a construction action.
---@class ConstructionGrant
---@field domain string
---@field category string|nil
---@field tier integer|nil

---@class ConstructionActions
---@field Assist ConstructionGrant
---@field Reclaim ConstructionGrant
---@field Resurrect ConstructionGrant
---@field Build ConstructionGrant

---@type ConstructionActions
Construction = {}
