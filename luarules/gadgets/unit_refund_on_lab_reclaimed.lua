local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Refund on lab reclaimed",
		desc      = "Refunds metal when factory is reclaimed by ally while producing",
		author    = "Pexo",
		date      = "29.03.2026",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitCosts = Spring.GetUnitCosts
local spAddUnitResource = Spring.AddUnitResource
local spAddTeamResource = Spring.AddTeamResource
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead

local reclaimedWeaponDefID = Game.envDamageTypes.Reclaimed

local factoryQueue = {}

local isFactory = {}
for udid = 1, #UnitDefs do
	local ud = UnitDefs[udid]
	if ud.isFactory then
		isFactory[udid] = true
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderID and isFactory[spGetUnitDefID(builderID)] then
		factoryQueue[builderID] = {
			unitID = unitID,
			unitDefID = unitDefID,
		}
	end
end

function gadget:UnitFromFactory(unitID, unitDefID, unitTeam, factoryID)
	factoryQueue[factoryID] = nil
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local queuedData = factoryQueue[unitID]
	if not queuedData then
		return
	end

	local unitBeingBuiltId = queuedData.unitID or queuedData -- backwards compatibility with old numeric queue entries
	local queuedUnitDefID = queuedData.unitDefID

	factoryQueue[unitID] = nil
	if weaponDefID ~= reclaimedWeaponDefID then 
		return
	end

	if not attackerTeam or not spAreTeamsAllied(unitTeam, attackerTeam) then 
		return
	end

	local _, buildProgress = spGetUnitIsBeingBuilt(unitBeingBuiltId)
	if not buildProgress or buildProgress <= 0 then
		return
	end

	local unitDefID = queuedUnitDefID or spGetUnitDefID(unitBeingBuiltId)
	local metalCost
	if unitDefID and UnitDefs[unitDefID] then
		metalCost = UnitDefs[unitDefID].metalCost
	else
		local _, fallbackMetalCost = spGetUnitCosts(unitBeingBuiltId)
		metalCost = fallbackMetalCost
	end

	if not metalCost or metalCost <= 0 then
		return
	end

	local refund = metalCost * buildProgress
	if refund <= 0 then
		return
	end

	if spValidUnitID(unitBeingBuiltId) and not spGetUnitIsDead(unitBeingBuiltId) then
		spAddUnitResource(unitBeingBuiltId, "m", refund)
	else
		spAddTeamResource(unitTeam, "m", refund)
	end
end