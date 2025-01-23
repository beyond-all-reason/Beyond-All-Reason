function gadget:GetInfo()
	return {
		name      = "Death Animations",
		desc      = "Prevent moving of Dying units",
		author    = "Beherith",
		date      = "2020",
		license   = "GNU GPL, v2 or later",
		layer     = 1000,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local hasDeathAnim = {
	[UnitDefNames.corkarg.id] = true,
	[UnitDefNames.corthud.id] = true,
	[UnitDefNames.corstorm.id] = true,
	[UnitDefNames.corsumo.id] = true,
	[UnitDefNames.armraz.id] = true,
	[UnitDefNames.armpw.id] = true,
	[UnitDefNames.armck.id] = true,
	[UnitDefNames.armrectr.id] = true,
	[UnitDefNames.armrock.id] = true,
	[UnitDefNames.armfast.id] = true,
	[UnitDefNames.armzeus.id] = true,
	[UnitDefNames.armfido.id] = true,
	[UnitDefNames.armham.id] = true,
	[UnitDefNames.corak.id] = true,
	[UnitDefNames.corck.id] = true,
}

for udid, ud in pairs(UnitDefs) do --almost all raptors have dying anims
	if string.find(ud.name, "raptor") or (ud.customParams.subfolder and ud.customParams.subfolder == "other/raptors") then
		hasDeathAnim[udid] = true
	end
end

local dyingUnits = {}
local CMD_STOP = CMD.STOP

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.ANY)
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if hasDeathAnim[unitDefID] then
		--Spring.Echo("gadget:UnitDestroyed",unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
    	Spring.SetUnitBlocking(unitID,false) -- non blocking while dying
		Spring.UnitIconSetDraw(unitID, false) -- dont draw icons
		Spring.GiveOrderToUnit(unitID, CMD_STOP, 0, 0)
		Spring.MoveCtrl.Enable(unitID)
		Spring.MoveCtrl.SetVelocity(unitID, 0, 0, 0)
    	dyingUnits[unitID] = true
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua) -- do not allow dying units to be moved
	return dyingUnits[unitID] and false or true
end

function gadget:RenderUnitDestroyed(unitID, unitDefID, unitTeam) --called when killed anim finishes
	if dyingUnits[unitID] then
		Spring.MoveCtrl.Disable(unitID) -- just in case, not sure if it's needed
		dyingUnits[unitID] = nil
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID) -- for unitID reuse, just in case
	if dyingUnits[unitID] then
		dyingUnits[unitID] = nil
	end
end
