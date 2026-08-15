--- MatchFlow's mission-sandbox verbs, pure half: lazy mirrors of the module
--- api. Victory(team) builds an effect for a Do chain; the imperative api
--- fires only when the trigger does. Takes the Team handle, not a raw
--- allyTeam id, so the mission line reads as English.

local MatchFlowVerbs = {}

---@param matchflowApi table the matchflow module api (ModuleHandler.Get)
---@return MatchFlowActions
function MatchFlowVerbs.Make(matchflowApi)
	return {
		---The mission-start condition. Empty inputs = evaluated once when the
		---trigger arms — arming IS the mission starting, so it holds at the
		---first cadence tick.
		---@return MissionCondition
		Started = function()
			return {
				inputs = {},
				---@param ctx MissionContext
				evaluate = function(ctx)
					return ctx.frame > 0
				end,
			}
		end,
		---@param team MissionTeam
		---@return MissionEffect
		Victory = function(team)
			assert(
				type(team) == "table" and type(team.allyTeam) == "number",
				"MatchFlow.Victory expects a Team handle (e.g. Team.Player)"
			)
			return {
				execute = function()
					matchflowApi.Victory(team.allyTeam)
				end,
			}
		end,
		---@param team MissionTeam
		---@return MissionEffect
		Defeat = function(team)
			assert(
				type(team) == "table" and type(team.allyTeam) == "number",
				"MatchFlow.Defeat expects a Team handle (e.g. Team.Player)"
			)
			return {
				execute = function()
					matchflowApi.Defeat({ team.allyTeam })
				end,
			}
		end,
	}
end

return MatchFlowVerbs
