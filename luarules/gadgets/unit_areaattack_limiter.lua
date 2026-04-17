local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Area Attack Limiter",
		desc = "Converts excess area attack commands to fight commands to reduce lag from large (air) engagements",
		author = "Floris",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -999999,
		enabled = false
	}
end

if gadgetHandler:IsSyncedCode() then
	return
end

local CMD_ATTACK = CMD.ATTACK
local CMD_AREA_ATTACK = CMD.AREA_ATTACK
local CMD_FIGHT = CMD.FIGHT
local CMD_STOP = CMD.STOP

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGiveOrderArrayToUnitArray = Spring.GiveOrderArrayToUnitArray

-- Max units allowed to use the expensive engine-side area attack.
-- Excess units receive a FIGHT command to the area center instead,
-- which makes them converge and auto-engage without the costly
-- per-unit target resolution the engine performs for area attacks.
local BATCH_LIMIT = 25

function gadget:CommandNotify(cmdID, cmdParams, cmdOpts)
	-- Only intercept area-format commands (4 params: x, y, z, radius)
	if (cmdID ~= CMD_ATTACK and cmdID ~= CMD_AREA_ATTACK) or #cmdParams ~= 4 or cmdParams[4] <= 0 then
		return
	end

	local selUnits = spGetSelectedUnits()
	local count = #selUnits
	if count <= BATCH_LIMIT then
		return
	end

	-- Preserve command options
	local opts = 0
	if cmdOpts.alt then opts = opts + CMD.OPT_ALT end
	if cmdOpts.ctrl then opts = opts + CMD.OPT_CTRL end
	if cmdOpts.meta then opts = opts + CMD.OPT_META end
	if cmdOpts.right then opts = opts + CMD.OPT_RIGHT end

	local x, y, z = cmdParams[1], cmdParams[2], cmdParams[3]

	-- Split: first BATCH_LIMIT units get the area attack for proper
	-- target distribution, the rest get FIGHT to the area center
	local attackUnits = {}
	local fightUnits = {}
	for i = 1, count do
		if i <= BATCH_LIMIT then
			attackUnits[i] = selUnits[i]
		else
			fightUnits[#fightUnits + 1] = selUnits[i]
		end
	end

	if cmdOpts.shift then
		local shiftOpts = opts + CMD.OPT_SHIFT
		spGiveOrderArrayToUnitArray(attackUnits, {{cmdID, cmdParams, shiftOpts}})
		spGiveOrderArrayToUnitArray(fightUnits, {{CMD_FIGHT, {x, y, z}, shiftOpts}})
	else
		spGiveOrderArrayToUnitArray(attackUnits, {{CMD_STOP, {}, 0}, {cmdID, cmdParams, CMD.OPT_SHIFT}})
		spGiveOrderArrayToUnitArray(fightUnits, {{CMD_STOP, {}, 0}, {CMD_FIGHT, {x, y, z}, CMD.OPT_SHIFT}})
	end

	return true
end
