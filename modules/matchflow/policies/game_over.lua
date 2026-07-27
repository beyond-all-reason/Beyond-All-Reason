--- Legacy quirk preserved: the shared-alliance path returns a winner COUNT, not a list — the
--- original built the list, commented it out, and shipped the count. Fix later, once, here.

local Stages = VFS.Include("modules/matchflow/policy_stages.lua") ---@type MatchflowPolicyStages

local singleWinnerScratch = {}
local sharedWinnerScratch = {}

---@class GameOverVerdict
---@field winners integer[]|integer|nil the shared-alliance path's legacy count, or the winner list
---@field continue boolean|nil

---@param ctx GameOverContext
---@param firstAllyTeamID integer
---@param secondAllyTeamID integer
---@return boolean
local function AreAllyTeamsDoubleAllied(ctx, firstAllyTeamID, secondAllyTeamID)
	for teamA in pairs(ctx.infos[firstAllyTeamID].teams) do
		for teamB in pairs(ctx.infos[secondAllyTeamID].teams) do
			if not ctx.AreTeamsAllied(teamA, teamB) or not ctx.AreTeamsAllied(teamB, teamA) then
				return false
			end
		end
	end
	return true
end

---@param ctx GameOverContext
local function CheckSingleAllyVictoryEnd(ctx)
	for i = #singleWinnerScratch, 1, -1 do
		singleWinnerScratch[i] = nil
	end
	local winnerCount = 0
	for allyTeamID in pairs(ctx.infos) do
		if not ctx.infos[allyTeamID].dead then
			winnerCount = winnerCount + 1
			singleWinnerScratch[winnerCount] = allyTeamID
		end
	end
	if winnerCount > 1 then
		return false
	end
	return singleWinnerScratch
end

---@param ctx GameOverContext
local function CheckSharedAllyVictoryEnd(ctx)
	for allyTeamID in pairs(sharedWinnerScratch) do
		sharedWinnerScratch[allyTeamID] = nil
	end
	local winnerCountSquared = 0
	local aliveCount = 0
	for allyTeamA in pairs(ctx.infos) do
		if not ctx.infos[allyTeamA].dead then
			aliveCount = aliveCount + 1
			for allyTeamB in pairs(ctx.infos) do
				if not ctx.infos[allyTeamB].dead and AreAllyTeamsDoubleAllied(ctx, allyTeamA, allyTeamB) then
					-- since we're gonna check if we're allied against ourself, only secondAllyTeamID needs to be stored
					sharedWinnerScratch[allyTeamB] = true
					winnerCountSquared = winnerCountSquared + 1
				end
			end
		end
	end

	if aliveCount * aliveCount ~= winnerCountSquared then
		return false
	end

	local winnersCorrectFormatCount = 0
	for _winner in pairs(sharedWinnerScratch) do
		winnersCorrectFormatCount = winnersCorrectFormatCount + 1
	end
	return winnersCorrectFormatCount
end

Policies.Pipeline(Stages.game_over)
	.Select(Stages.game_over.ScriptedVerdict, function(ctx)
		if ctx.scriptedWinners ~= nil then
			return { winners = ctx.scriptedWinners }
		end
		return nil
	end)
	.Select(Stages.game_over.LastAllyStanding, function(ctx)
		local winners
		if not ctx.fixedallies and ctx.sharedDynamicAllianceVictory then
			winners = CheckSharedAllyVictoryEnd(ctx)
		else
			winners = CheckSingleAllyVictoryEnd(ctx)
		end
		if winners then
			return { winners = winners }
		end
		return { continue = true }
	end)
