local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Area Attack Limiter",
		desc = "Converts excess area-form attack commands to fight commands to reduce lag from large (air) engagements",
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

local CMD_ATTACK = CMD.ATTACK
local CMD_FIGHT = CMD.FIGHT
local CMD_STOP = CMD.STOP

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGiveOrderArrayToUnitArray = Spring.GiveOrderArrayToUnitArray

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

-- Max non-bomber units allowed to use an area-form CMD_ATTACK.
-- Excess units receive a FIGHT command to the area center instead,
-- which makes them converge and auto-engage without expanding the
-- command into too many target-specific attack orders.
local BATCH_LIMIT = 30

local isReissuing = false

function gadget:CommandNotify(cmdID, cmdParams, cmdOpts)
	-- Guard against re-entrancy: GiveOrderArrayToUnitArray can trigger CommandNotify again
	if isReissuing then
		return
	end

	-- Only intercept area-form CMD_ATTACK commands (4 params: x, y, z, radius).
	-- Engine-native CMD_AREA_ATTACK remains compact and is intentionally not limited.
	if cmdID ~= CMD_ATTACK or #cmdParams ~= 4 or cmdParams[4] <= 0 then
		return
	end

	local selUnits = spGetSelectedUnits()
	local count = #selUnits

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

	local x, y, z = cmdParams[1], cmdParams[2], cmdParams[3]

	-- Split: bombers are always exempt from the batch limit.
	-- Only non-bombers are counted against BATCH_LIMIT.
	local attackUnits = {}
	local fightUnits = {}
	local nonBomberCount = 0
	for i = 1, count do
		local unitID = selUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID and isBomberUnitDef[unitDefID] then
			attackUnits[#attackUnits + 1] = unitID
		else
			nonBomberCount = nonBomberCount + 1
			if nonBomberCount <= BATCH_LIMIT then
				attackUnits[#attackUnits + 1] = unitID
			else
				fightUnits[#fightUnits + 1] = unitID
			end
		end
	end

	-- If no non-bomber exceeded the limit, keep engine default behavior.
	if #fightUnits == 0 then
		return
	end

	-- Use SelectUnitArray + GiveOrder to go through the normal player input
	-- pipeline. GiveOrderArrayToUnitArray doesn't reliably deliver area attack
	-- commands (4-param CMD_ATTACK) to the engine.
	isReissuing = true
	CallAsTeam(Spring.GetLocalTeamID(), function()
		Spring.SelectUnitArray(attackUnits)
		if cmdOpts.shift then
			Spring.GiveOrder(cmdID, cmdParams, opts + CMD.OPT_SHIFT)
		else
			Spring.GiveOrder(CMD_STOP, {}, 0)
			Spring.GiveOrder(cmdID, cmdParams, opts + CMD.OPT_SHIFT)
		end

		Spring.SelectUnitArray(fightUnits)
		if cmdOpts.shift then
			Spring.GiveOrder(CMD_FIGHT, { x, y, z }, opts + CMD.OPT_SHIFT)
		else
			Spring.GiveOrder(CMD_STOP, {}, 0)
			Spring.GiveOrder(CMD_FIGHT, { x, y, z }, opts + CMD.OPT_SHIFT)
		end

		Spring.SelectUnitArray(selUnits)
	end)
	isReissuing = false

	return true
end
