function gadget:GetInfo()
	return {
		name = "Stun Storage",
		desc = "Makes stunned storage drop capactiy",
		author = "Nixtux, Floris",
		date = "June 15, 2014",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local storageDefs = {}
local isCommander = {}
for udid, ud in pairs(UnitDefs) do
	if ud.metalStorage >= 50 then
		if not storageDefs[udid] then
			storageDefs[udid] = {}
		end
		storageDefs[udid].metal = ud.metalStorage
	end
	if ud.energyStorage >= 100 then
		if not storageDefs[udid] then
			storageDefs[udid] = {}
		end
		storageDefs[udid].energy = ud.energyStorage
	end
	if ud.customParams.iscommander then
		isCommander[udid] = true
	end
end

local storageUnits = {}

local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spGetUnitDefID = Spring.GetUnitDefID

function gadget:GameFrame(n)
	for unitID, _ in pairs(storageUnits) do
		local unitDefID = spGetUnitDefID(unitID)
		if not unitDefID then
			break
		end

		if not isCommander[unitDefID] or n > 150 then	-- workaround to prevent commander-gate paralyze effect to rob you of half your starting resources

			local isStunned = spGetUnitIsStunned(unitID)

			-- when freshly EMP'd: reduce total storage
			if not storageUnits[unitID].stunned and isStunned then
				storageUnits[unitID].stunned = true

				local teamID = Spring.GetUnitTeam(unitID)
				if storageDefs[spGetUnitDefID(unitID)].metal then
					local _, totalStorage = Spring.GetTeamResources(teamID, "metal")
					local newStorageTotal = totalStorage - storageUnits[unitID].metal
					Spring.SetTeamResource(teamID, "ms", newStorageTotal)
				end
				if storageDefs[spGetUnitDefID(unitID)].energy then
					local _, totalStorage = Spring.GetTeamResources(teamID, "energy")
					local newStorageTotal = totalStorage - storageUnits[unitID].energy
					Spring.SetTeamResource(teamID, "es", newStorageTotal)
				end

				-- when EMP ran out: restore total storage
			elseif storageUnits[unitID].stunned and not isStunned then
				if storageDefs[spGetUnitDefID(unitID)].metal then
					local _, totalStorage = Spring.GetTeamResources(Spring.GetUnitTeam(unitID), "metal")
					Spring.SetTeamResource(Spring.GetUnitTeam(unitID), "ms", totalStorage + storageUnits[unitID].metal)
					storageUnits[unitID].stunned = false
				end
				if storageDefs[spGetUnitDefID(unitID)].energy then
					local _, totalStorage = Spring.GetTeamResources(Spring.GetUnitTeam(unitID), "energy")
					Spring.SetTeamResource(Spring.GetUnitTeam(unitID), "es", totalStorage + storageUnits[unitID].energy)
					storageUnits[unitID].stunned = false
				end
			end
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if storageDefs[unitDefID] then
		storageUnits[unitID] = {
			stunned = false,
			metal = storageDefs[unitDefID].metal,
			energy = storageDefs[unitDefID].energy,
		}
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if storageUnits[unitID] and storageUnits[unitID].stunned then
		if storageUnits[unitID].metal then
			local _, totalStorage = Spring.GetTeamResources(oldTeam, "metal")
			Spring.SetTeamResource(oldTeam, "ms", totalStorage + storageUnits[unitID].metal)
			_, totalStorage = Spring.GetTeamResources(newTeam, "metal")
			Spring.SetTeamResource(newTeam, "ms", totalStorage - storageUnits[unitID].metal)
		end
		if storageUnits[unitID].energy then
			local _, totalStorage = Spring.GetTeamResources(oldTeam, "energy")
			Spring.SetTeamResource(oldTeam, "es", totalStorage + storageUnits[unitID].energy)
			_, totalStorage = Spring.GetTeamResources(newTeam, "energy")
			Spring.SetTeamResource(newTeam, "es", totalStorage - storageUnits[unitID].energy)
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if storageUnits[unitID] then
		if storageUnits[unitID].stunned then

			-- restore before unit is destroyed
			if storageUnits[unitID].metal then
				local _, totalStorage = Spring.GetTeamResources(unitTeam, "metal")
				Spring.SetTeamResource(unitTeam, "ms", totalStorage + storageUnits[unitID].metal)
			end
			if storageUnits[unitID].energy then
				local _, totalStorage = Spring.GetTeamResources(unitTeam, "energy")
				Spring.SetTeamResource(unitTeam, "es", totalStorage + storageUnits[unitID].energy)
			end
		end
		storageUnits[unitID] = nil
	end
end

function gadget:Initialize()
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		if select(5, Spring.GetUnitHealth(unitID)) == 1 then
			gadget:UnitFinished(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
			if storageUnits[unitID] and spGetUnitIsStunned(unitID) then
				storageUnits[unitID].stunned = true
			end
		end
	end
end
