local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Air Transports Speed",
		desc = "Slows down transport depending on loaded mass",
		author = "raaar, Hornet",--added com mod 13/06/24
		date = "2015",
		license = "PD",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local TRANSPORTED_MASS_SPEED_PENALTY = 0.2 -- higher makes unit slower
local FRAMES_PER_SECOND = Game.gameSpeed

local airTransports = {}
local airTransportMaxSpeeds = {}

local canFly = {}
local unitMass = {}
local unitTransportMass = {}
local unitSpeed = {}
local unitSpeedPenalty = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canFly then
		canFly[unitDefID] = true
		unitTransportMass[unitDefID] = unitDef.transportMass
	end
	unitMass[unitDefID] = unitDef.mass
	unitSpeed[unitDefID] = unitDef.speed
	unitSpeedPenalty[unitDefID] = tonumber(unitDef.customParams.transportspeedmult or 0) or 0
end

local spGetUnitVelocity = Spring.GetUnitVelocity
local spSetUnitVelocity = Spring.SetUnitVelocity
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting

-- update allowed speed for transport
local function updateAllowedSpeed(transportId)
	local uDefID = spGetUnitDefID(transportId)
	local units = spGetUnitIsTransporting(transportId) or {}

	local transportspeedmult = 0
	local currentMassUsage = 0

	for _,tUnitId in pairs(units) do
		local tunitdefid = spGetUnitDefID(tUnitId)
		transportspeedmult = transportspeedmult + unitSpeedPenalty[tunitdefid]
		currentMassUsage = currentMassUsage + unitMass[tunitdefid]
	end

	local massUsageFraction = (currentMassUsage / unitTransportMass[uDefID])
	local massSpeedPenalty = massUsageFraction * (TRANSPORTED_MASS_SPEED_PENALTY + transportspeedmult)

	airTransportMaxSpeeds[transportId] = unitSpeed[uDefID] * (1 - massSpeedPenalty) / FRAMES_PER_SECOND
end

-- add transports to table when they load a unit
function gadget:UnitLoaded(unitId, unitDefId, unitTeam, transportId, transportTeam)
	if canFly[spGetUnitDefID(transportId)] and not airTransports[transportId] then
		airTransports[transportId] = true
		updateAllowedSpeed(transportId)
	end
end

-- cleanup transports and unloaded unit tables when destroyed
function gadget:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId)
	airTransports[unitId] = nil
	airTransportMaxSpeeds[unitId] = nil
end

-- every frame, adjust speed of air transports according to transported mass, if any
function gadget:GameFrame(n)

	-- for each air transport with units loaded, reduce speed if currently greater than allowed
	local factor = 1
	local vx,vy,vz,vw = 0
	local alSpeed = 0
	for unitId,_ in pairs(airTransports) do
		vx,vy,vz,vw = spGetUnitVelocity(unitId)
		alSpeed = airTransportMaxSpeeds[unitId]
		if alSpeed and vw and vw > alSpeed then
			factor = alSpeed / vw
			spSetUnitVelocity(unitId,vx * factor,vy * factor,vz * factor)
		end
	end
end


function gadget:UnitUnloaded(unitId, unitDefId, teamId, transportId)
	if airTransports[transportId] then
		updateAllowedSpeed(transportId)

		local units = spGetUnitIsTransporting(transportId)

		if not units or not units[1] then
			airTransports[transportId] = nil
			airTransportMaxSpeeds[transportId] = nil
		end
	end
end
