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

local paralyzedUnits = {}

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

function gadget:GameFrame(n)
	if n % 5 == 1 then
		for unitID, unitDefID in pairs(paralyzedUnits) do
			if not spGetUnitIsStunned(unitID) then		-- when EMP ran out: restore total storage
				restoreStorage(unitID, unitDefID, Spring.GetUnitTeam(unitID))
			end
		end
	end
end

function gadget:UnitDamaged(unitID, unitDefID, teamID, damage, paralyzer)
	-- when freshly EMP'd: reduce total storage
	if paralyzer and storageDefs[unitDefID] and not paralyzedUnits[unitID] then
		local _, maxHealth, paralyzeDamage, _, _ = Spring.GetUnitHealth(unitID)
		if paralyzeDamage + damage > maxHealth then
			if not isCommander[unitDefID] or Spring.GetGameFrame() > 150 then	-- workaround to prevent commander-gate paralyze effect to rob you of half your starting resources
				reduceStorage(unitID, unitDefID, teamID)
			end
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

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if paralyzedUnits[unitID] then
		restoreStorage(unitID, unitDefID, unitTeam)
	end
end

function gadget:Initialize()
	local allUnits = Spring.GetAllUnits()
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
	for unitID, unitDefID in pairs(paralyzedUnits) do
		if spGetUnitIsStunned(unitID) then
			restoreStorage(unitID, unitDefID, Spring.GetUnitTeam(unitID))
		end
	end
end
