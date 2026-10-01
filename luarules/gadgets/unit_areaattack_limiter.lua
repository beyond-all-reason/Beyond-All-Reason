local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Area Attack Limiter",
		desc = "Splits large area-form attack commands into targeted attacks to reduce lag from large (air) engagements",
		author = "Floris",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -999999,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return
end

-- Max non-bomber units allowed to use an area-form CMD_ATTACK.
-- Commands expand into units x targets. Consider about 1000 targets.
local AREA_LIMIT = 30
-- Max targeted attack orders issued per area-form CMD_ATTACK.
local COMMAND_LIMIT = 500

local CMD_ATTACK = CMD.ATTACK
local CMD_STOP = CMD.STOP
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local ENEMY_UNITS = Spring.ENEMY_UNITS

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local table_sort = table.sort

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit

local splitRivers = require("modules/split_targets").Rivers

local isBombWeapon = {}
for weaponDefID, weaponDef in pairs(WeaponDefs) do
	if weaponDef.type == "AircraftBomb" then
		isBombWeapon[weaponDefID] = true
	end
end

-- customparams.areaattack_unlimited: must classify identically in
-- cmd_exclude_walls_area_attacks.lua and cmd_bomber_attack_building_ground.lua
local isBomberUnitDef = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if
		(unitDef.weapons and unitDef.weapons[1] and isBombWeapon[unitDef.weapons[1].weaponDef])
		or unitDef.customParams.areaattack_unlimited
	then
		isBomberUnitDef[unitDefID] = true
	end
end

local isReissuing = false

local function sortClosestFirst(unitID, targets)
	local unitX, _, unitZ = spGetUnitPosition(unitID)
	local distances = {}
	for i = 1, #targets do
		local targetID = targets[i]
		local targetX, _, targetZ = spGetUnitPosition(targetID)
		local dx, dz = targetX - unitX, targetZ - unitZ
		distances[targetID] = dx * dx + dz * dz
	end
	table_sort(targets, function(a, b)
		return distances[a] < distances[b]
	end)
end

function gadget:CommandNotify(cmdID, cmdParams, cmdOpts)
	-- Guard against re-entrancy: reissued orders can trigger CommandNotify again
	if isReissuing then
		return
	end

	-- Only intercept area-form CMD_ATTACK commands (4 params: x, y, z, radius).
	-- Engine-native CMD_AREA_ATTACK remains compact and is intentionally not limited.
	if cmdID ~= CMD_ATTACK or #cmdParams ~= 4 or cmdParams[4] <= 0 then
		return
	end

	local selUnits = spGetSelectedUnits()

	-- Only non-bombers are counted against AREA_LIMIT.
	local attackers, bombers = {}, {} ---@type UnitID[], UnitID[]
	for i = 1, #selUnits do
		local unitID = selUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID and isBomberUnitDef[unitDefID] then
			bombers[#bombers + 1] = unitID
		else
			attackers[#attackers + 1] = unitID
		end
	end
	if #attackers <= AREA_LIMIT then
		return
	end

	-- Preserve command options
	local opts = 0
	if cmdOpts.alt then
		opts = opts + CMD.OPT_ALT
	end
	if cmdOpts.ctrl then
		opts = opts + CMD.OPT_CTRL
	end
	if cmdOpts.meta then
		opts = opts + CMD.OPT_META
	end
	if cmdOpts.right then
		opts = opts + CMD.OPT_RIGHT
	end

	local x, z, radius = cmdParams[1], cmdParams[3], cmdParams[4]
	local handled = false

	isReissuing = true
	CallAsTeam(Spring.GetLocalTeamID(), function()
		local targets = spGetUnitsInCylinder(x, z, radius, ENEMY_UNITS)
		if not targets[1] then
			return
		end

		handled = true -- We go back through the normal input pipeline.

		if bombers[1] ~= nil then
			Spring.SelectUnitArray(bombers)
			if not cmdOpts.shift then
				Spring.GiveOrder(CMD_STOP, {}, 0)
			end
			-- FIXME: GiveOrderArrayToUnitArray doesn't reliably deliver area attack commands (4-param CMD_ATTACK).
			Spring.GiveOrder(cmdID, cmdParams, opts + CMD_OPT_SHIFT)
			Spring.SelectUnitArray(selUnits)
		end

		local maxTargetsPerUnit = math_max(math_floor(COMMAND_LIMIT / #attackers), 1)
		local targetsPerUnit = splitRivers(attackers, targets)
		for i = 1, #attackers do
			local unitID = attackers[i]
			local unitTargets = targetsPerUnit[unitID]
			sortClosestFirst(unitID, unitTargets)

			local orders = {}
			if not cmdOpts.shift then
				orders[1] = { CMD_STOP, {}, 0 }
			end
			for j = 1, math_min(#unitTargets, maxTargetsPerUnit) do
				orders[#orders + 1] = { CMD_ATTACK, { unitTargets[j] }, opts + CMD_OPT_SHIFT }
			end
			spGiveOrderArrayToUnit(unitID, orders)
		end
	end)
	isReissuing = false

	return handled
end
