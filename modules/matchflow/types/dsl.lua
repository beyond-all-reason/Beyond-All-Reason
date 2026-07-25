---@meta dsl

--- The MatchFlow vocabulary matchflow contributes to the mission sandbox:
--- lazy mirrors of the module api, plus the Started condition. They take the
--- Team handle so mission lines read as English.
---@class MissionMatchFlow
---@field Started fun(): MissionCondition holds from the first cadence tick after arming
---@field Victory fun(team: MissionTeam): MissionEffect
---@field Defeat fun(team: MissionTeam): MissionEffect

---@type MissionMatchFlow
MatchFlow = {}
