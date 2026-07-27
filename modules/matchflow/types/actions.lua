---@meta actions

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
