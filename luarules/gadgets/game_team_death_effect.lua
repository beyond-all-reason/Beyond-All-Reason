local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Team Death Effect",
		desc = "blows up a teams units in a gradual/wave like manner",
		author = "Floris", -- original: KDR_11k (David Becker)",
		date = "September 2021",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true
	}
end

-- this gadget wont do: Spring.KillTeam(...)

if not gadgetHandler:IsSyncedCode() then
	return
end

local wavePeriod = 550
GG.wipeoutWithWreckage = false		-- FFA can enable this

local isCommander = {}
local unitDecoration = {}
for udefID,def in ipairs(UnitDefs) do
	if def.customParams.iscommander then
		isCommander[udefID] = true
	end
	if def.customParams.decoration then
		unitDecoration[udefID] = true
	end
end

local spDestroyUnit = Spring.DestroyUnit
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID
local DISTANCE_LIMIT = math.max(Game.mapSizeX,Game.mapSizeZ) * math.max(Game.mapSizeX,Game.mapSizeZ)
local destroyUnitQueue = {}
local wipedoutTeams = {}

local function getSqrDistance(x1,z1,x2,z2)
	local dx, dz = x1-x2, z1-z2
	return (dx*dx) + (dz*dz)
end

local function wipeoutTeam(teamID, originX, originZ, attackerUnitID, periodMult)	-- only teamID is required
	wipedoutTeams[teamID] = Spring.GetGameFrame()
	periodMult = periodMult or 1
	local gf = Spring.GetGameFrame()
	local maxDeathFrame = 0
	local teamUnits = Spring.GetTeamUnits(teamID)
	for i=1, #teamUnits do
		local unitID = teamUnits[i]
		if not unitDecoration[spGetUnitDefID(unitID)] then
			local x,_,z = spGetUnitPosition(unitID)
			local deathFrame
			if originX then
				deathFrame = 6 + math.floor((math.min(((getSqrDistance(x, z, originX, originZ) / DISTANCE_LIMIT) * wavePeriod*0.6), wavePeriod) + math.random(0,wavePeriod/2.5)) * periodMult)
			else
				deathFrame = 6 + math.floor((math.random(1, wavePeriod*0.3) + math.random(0,wavePeriod/2.5)) * periodMult)
			end
			maxDeathFrame = math.max(maxDeathFrame, deathFrame)
			if destroyUnitQueue[unitID] == nil then
				destroyUnitQueue[unitID] = {
					frame = gf + deathFrame,
					attackerUnitID = attackerUnitID,
				}
			end

			-- neutralize units
			Spring.SetUnitNeutral(unitID, true)
			Spring.SetUnitSensorRadius(unitID, 'los', 0)
			Spring.SetUnitSensorRadius(unitID, 'airLos', 0)
			Spring.SetUnitSensorRadius(unitID, 'radar', 0)
			Spring.SetUnitSensorRadius(unitID, 'sonar', 0)
			local i = 0
			for weaponID, _ in pairs(UnitDefs[GetUnitDefID(unitID)].weapons) do
				Spring.UnitWeaponHoldFire(unitID, weaponID)
				i = i + 1
			end
			if i > 0 then
				Spring.SetUnitMaxRange(unitID, 0)
				Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, {0}, 0)
				Spring.SetUnitTarget(unitID, nil)
			end
			--Spring.SetUnitNoMinimap(unitID, true)
		end
	end
	GG.maxDeathFrame = GG.maxDeathFrame and math.max(GG.maxDeathFrame, maxDeathFrame) or maxDeathFrame	-- storing frame of total unit wipeout
end

local function wipeoutAllyTeam(allyTeamID, attackerUnitID, originX, originZ, periodMult)	-- only allyTeamID is required

	-- xmas gadget uses this (to prevent creating xmasballs)
	if not _G.destroyingTeam then _G.destroyingTeam = {} end
	_G.destroyingTeam[allyTeamID] = true

	-- define smaller destruction period when few units
	local totalUnits = 0
	for _, teamID in ipairs(Spring.GetTeamList(allyTeamID)) do
		local units = Spring.GetTeamUnits(teamID)
		totalUnits = totalUnits + #units
	end
	periodMult = (periodMult or 1) * math.clamp(totalUnits / 300, 0.33, 1)	-- make low unitcount blow up faster

	-- destroy all teams
	for _, teamID in ipairs(Spring.GetTeamList(allyTeamID)) do
		wipeoutTeam(teamID, originX, originZ, attackerUnitID, periodMult)
	end
end

GG.wipeoutTeam = wipeoutTeam
GG.wipeoutAllyTeam = wipeoutAllyTeam

function gadget:GameFrame(gf)
	if next(destroyUnitQueue) then
		local selfD = not GG.wipeoutWithWreckage
		for unitID, defs in pairs(destroyUnitQueue) do
			if gf > defs.frame then
                if defs.attackerUnitID then
					spDestroyUnit(unitID, selfD, false, defs.attackerUnitID)
				else
					if selfD and isCommander[spGetUnitDefID(unitID)]  then
						spDestroyUnit(unitID, false, false)	-- always leave commander wreckage (ffa reclaims all on early dropped players now)
					else
						spDestroyUnit(unitID, selfD, false) -- if 4th arg is given, it cannot be nil (or engine complains)
					end
                end
				destroyUnitQueue[unitID] = nil
			end
		end
	end
end

-- i've seen a resurrected unit being left-over so lets remove units being created after a team wipeout was initiated
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if wipedoutTeams[unitTeam] and wipedoutTeams[unitTeam]+300 > Spring.GetGameFrame() then
		Spring.DestroyUnit(unitID, not GG.wipeoutWithWreckage, false)
	end
end
