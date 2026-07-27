local PolicyBuilder = VFS.Include("modules/policy_builder.lua")

---@class GameOverContext
---@field infos table<integer, { dead: boolean, teams: table<integer, true> }> per-ally-team liveness
---@field scriptedWinners integer[]|nil a MatchFlow verdict awaiting delivery
---@field fixedallies boolean
---@field sharedDynamicAllianceVictory boolean
---@field AreTeamsAllied fun(teamA: integer, teamB: integer): boolean

---@class MatchflowGameOverStages: PolicyStages<GameOverContext, GameOverVerdict>
---@field ScriptedVerdict string
---@field LastAllyStanding string

---@type MatchflowGameOverStages
local GameOver = {
	ScriptedVerdict = "ScriptedVerdict",
	LastAllyStanding = "LastAllyStanding",
}

---@class MatchflowPipelines what LoadPolicies("matchflow") hands back
---@field game_over AssembledPipeline<GameOverContext, GameOverVerdict>

---@class MatchflowPolicyStages
---@field game_over MatchflowGameOverStages

return PolicyBuilder.Stages("matchflow", { game_over = PolicyBuilder.Single(GameOver) })
