local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Air Transport Speed Penalty",
		desc    = "Reduces air transport speed given custom speed penalties",
		author  = "raaar, Hornet",
		date    = "2015",
		license = "PD",
		layer   = 0,
		enabled = true, -- auto-disables
	}
end

-- 2026 efrec
-- Mass-based transport speed penalties are effectively broken beyond repair, at the moment.
-- So the previous gadget by raaar, revised by Hornet, contained code that no longer worked.

if not gadgetHandler:IsSyncedCode() then
	return
end

local math_max = math.max

local spGetUnitVelocity = Spring.GetUnitVelocity
local spSetUnitVelocity = Spring.SetUnitVelocity
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting

local isAirTransport = {}
local unitSpeedMax = {}
local unitPenalty = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.isAirUnit and unitDef.isTransport then
		isAirTransport[unitDefID] = true
		unitSpeedMax[unitDefID] = unitDef.speed / Game.gameSpeed
	end
	unitPenalty[unitDefID] = math.clamp(tonumber(unitDef.customParams.transportspeedpenalty or 0) or 0, 0, 1)
end

if not table.any(unitPenalty, function(value) return value > 0 end) then
	return false
end

local unitCurrentSpeed = {}

local function updateAllowedSpeed(transporterID)
	local maxSpeedPenalty = 0
	for _, transporteeID in pairs(spGetUnitIsTransporting(transporterID) or {}) do
		maxSpeedPenalty = math_max(maxSpeedPenalty, unitPenalty[spGetUnitDefID(transporteeID)])
	end
	unitCurrentSpeed[transporterID] = unitSpeedMax[spGetUnitDefID(transporterID)] * (1 - maxSpeedPenalty)
end

function gadget:GameFrame(frame)
	for unitID, speedMax in pairs(unitCurrentSpeed) do
		local vx, vy, vz, speed = spGetUnitVelocity(unitID)
		if (speed or 0) > speedMax then
			local factor = speedMax / speed
			spSetUnitVelocity(unitID, vx * factor, vy * factor, vz * factor)
		end
	end
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if isAirTransport[spGetUnitDefID(transportID)] then
		updateAllowedSpeed(transportID)
	end
end

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID, transportTeam)
	if isAirTransport[spGetUnitDefID(transportID)] then
		local units = spGetUnitIsTransporting(transportID)
		if units and units[1] then
			updateAllowedSpeed(transportID)
		else
			unitCurrentSpeed[transportID] = nil
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeam, weaponDefID)
	unitCurrentSpeed[unitID] = nil
end
