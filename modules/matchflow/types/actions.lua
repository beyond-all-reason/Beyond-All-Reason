---@meta actions

--- MatchFlow's actions, declared once for every grammar that names them.
--- Each is a class that is callable where it can be performed; a mode facet
--- (a domain a grant is written against) can be added to any of them without
--- a second declaration somewhere else.

--- Holds from the first cadence tick after arming.
---@class MatchFlowStarted
---@overload fun(): MissionCondition

---@class MatchFlowVictory
---@overload fun(team: MissionTeam): MissionEffect

---@class MatchFlowDefeat
---@overload fun(team: MissionTeam): MissionEffect

---@class MatchFlowActions
---@field Started MatchFlowStarted
---@field Victory MatchFlowVictory
---@field Defeat MatchFlowDefeat

---@type MatchFlowActions
MatchFlow = {}
