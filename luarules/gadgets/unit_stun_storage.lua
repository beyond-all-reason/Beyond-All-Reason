local gadget = gadget ---@type Gadget

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

local spGetTeamResources = Spring.GetTeamResources
local spSetTeamResource = Spring.SetTeamResource

local paralyzedUnits = {}

local storageDefs = {}
local isCommander = {}
for udid, ud in pairs(UnitDefs) do
	if not ud.canMove then	-- this is to exclude transportable units since they get stunned while being transported

		-- instead of checking every unit to see if it is a commander we add them in late, except we don't cause they move
		-- i don't understand our decision making but i'm future proofing this
		-- commanders were tested to be excluded for the first 150 game frames
		-- well re-add them if they ever get stationarty to the list of storage units 150 frames in late instead, to lower amount of checks
		if ud.customParams.iscommander then
			isCommander[udid] = true
		else

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
	end
end

local function restoreStorage(unitID, unitDefID, teamID)
	if storageDefs[unitDefID].metal then
		local _, totalStorage = spGetTeamResources(teamID, "metal")
		spSetTeamResource(teamID, "ms", totalStorage + storageDefs[unitDefID].metal)
	end
	if storageDefs[unitDefID].energy then
		local _, totalStorage = spGetTeamResources(teamID, "energy")
		spSetTeamResource(teamID, "es", totalStorage + storageDefs[unitDefID].energy)
	end
	paralyzedUnits[unitID] = nil
end

local function reduceStorage(unitID, unitDefID, teamID)
	paralyzedUnits[unitID] = unitDefID
	if storageDefs[unitDefID].metal then
		local _, totalStorage = spGetTeamResources(teamID, "metal")
		spSetTeamResource(teamID, "ms", totalStorage - storageDefs[unitDefID].metal)
	end
	if storageDefs[unitDefID].energy then
		local _, totalStorage = spGetTeamResources(teamID, "energy")
		spSetTeamResource(teamID, "es", totalStorage - storageDefs[unitDefID].energy)
	end
end

if #isCommander > 0 then
	function gadget:GameFrame(n)
		if n > 150 then
			for commander, _ in pairs(isCommander) do
				if UnitDefs[commander].metalStorage >= 50 then
					storageDefs[udid].metal = UnitDefs[commander].metalStorage
				end
				if UnitDefs[commander].energyStorage >= 100 then
					storageDefs[udid].energy = UnitDefs[commander].energyStorage
				end
			end
			isCommander = nil
			gadgetHandler:RemoveCallIn("GameFrame")
		end
	end
else
	isCommander = nil
end

function gadget:UnitStunned(unitID, unitDefID, teamID, stunned)
	if not storageDefs[unitDefID] then
		return
	end

	if stunned then
		if not paralyzedUnits[unitID] then
			local beingBuilt, _ = Spring.GetUnitIsBeingBuilt(unitID)
			if not beingBuilt then
				reduceStorage(unitID, unitDefID, teamID)
			end
		end
	else
		if paralyzedUnits[unitID] then
			restoreStorage(unitID, unitDefID, teamID)
		end
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if paralyzedUnits[unitID] then
		restoreStorage(unitID, unitDefID, oldTeam)
		reduceStorage(unitID, unitDefID, newTeam)
	end
end

--function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
--	gadget:UnitGiven(unitID, unitDefID, newTeam, unitTeam)
--end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if storageDefs[unitDefID] then
		local _, maxHealth, paralyzeDamage, _, _ = Spring.GetUnitHealth(unitID)
		if paralyzeDamage > maxHealth then
			reduceStorage(unitID, unitDefID, unitTeam)
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if paralyzedUnits[unitID] then
		restoreStorage(unitID, unitDefID, unitTeam)
	end
end

function gadget:Initialize()
	local allUnits = Spring.GetAllUnits()

	if #allUnits == 0 then
		return
	end

	local spGetUnitIsStunned = Spring.GetUnitIsStunned
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		if select(5, Spring.GetUnitHealth(unitID)) == 1 then
			local unitDefID = Spring.GetUnitDefID(unitID)
			if storageDefs[unitDefID] and spGetUnitIsStunned(unitID) then
				reduceStorage(unitID, unitDefID, Spring.GetUnitTeam(unitID))
			end
		end
	end
end

function gadget:Shutdown()
	local spGetUnitIsStunned = Spring.GetUnitIsStunned
	for unitID, unitDefID in pairs(paralyzedUnits) do
		if spGetUnitIsStunned(unitID) then
			restoreStorage(unitID, unitDefID, Spring.GetUnitTeam(unitID))
		end
	end
end
