local gadget = gadget ---@type Gadget

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

local units = {
	corkarg = true,
	corthud = true,
	corstorm = true,
	corsumo = true,
	armraz = true,
	armpw = true,
	armck = true,
	armrectr = true,
	armrock = true,
	armfast = true,
	armzeus = true,
	armfido = true,
	armham = true,
	corak = true,
	corck = true,
}
local unitsCopy = table.copy(units)
for name,v in pairs(unitsCopy) do
	units[name..'_scav'] = true
end
local hasDeathAnim = {}
for udid, ud in pairs(UnitDefs) do
	if units[ud.name] then
		hasDeathAnim[udid] = true
	end
	-- almost all raptors have dying anims
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
    	Spring.SetUnitBlocking(unitID,false) -- non blocking while dying
		Spring.SetUnitIconDraw(unitID, false) -- dont draw icons
		Spring.GiveOrderToUnit(unitID, CMD_STOP, 0, 0)
		Spring.MoveCtrl.Enable(unitID)
		Spring.MoveCtrl.SetVelocity(unitID, 0, 0, 0)
    	dyingUnits[unitID] = true
	end
end

 -- do not allow dying units to be moved
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	return dyingUnits[unitID] and false or true
end

function gadget:RenderUnitDestroyed(unitID, unitDefID, unitTeam) --called when killed anim finishes
	if dyingUnits[unitID] then
		Spring.MoveCtrl.Disable(unitID) -- just in case, not sure if it's needed
		dyingUnits[unitID] = nil
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if dyingUnits[unitID] then
		dyingUnits[unitID] = nil -- for unitID reuse, just in case
	end
end
