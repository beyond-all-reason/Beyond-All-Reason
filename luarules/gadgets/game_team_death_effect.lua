function gadget:GetInfo()
	return {
		name = "Team Death Effect",
		desc = "blows up a teams units in a gradual/wave like manner",
		author = "Floris", -- original: KDR_11k (David Becker)",
		date = "September 2021",
		license = "",
		layer = 1,
		enabled = true
	}
end

-- other gadgets can call a unit death wave with:
-- GG.wipeoutTeam(teamID, originX, originZ, attackerUnitID)
-- attackerUnitID is optional, originX, originZ will be set as 0 when not defined

-- this gadget wont do: Spring.KillTeam(...)

if not gadgetHandler:IsSyncedCode() then
	return
end

local wavePeriod = 220

--local spSpawnCEG = Spring.SpawnCEG
local spDestroyUnit = Spring.DestroyUnit
local spGetUnitPosition = Spring.GetUnitPosition
local DISTANCE_LIMIT = math.max(Game.mapSizeX,Game.mapSizeZ) * math.max(Game.mapSizeX,Game.mapSizeZ)
local destroyUnitQueue = {}

local function getSqrDistance(x1,z1,x2,z2)
	local dx, dz = x1-x2, z1-z2
	return (dx*dx) + (dz*dz)
end

local function wipeoutTeam(teamID, originX, originZ, attackerUnitID)
	originX = originX or 0
	originZ = originZ or 0
	local gf = Spring.GetGameFrame()
	local maxDeathFrame = 0
	local teamUnits = Spring.GetTeamUnits(teamID)
	for i=1, #teamUnits do
		local unitID = teamUnits[i]
		local x,y,z = spGetUnitPosition(unitID)
		local deathFrame = math.floor(math.min(((getSqrDistance(x, z, originX, originZ) / DISTANCE_LIMIT) * wavePeriod/2), wavePeriod) + math.random(0,wavePeriod/3))
		maxDeathFrame = math.max(maxDeathFrame, deathFrame)
		if destroyUnitQueue[unitID] == nil then
			destroyUnitQueue[unitID] = {
				frame = gf + deathFrame,
				attackerUnitID = attackerUnitID,
				--x = x, y = y, z = z,
			}
		end
	end
	GG.maxDeathFrame = GG.maxDeathFrame and math.max(GG.maxDeathFrame, maxDeathFrame) or maxDeathFrame	-- storing frame of total unit wipeout
end

GG.wipeoutTeam = wipeoutTeam
GG.wipeoutPeriod = math.floor(wavePeriod*1.25)


function gadget:GameFrame(gf)
	if next(destroyUnitQueue) then
		for unitID, defs in pairs(destroyUnitQueue) do
			--if dt > defs.frame - 15 and not defs.spark then
			--	spSpawnCEG("DEATH_WAVE_SPARKS",defs.x,defs.y,defs.z,0,0,0)
			--	destroyUnitQueue[unitID].spark = true
			--end
			if gf > defs.frame then
                if defs.attackerUnitID then
					spDestroyUnit(unitID, true, nil, defs.attackerUnitID)
				else
					spDestroyUnit(unitID, true) -- if 4th arg is given, it cannot be nil (or engine complains)
                end
				destroyUnitQueue[unitID] = nil
			end
		end
	end
end
