function gadget:GetInfo()
	return {
		name = "Team Com Ends + dead allyteam blowup",
		desc = "Implements com ends for allyteams + blows up team if no players left",
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
local endmodes = {
	com=true,
}

if (gadgetHandler:IsSyncedCode()) then

--SYNCED

local destroyQueue = {}

local destroyUnitQueue = {}

local aliveCount = {}
local deadAllyTeams = {}
local isAlive = {}

local GetTeamList=Spring.GetTeamList
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local DestroyUnit=Spring.DestroyUnit
local GetUnitPosition = Spring.GetUnitPosition
local SpawnCEG = Spring.SpawnCEG

local DISTANCE_LIMIT = (math.max(Game.mapSizeX,Game.mapSizeZ) * math.max(Game.mapSizeX,Game.mapSizeZ))
local min = math.min
local deathWave = false -- is the death wave happening right now?
local deathTimeBoost = 1
local modeComEnds = true

local gaiaTeamID = Spring.GetGaiaTeamID()
local allyTeamList = Spring.GetAllyTeamList()


local teamCount = 0
for _,teamID in ipairs(GetTeamList()) do
	if teamID ~= gaiaTeamID then
		teamCount = teamCount + 1
	end
end

local blowUpWhenEmptyAllyTeam = true
if Spring.GetModOptions() and Spring.GetModOptions().ffa_mode ~= nil and (tonumber(Spring.GetModOptions().ffa_mode) or 0) == 1 then
	blowUpWhenEmptyAllyTeam = false
end
if teamCount == 2 then
	blowUpWhenEmptyAllyTeam = false -- let player quit & rejoin in 1v1
end

blowUpWhenEmptyAllyTeam = false -- disabled for now because other gadget already seems to handle this


local function getSqrDistance(x1,z1,x2,z2)
  local dx,dz = x1-x2,z1-z2
  return (dx*dx)+(dz*dz)
end

function gadget:Initialize()
	if not endmodes[Spring.GetModOptions().deathmode] then
		if blowUpWhenEmptyAllyTeam == false then
			gadgetHandler:RemoveGadget(self) -- in particular, this gadget is removed if deathmode is "killall" or "none"
		end
		modeComEnds = false
	end
	for _,t in ipairs(Spring.GetAllyTeamList()) do
		aliveCount[t] = 0
	end
end


function gadget:GameFrame(t)

	if t % 15 < .1 then
		-- blow up an allyteam when it has no players left
		if blowUpWhenEmptyAllyTeam then
			for _,allyTeamID in ipairs(allyTeamList) do
				if deadAllyTeams[allyTeamID] == nil then
					local deadAllyTeam = true
					local teamsList = GetTeamList(allyTeamID)
					for _,teamID in ipairs(teamsList) do
						local _,_,_,isAi, _, _ = Spring.GetTeamInfo(teamID)
						if isAi or teamID == gaiaTeamID then
							deadAllyTeam = false
						else
							local playersList = Spring.GetPlayerList(teamID,true)
							for _,playerID in ipairs(playersList) do
								local name,_,isSpec = Spring.GetPlayerInfo(playerID)
								if name ~= nil and not isSpec then
									deadAllyTeam = false
								end
							end
						end
					end
					if deadAllyTeam then
						destroyQueue[allyTeamID] = {x=0,y=0,z=0}
						aliveCount[allyTeamID] = 0
						deadAllyTeams[allyTeamID] = true
						for _,teamID in ipairs(teamsList) do
							Spring.KillTeam(teamID)
						end
						break
					end
				end
			end
		end

		for at,defs in pairs(destroyQueue) do
			if aliveCount[at] <= 0 then --safety check, triggers on transferring the last com otherwise
				for _,team in ipairs(GetTeamList(at)) do
					for _,unitID in ipairs(GetTeamUnits(team)) do
						local x,y,z = GetUnitPosition(unitID)
						local deathTime = min(((getSqrDistance(x,z,defs.x,defs.z) / DISTANCE_LIMIT) * 450), 450)
						if (destroyUnitQueue[unitID] == nil) then
							destroyUnitQueue[unitID] = {
								time = t + deathTime + math.random(0,7),
								x = x,
								y = y,
								z = z,
								spark = false,
                                a = defs.a,
							}
						end
					end
				end
				deathWave = true
			end
			destroyQueue[at]=nil
		end
	end

	if (deathWave) and next(destroyUnitQueue) then
		local dt = (t + deathTimeBoost)
		for unitID, defs in pairs(destroyUnitQueue) do
			if ((dt > (defs.time - 15)) and (defs.spark == false)) then
				SpawnCEG("DEATH_WAVE_SPARKS",defs.x,defs.y,defs.z,0,0,0)
				destroyUnitQueue[unitID].spark = true
			end
			if (dt > defs.time) then
                if defs.a then DestroyUnit(unitID, true, nil, defs.a)
                    else DestroyUnit(unitID, true) -- if 4th arg is given, it cannot be nil (or engine complains)                
                end
				destroyUnitQueue[unitID] = nil
			end
		end
		deathTimeBoost = math.min(deathTimeBoost * 1.5, 500)
	end
	
end

function gadget:UnitCreated(u, ud, team)
	if modeComEnds then
		isAlive[u] = true
		if UnitDefs[ud].customParams.iscommander then
			local allyTeam = GetUnitAllyTeam(u)
			aliveCount[allyTeam] = aliveCount[allyTeam] + 1
		end
	end
end

function gadget:UnitGiven(u, ud, team)
	if modeComEnds then
		if UnitDefs[ud].customParams.iscommander then
			local allyTeam = GetUnitAllyTeam(u)
			aliveCount[allyTeam] = aliveCount[allyTeam] + 1
		end
	end
end

function gadget:UnitDestroyed(u, ud, team, a, ad, ateam)
	if modeComEnds then
		isAlive[u] = nil
		if UnitDefs[ud].customParams.iscommander then
			local allyTeam = GetUnitAllyTeam(u)
			aliveCount[allyTeam] = aliveCount[allyTeam] - 1
			if aliveCount[allyTeam] <= 0 then
				local x,y,z = Spring.GetUnitPosition(u)
				destroyQueue[allyTeam] = {x = x, y = y, z = z, a = a }
				if not _G.destroyingTeam then
					_G.destroyingTeam = {}
				end
				_G.destroyingTeam[allyTeam] = true
            end
		end
	end
end

function gadget:UnitTaken(u, ud, team, a, ad, ateam)
	if modeComEnds and isAlive[u] and UnitDefs[ud].customParams.iscommander then
		local allyTeam = GetUnitAllyTeam(u)
		aliveCount[allyTeam] = aliveCount[allyTeam] - 1
		if aliveCount[allyTeam] <= 0 then
			local x,y,z = Spring.GetUnitPosition(u)
			destroyQueue[allyTeam] = {x = x, y = y, z = z, a = a}
		end
	end
end



else

--UNSYNCED

return false

end
