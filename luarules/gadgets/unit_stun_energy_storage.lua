-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name = "Stun Energy Storage",
		desc = "Makes stunned storage leak/use energy",
		author = "Nixtux",
		date = "June 15, 2014",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true  --  loaded by default?
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local storageDefs = {
	--Armada
	[UnitDefNames.armestor.id] = true,
	[UnitDefNames.armuwadves.id] = true,
	[UnitDefNames.armuwes.id] = true,
	--Cortex
	[UnitDefNames.corestor.id] = true,
	[UnitDefNames.coruwadves.id] = true,
	[UnitDefNames.coruwes.id] = true,
}
for udid, ud in pairs(UnitDefs) do
	for id, v in pairs(storageDefs) do
		if string.find(ud.name, UnitDefs[id].name) then
			storageDefs[udid] = { ud.energyStorage, ud.height }
		end
	end
end

local storageunits = {}

local pairs = pairs
local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spUseTeamResource = Spring.UseTeamResource
local spSpawnCEG = Spring.SpawnCEG

function gadget:GameFrame(n)
	if ((n + 18) % 30) < 0.1 then
		for unitID, _ in pairs(storageunits) do
			if spGetUnitIsStunned(unitID) then
				--Spring.Echo(unitID .. " is stunned  " ..storageunits[unitID].storagecap,penality,storageunits[unitID].height)
				local team = spGetUnitTeam(unitID)
				if team ~= nil then
					local penality = storageunits[unitID].storagecap * 0.01 -- work's out 60e per second for t1 storage and 400e per second for t2 storage
					local x, y, z = spGetUnitPosition(unitID)
					local height = storageunits[unitID].height * 0.40
					spSpawnCEG("ENERGY_STORAGE_LEAK", x, y + height, z, 0, 0, 0)
					spUseTeamResource(team, "energy", penality)
				end
			end
		end
	end
end

local function SetupUnit(unitID, unitDefID)
	storageunits[unitID] = {
		storagecap = storageDefs[unitDefID][1],
		height = storageDefs[unitDefID][2],
	}
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if storageDefs[unitDefID] then
		SetupUnit(unitID, unitDefID)
	end
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam)
	if storageDefs[unitDefID] then
		SetupUnit(unitID, unitDefID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	storageunits[unitID] = nil
end

