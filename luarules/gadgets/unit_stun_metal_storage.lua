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

local storageDefs = {}
for udid, ud in pairs(UnitDefs) do
	if ud.metalStorage >= 50 then
		storageDefs[udid] = ud.metalStorage
	end
end

local storageunits = {}

local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spGetUnitDefID = Spring.GetUnitDefID

function gadget:GameFrame(n)
	if ((n + 18) % 30) < 0.1 then
		for unitID, _ in pairs(storageunits) do
			if not spGetUnitDefID(unitID) then
				break
			end
			local isStunned = spGetUnitIsStunned(unitID)

			-- when freshly EMP'd: reduce total metal storage
			if not storageunits[unitID].stunned and isStunned then
				local teamID = Spring.GetUnitTeam(unitID)
				local _, totalstorage = Spring.GetTeamResources(teamID, "metal")
				local newstoragetotal = totalstorage - storageunits[unitID].storage
				Spring.SetTeamResource(teamID, "ms", newstoragetotal)
				storageunits[unitID].stunned = true

			-- when EMP ran out: restore total metal storage
			elseif storageunits[unitID].stunned and not isStunned then
				local _, totalstorage = Spring.GetTeamResources(Spring.GetUnitTeam(unitID), "metal")
				Spring.SetTeamResource(Spring.GetUnitTeam(unitID), "ms", totalstorage + storageunits[unitID].storage)
				storageunits[unitID].stunned = false
			end
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if storageDefs[unitDefID] then
		storageunits[unitID] = {
			stunned = false,
			storage = storageDefs[unitDefID],
		}
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if storageunits[unitID] and storageunits[unitID].stunned then
		local _, totalstorage = Spring.GetTeamResources(oldTeam, "metal")
		Spring.SetTeamResource(oldTeam, "ms", totalstorage + storageunits[unitID].storage)
		_, totalstorage = Spring.GetTeamResources(newTeam, "metal")
		Spring.SetTeamResource(newTeam, "ms", totalstorage - storageunits[unitID].storage)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if storageunits[unitID] then
		if storageunits[unitID].stunned then
			local _, totalstorage = Spring.GetTeamResources(unitTeam, "metal")
			Spring.SetTeamResource(unitTeam, "ms", totalstorage + storageunits[unitID].storage) --Add back before unit is destroyed
		end
		storageunits[unitID] = nil
	end
end

function gadget:Initialize()
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		if select(5, Spring.GetUnitHealth(unitID)) == 1 then
			gadget:UnitFinished(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
			if spGetUnitIsStunned(unitID) then
				storageunits[unitID].stunned = true
			end
		end
	end
end
