--in BAR "commando" unit always survives being shot down during transport
--when a com dies in mid air the damage done is controlled by unit_combomb_full_damage

--several other ways to code this do not work because:
--when UnitDestroyed() is called, Spring.GetUnitIsTransporting is already empty -> meh
--checking newDamage>health in UnitDamaged() does not work because UnitDamaged() does not trigger on selfdestruct -> meh
--with releaseHeld, on death of a transport UnitUnload is called before UnitDestroyed
--when UnitUnloaded is called due to transport death, Spring.GetUnitIsDead (transportID) is still false
--when trans is self d'ed, on the frame it dies it has both Spring.GetUnitHealth(ID)>0 and Spring.UnitSelfDTime(ID)=0
--when trans is crashing it isn't dead

if not gadgetHandler:IsSyncedCode() then return end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "transport_dies_load_dies",
		desc      = "kills units in transports when transports dies (except commandos, lootboxes, scavengerbeacons and hats)",
		author    = "knorke, bluestone, icexuick, beherith",
		date      = "Dec 2012",
		license   = "GNU GPL, v2 or later, horses",
		layer     = 0,
		enabled   = true
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
	return Spring.GetUnitIsDead(unitID) ~= false
		or Spring.GetUnitMoveTypeData(unitID).aircraftState == "crashing"
end

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	if Spring.GetUnitRulesParam(unitID, "unit_effigy") then
		--don't destroy units with effigies. Spring.SetUnitPosition cannot move a unit mid-fall.
		return
	end

	if isParatrooper[unitDefID] then
		--commandos are given a move order to the location of the ground below where the transport died; remove it
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
		return
	end

	-- Transports unload their units when they die, but it is annoying to detect when the unit is dead/destroyed.
	-- We mark transportees as maybe-dead and check whether they are or not later after the end-of-frame cleanup.
	maybeDead[unitID] = transportID
end

function gadget:GameFramePost(gameFrame)
	if not next(maybeDead) then
		return
	end

	for unitID, transportID in pairs(maybeDead) do
		if isDeadOrCrashing(transportID) and not isDeadOrCrashing(unitID) then
			Spring.UnitDetach(unitID) -- secret sauce
			Spring.AddUnitDamage(unitID, 1e6, nil, nil, Game.envDamageTypes.TransportKilled) -- TODO: attackerID
		end
	end

	maybeDead = {}
end
