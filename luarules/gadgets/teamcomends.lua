function gadget:GetInfo()
	return {
		name = "Team Com Ends",
		desc = "Implements com ends for allyteams",
		author = "KDR_11k (David Becker)",
		date = "2008-02-04",
		license = "Public domain",
		layer = 1,
		enabled = true
	}
end

-- this acts just like Com Ends except instead of killing a player's units when
-- his com dies it acts on an allyteam level, if all coms in an allyteam are dead
-- the allyteam is out

-- the deathmode modoption must be set to one of the following to enable this

local endmodes= {
	com=true,
	comcontrol=true,
}

if (gadgetHandler:IsSyncedCode()) then

--SYNCED

local destroyQueue = {}

local aliveCount = {}

local isAlive = {}

local GetTeamList=Spring.GetTeamList
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local DestroyUnit=Spring.DestroyUnit

function gadget:GameFrame(t)
	if t % 32 < .1 then
		for at,_ in pairs(destroyQueue) do
			if aliveCount[at] <= 0 then --safety check, triggers on transferring the last com otherwise
				for _,team in ipairs(GetTeamList(at)) do
					for _,u in ipairs(GetTeamUnits(team)) do
						DestroyUnit(u, true)
					end
				end
			end
			destroyQueue[t]=nil
		end
	end
end

function gadget:UnitCreated(u, ud, team)
	isAlive[u] = true
	if UnitDefs[ud].customParams.iscommander then
		local allyTeam = GetUnitAllyTeam(u)
		aliveCount[allyTeam] = aliveCount[allyTeam] + 1
	end
end

function gadget:UnitGiven(u, ud, team)
	if UnitDefs[ud].customParams.iscommander then
		local allyTeam = GetUnitAllyTeam(u)
		aliveCount[allyTeam] = aliveCount[allyTeam] + 1
	end
end

function gadget:UnitDestroyed(u, ud, team)
	isAlive[u] = nil
	if UnitDefs[ud].customParams.iscommander then
		local allyTeam = GetUnitAllyTeam(u)
		aliveCount[allyTeam] = aliveCount[allyTeam] - 1
		if aliveCount[allyTeam] <= 0 then
			destroyQueue[allyTeam] = true
		end
	end
end

function gadget:UnitTaken(u, ud, team)
	if isAlive[u] and UnitDefs[ud].customParams.iscommander then
		local allyTeam = GetUnitAllyTeam(u)
		aliveCount[allyTeam] = aliveCount[allyTeam] - 1
		if aliveCount[allyTeam] <= 0 then
			destroyQueue[allyTeam] = true
		end
	end
end

function gadget:Initialize()
	if not endmodes[Spring.GetModOptions().deathmode] then
		gadgetHandler:RemoveGadget()
	end
	for _,t in ipairs(Spring.GetAllyTeamList()) do
		aliveCount[t] = 0
	end
end

else

--UNSYNCED

return false

end
