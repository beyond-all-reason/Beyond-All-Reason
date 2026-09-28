local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Holdfire Fix",
		desc = "Hold fire drops automatic targets immediately",
		author = "efrec",
		date = "2026-09-28",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local spGetUnitStates = Spring.GetUnitStates
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local spUnitFinishCommand = Spring.UnitFinishCommand
local spUnitWeaponHoldFire = Spring.UnitWeaponHoldFire

local bit_and = math.bit_and
local next = next

local CMD_ATTACK = CMD.ATTACK
local CMD_FIRE_STATE = CMD.FIRE_STATE
local FIRESTATE_HOLDFIRE = CMD.FIRESTATE_HOLDFIRE
local OPT_INTERNAL = CMD.OPT_INTERNAL
local TARGET_INTERCEPT = 3

local issuesAttack = {
	-- [CMD.FIGHT] = true, -- Drop Fight anyway because it should respect Hold Fire.
	[CMD.AREA_ATTACK] = true,
	[GameCMD.AREA_ATTACK_GROUND] = true,
}

local weaponCount = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canFireControl and #unitDef.weapons > 0 then
		weaponCount[unitDefID] = #unitDef.weapons
	end
end

local holdFireUnits = {}

local function isAutomatic(cmdOptions)
	return bit_and(cmdOptions, OPT_INTERNAL) ~= 0
end

local function dropAutomaticAttack(unitID)
	local cmdID, options = spGetUnitCurrentCommand(unitID)
	if cmdID ~= CMD_ATTACK or not isAutomatic(options) then
		return
	end
	local nextCommand, nextOptions = spGetUnitCurrentCommand(unitID, 2)
	if issuesAttack[nextCommand] and not isAutomatic(nextOptions) then
		return
	end
	spUnitFinishCommand(unitID)
end

local function dropAutomaticWeaponTargets(unitID, count)
	for weaponNum = 1, count do
		local targetType, isUserTarget = spGetUnitWeaponTarget(unitID, weaponNum)
		if isUserTarget == false and targetType ~= TARGET_INTERCEPT then
			spUnitWeaponHoldFire(unitID, weaponNum)
		end
	end
end

function gadget:GameFrame(frame)
	if next(holdFireUnits) == nil then
		return
	end
	local units = holdFireUnits
	holdFireUnits = {}
	-- New automatic attacks are not generated yet since last frame's command check.
	for unitID, count in pairs(units) do
		if spGetUnitStates(unitID, false) == FIRESTATE_HOLDFIRE then
			dropAutomaticAttack(unitID)
			dropAutomaticWeaponTargets(unitID, count)
		end
	end
end

function gadget:UnitDestroyed(unitID)
	holdFireUnits[unitID] = nil
end

function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams)
	if cmdID == CMD_FIRE_STATE and cmdParams[1] == FIRESTATE_HOLDFIRE and weaponCount[unitDefID] then
		-- The new fire state is applied after this call-in returns. We can check the old state:
		if spGetUnitStates(unitID, false) > FIRESTATE_HOLDFIRE then
			holdFireUnits[unitID] = weaponCount[unitDefID]
		end
	end
end
