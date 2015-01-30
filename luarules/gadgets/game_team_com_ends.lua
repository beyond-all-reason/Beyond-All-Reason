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
local endmodes = {
	com=true,
}

if (gadgetHandler:IsSyncedCode()) then

--SYNCED

local destroyQueue = {}

local destroyUnitQueue = {}

local aliveCount = {}

local isAlive = {}

local GetTeamList=Spring.GetTeamList
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local DestroyUnit=Spring.DestroyUnit
local GetUnitPosition = Spring.GetUnitPosition
local SpawnCEG = Spring.SpawnCEG

local DISTANCE_LIMIT = (math.max(Game.mapSizeX,Game.mapSizeZ) * math.max(Game.mapSizeX,Game.mapSizeZ))
local min = math.min
local deathWave = false
local deathTimeBoost = 1

local function getSqrDistance(x1,z1,x2,z2)
  local dx,dz = x1-x2,z1-z2
  return (dx*dx)+(dz*dz)
end

function gadget:Initialize()
	if not endmodes[Spring.GetModOptions().deathmode] then
		gadgetHandler:RemoveGadget(self) -- in particular, this gadget is removed if deathmode is "killall" or "none"
	end
	for _,t in ipairs(Spring.GetAllyTeamList()) do
		aliveCount[t] = 0
	end
end

function gadget:GameFrame(t)
	if t % 16 < .1 then
		for at,defs in pairs(destroyQueue) do
			if aliveCount[at] <= 0 then --safety check, triggers on transferring the last com otherwise
				for _,team in ipairs(GetTeamList(at)) do
					for _,unitID in ipairs(GetTeamUnits(team)) do
						local x,y,z = GetUnitPosition(unitID)
						local deathTime = min(((getSqrDistance(x,z,defs.x,defs.z) / DISTANCE_LIMIT) * 250), 250)
						if (destroyUnitQueue[unitID] == nil) then
							destroyUnitQueue[unitID] = { 
									time = t + deathTime + math.random(0,5), 
									x = x, 
									y = y, 
									z = z, 
									spark = false 
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
				DestroyUnit(unitID, true)
				destroyUnitQueue[unitID] = nil
			end
		end
		deathTimeBoost = math.min(deathTimeBoost * 1.125, 250)
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
			local x,y,z = Spring.GetUnitPosition(u)
			destroyQueue[allyTeam] = {x = x, y = y, z = z}
		end
	end
end

function gadget:UnitTaken(u, ud, team)
	if isAlive[u] and UnitDefs[ud].customParams.iscommander then
		local allyTeam = GetUnitAllyTeam(u)
		aliveCount[allyTeam] = aliveCount[allyTeam] - 1
		if aliveCount[allyTeam] <= 0 then
			local x,y,z = Spring.GetUnitPosition(u)
			destroyQueue[allyTeam] = {x = x, y = y, z = z}
		end
	end
end

else

--UNSYNCED

return false

end
