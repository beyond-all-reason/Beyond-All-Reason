local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Death Animations",
		desc = "Prevent moving of Dying units",
		author = "Beherith",
		date = "2020",
		license = "GNU GPL, v2 or later",
		layer = 1000,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local spSetUnitBlocking = Spring.SetUnitBlocking
local spSetUnitIconDraw = Spring.SetUnitIconDraw
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spMoveCtrlEnable = Spring.MoveCtrl.Enable
local spMoveCtrlDisable = Spring.MoveCtrl.Disable
local spMoveCtrlSetVelocity = Spring.MoveCtrl.SetVelocity
local hasDeathAnim = {}
for udid, ud in pairs(UnitDefs) do
	-- almost all raptors have dying anims
	if ud.customParams.hasdeathanimation or ud.customParams.israptor then
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
		spSetUnitBlocking(unitID, false) -- non blocking while dying
		spSetUnitIconDraw(unitID, false) -- dont draw icons
		spGiveOrderToUnit(unitID, CMD_STOP, 0, 0)
		spMoveCtrlEnable(unitID)
		spMoveCtrlSetVelocity(unitID, 0, 0, 0)
		dyingUnits[unitID] = true
	end
end

-- do not allow dying units to be moved
function gadget:AllowCommand(
	unitID,
	unitDefID,
	teamID,
	cmdID,
	cmdParams,
	cmdOptions,
	cmdTag,
	playerID,
	fromSynced,
	fromLua
)
	return dyingUnits[unitID] and false or true
end

function gadget:RenderUnitDestroyed(unitID, unitDefID, unitTeam) --called when killed anim finishes
	if dyingUnits[unitID] then
		spMoveCtrlDisable(unitID) -- just in case, not sure if it's needed
		dyingUnits[unitID] = nil
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if dyingUnits[unitID] then
		dyingUnits[unitID] = nil -- for unitID reuse, just in case
	end
end
