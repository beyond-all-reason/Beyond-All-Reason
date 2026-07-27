--- The game-over decision, extracted from game_end.lua's CheckSingle/
--- CheckSharedAllyVictoryEnd. Pure functions over the ctx the gadget hands in;
--- first non-nil result wins; the terminal Compute always returns (explicit
--- continue, the sharing-module precedent).
---
--- GameOverCtx (built by the game_end gadget per evaluation):
---   infos                        liveness.Infos() — allyTeamInfos view
---   scriptedWinners              pending MatchFlow.Victory/Defeat verdict, or nil
---   fixedallies                  modoption; forces the single-ally check
---   sharedDynamicAllianceVictory modoption; enables the alliance cross-check
---   AreTeamsAllied               fun(teamA, teamB): boolean (engine read)
---
--- Legacy quirk preserved: the shared-alliance path returns a winner COUNT
--- (a number), not a winner list — the original built the list, commented it
--- out, and shipped the count. Bit-identical behavior first; fix later, once,
--- here.

local singleWinnerScratch = {}
local sharedWinnerScratch = {}

local function AreAllyTeamsDoubleAllied(ctx, firstAllyTeamID, secondAllyTeamID)
	-- we need to check for both directions of alliance
	for teamA in pairs(ctx.infos[firstAllyTeamID].teams) do
		for teamB in pairs(ctx.infos[secondAllyTeamID].teams) do
			if not ctx.AreTeamsAllied(teamA, teamB) or not ctx.AreTeamsAllied(teamB, teamA) then
				return false
			end
		end
	end
	return true
end

-- find the last remaining allyteam
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

-- we have to cross check all the alliances
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
					-- store both check directions
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

	-- all the allyteams alive are bidirectionally allied against eachother, they are all winners
	local winnersCorrectFormatCount = 0
	for _winner in pairs(sharedWinnerScratch) do
		winnersCorrectFormatCount = winnersCorrectFormatCount + 1
	end
	return winnersCorrectFormatCount
end

Policies.Pipeline()
	:Gate("MissionOverride", function(ctx)
		-- scripted verdicts (CampaignAPI / MatchFlow.Victory) exit through the
		-- same pipeline as every other end condition — not a bypass
		if ctx.scriptedWinners ~= nil then
			return { winners = ctx.scriptedWinners }
		end
		return nil
	end)
	:Compute("LastAllyStanding", function(ctx)
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
	:Register()
