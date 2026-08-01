local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Transportee Hider",
		desc = "Hides units when inside a closed transport, issues stop command to units trying to enter a full transport",
		author = "FLOZi",
		date = "09/02/10",
		license = "PD",
		layer = 0,
		enabled = false
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local SetUnitNoDraw = Spring.SetUnitNoDraw
local SetUnitStealth = Spring.SetUnitStealth
local SetUnitSonarStealth = Spring.SetUnitSonarStealth
local GetUnitDefID = Spring.GetUnitDefID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetAllUnits = Spring.GetAllUnits
local GetUnitTeam = Spring.GetUnitTeam

local CMD_LOAD_ONTO = CMD.LOAD_ONTO
local CMD_STOP = CMD.STOP

local massLeft = {}
local toBeLoaded = {}

local unitTransportMass = {}
local unitTransportVtol = {}
local unitMass = {}
local isTransport = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	unitMass[unitDefID] = unitDef.mass
	unitTransportMass[unitDefID] = unitDef.transportMass
	if not unitDef.modCategories.vtol and not unitDef.customParams.isairbase then
		unitTransportVtol[unitDefID] = true
	end
	if unitDef.isTransport then
		isTransport[unitDefID] = true
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- accepts: CMD.LOAD_ONTO
	local transportID = cmdParams[1]
	toBeLoaded[unitID] = transportID
	return true
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
	if isTransport[unitDefID] then
		massLeft[unitID] = unitTransportMass[unitDefID]
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	massLeft[unitID] = nil
	toBeLoaded[unitID] = nil
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_LOAD_ONTO)
	local allUnits = GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		gadget:UnitCreated(unitID, GetUnitDefID(unitID), GetUnitTeam(unitID))
	end
end

local function TransportIsFull(transportID)
	for unitID, targetTransporterID in pairs(toBeLoaded) do
		if targetTransporterID == transportID then
			GiveOrderToUnit(unitID, CMD_STOP, {}, 0)
			toBeLoaded[unitID] = nil
		end
	end
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	--Spring.Echo("UnitLoaded", unitID, unitDefID, transportID)
	if not unitDefID or not transportID or not massLeft[transportID] then
		return
	end
	massLeft[transportID] = massLeft[transportID] - unitMass[unitDefID]
	if massLeft[transportID] == 0 then
		TransportIsFull(transportID)
	end
	if unitTransportVtol[GetUnitDefID(transportID)] then
		SetUnitNoDraw(unitID, true)
		SetUnitStealth(unitID, true)
		SetUnitSonarStealth(unitID, true)
	end
end

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	--Spring.Echo("UnitUnloaded", unitID, unitDefID, transportID)
	if not unitDefID or not transportID or not massLeft[transportID] then
		return
	end
	massLeft[transportID] = massLeft[transportID] + unitMass[unitDefID]
	if unitTransportVtol[GetUnitDefID(transportID)] then
		SetUnitNoDraw(unitID, false)
		SetUnitStealth(unitID, false)
		SetUnitSonarStealth(unitID, false)
	end
end
