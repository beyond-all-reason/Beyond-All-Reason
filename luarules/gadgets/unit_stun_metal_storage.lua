function gadget:GetInfo()
	return {
		name = "Stun Metal Storage",
		desc = "Makes stunned storage drop capactiy",
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
	[UnitDefNames.armmstor.id] = true,
	[UnitDefNames.armuwms.id] = true,
	[UnitDefNames.armuwadvms.id] = true,

	[UnitDefNames.cormstor.id] = true,
	[UnitDefNames.coruwms.id] = true,
	[UnitDefNames.coruwadvms.id] = true,
}
for udid, ud in pairs(UnitDefs) do
	for id, v in pairs(storageDefs) do
		if string.find(ud.name, UnitDefs[id].name) and ud.height ~= nil then
			storageDefs[udid] = {ud.metalStorage, ud.height}
		end
	end
end

local storageunits = {}
local stunnedstorage = {}

local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spGetUnitDefID = Spring.GetUnitDefID

function gadget:GameFrame(n)
	if ((n + 18) % 30) < 0.1 then
		for unitID, _ in pairs(storageunits) do
			if not spGetUnitDefID(unitID) then
				break
			end
			if not storageunits[unitID].isEMPed and spGetUnitIsStunned(unitID)then
				local currentLevel, totalstorage = Spring.GetTeamResources(Spring.GetUnitTeam(unitID), "metal")
				local newstoragetotal = totalstorage - storageunits[unitID].storage
				Spring.SetTeamResource(Spring.GetUnitTeam(unitID), "ms", newstoragetotal)
				if currentLevel > newstoragetotal then
					local x, y, z = Spring.GetUnitPosition(unitID)
					local height = storageunits[unitID].height * 0.70
					Spring.SpawnCEG("METAL_STORAGE_LEAK", x, y + height, z, 0, 0, 0)
				end
				storageunits[unitID].isEMPed = true
				stunnedstorage[unitID] = true
			end
		end
		for unitID, _ in pairs(stunnedstorage) do
			local team = Spring.GetUnitTeam(unitID)
			if team ~= nil and not spGetUnitIsStunned(unitID) then
				local _, totalstorage = Spring.GetTeamResources(team, "metal")
				Spring.SetTeamResource(Spring.GetUnitTeam(unitID), "ms", totalstorage + storageunits[unitID].storage)
				stunnedstorage[unitID] = nil
				storageunits[unitID].isEMPed = false
			end
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if storageDefs[unitDefID] then
		storageunits[unitID] = {
			isEMPed = false,
			storage = storageDefs[unitDefID][1],
			height = storageDefs[unitDefID][2],
		}
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if storageunits[unitID] and storageunits[unitID].isEMPed then
		local _, totalstorage = Spring.GetTeamResources(oldTeam, "metal")
		Spring.SetTeamResource(oldTeam, "ms", totalstorage + storageunits[unitID].storage)
		_, totalstorage = Spring.GetTeamResources(newTeam, "metal")
		Spring.SetTeamResource(newTeam, "ms", totalstorage - storageunits[unitID].storage)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if stunnedstorage[unitID] then
		if storageunits[unitID] and storageunits[unitID].isEMPed then
			local _, totalstorage = Spring.GetTeamResources(unitTeam, "metal")
			Spring.SetTeamResource(unitTeam, "ms", totalstorage + storageunits[unitID].storage) --Add back before unit is destoryed
		end
		stunnedstorage[unitID] = nil
		storageunits[unitID] = nil
	end
end
