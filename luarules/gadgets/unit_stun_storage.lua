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

local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spGetTeamResources = Spring.GetTeamResources
local spSetTeamResource = Spring.SetTeamResource

local storageUnits = {}

local storageDefs = {}
local isCommander = {}
for udid, ud in pairs(UnitDefs) do
	if not ud.canMove then	-- this is to exclude transportable units since they get stunned while being transported
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
	end
	if ud.customParams.iscommander then
		isCommander[udid] = true
	end
end


function gadget:GameFrame(n)
	if n % 5 == 1 then
		for unitID, params in pairs(storageUnits) do
			if not isCommander[params.unitDefID] or n > 150 then	-- workaround to prevent commander-gate paralyze effect to rob you of half your starting resources

				local isStunned = spGetUnitIsStunned(unitID)

				-- when freshly EMP'd: reduce total storage
				if not storageUnits[unitID].stunned and isStunned then
					storageUnits[unitID].stunned = true

					if params.metal then
						local _, totalStorage = spGetTeamResources(params.teamID, "metal")
						local newStorageTotal = totalStorage - params.metal
						spSetTeamResource(params.teamID, "ms", newStorageTotal)
					end
					if params.energy then
						local _, totalStorage = spGetTeamResources(params.teamID, "energy")
						local newStorageTotal = totalStorage - params.energy
						spSetTeamResource(params.teamID, "es", newStorageTotal)
					end

					-- when EMP ran out: restore total storage
				elseif storageUnits[unitID].stunned and not isStunned then
					if params.metal then
						local _, totalStorage = spGetTeamResources(params.teamID, "metal")
						spSetTeamResource(params.teamID, "ms", totalStorage + params.metal)
						storageUnits[unitID].stunned = false
					end
					if params.energy then
						local _, totalStorage = spGetTeamResources(params.teamID, "energy")
						spSetTeamResource(params.teamID, "es", totalStorage + params.energy)
						storageUnits[unitID].stunned = false
					end
				end
			end
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if storageDefs[unitDefID] then
		storageUnits[unitID] = {
			unitDefID = unitDefID,
			stunned = false,
			metal = storageDefs[unitDefID].metal,
			energy = storageDefs[unitDefID].energy,
			teamID = unitTeam,
		}
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if storageUnits[unitID] and storageUnits[unitID].stunned then
		if storageUnits[unitID].metal then
			local _, totalStorage = spGetTeamResources(oldTeam, "metal")
			spSetTeamResource(oldTeam, "ms", totalStorage + storageUnits[unitID].metal)
			_, totalStorage = spGetTeamResources(newTeam, "metal")
			spSetTeamResource(newTeam, "ms", totalStorage - storageUnits[unitID].metal)
		end
		if storageUnits[unitID].energy then
			local _, totalStorage = spGetTeamResources(oldTeam, "energy")
			spSetTeamResource(oldTeam, "es", totalStorage + storageUnits[unitID].energy)
			_, totalStorage = spGetTeamResources(newTeam, "energy")
			spSetTeamResource(newTeam, "es", totalStorage - storageUnits[unitID].energy)
		end
		storageDefs[unitDefID].teamID = newTeam
	end
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	gadget:UnitGiven(unitID, unitDefID, newTeam, unitTeam)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if storageUnits[unitID] then
		if storageUnits[unitID].stunned then

			-- restore before unit is destroyed
			if storageUnits[unitID].metal then
				local _, totalStorage = spGetTeamResources(unitTeam, "metal")
				spSetTeamResource(unitTeam, "ms", totalStorage + storageUnits[unitID].metal)
			end
			if storageUnits[unitID].energy then
				local _, totalStorage = spGetTeamResources(unitTeam, "energy")
				spSetTeamResource(unitTeam, "es", totalStorage + storageUnits[unitID].energy)
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
