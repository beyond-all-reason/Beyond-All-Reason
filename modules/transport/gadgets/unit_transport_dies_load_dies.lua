if not gadgetHandler:IsSyncedCode() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "transport_dies_load_dies",
		desc = "kills units in transports when transports dies (except commandos, lootboxes, scavengerbeacons and hats)",
		author = "knorke, bluestone, icexuick, beherith",
		date = "Dec 2012",
		license = "GNU GPL, v2 or later, horses",
		layer = 0,
		enabled = true,
	}
end

local isParatrooper = {}

for udid, ud in pairs(UnitDefs) do
	if ud.customParams.paratrooper or ud.customParams.subfolder == "other/hats" then
		isParatrooper[udid] = true
	end
end

local maybeDead = {}

local function isDeadOrCrashing(unitID)
	return Spring.GetUnitIsDead(unitID) ~= false or Spring.GetUnitMoveTypeData(unitID).aircraftState == "crashing"
end

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	if Spring.GetUnitRulesParam(unitID, "unit_effigy") then
		return
	end

	if isParatrooper[unitDefID] then
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
		return
	end

	maybeDead[unitID] = transportID
end

function gadget:GameFramePost(gameFrame)
	if not next(maybeDead) then
		return
	end

	for unitID, transportID in pairs(maybeDead) do
		if isDeadOrCrashing(transportID) and not isDeadOrCrashing(unitID) then
			Spring.UnitDetach(unitID)
			Spring.AddUnitDamage(unitID, 1e6, nil, nil, Game.envDamageTypes.TransportKilled)
		end
	end

	maybeDead = {}
end
