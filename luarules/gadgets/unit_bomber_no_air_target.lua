local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name	= "Bomber No Air Target",
		desc	= "Prevents bombers from targeting air units in flight",
		author	= "Floris",
		date	= "2026",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled	= true,
	}
end

local math_abs = math.abs
local ensureTable = table.ensureTable

local CallAsTeam = CallAsTeam
local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitVelocity = Spring.GetUnitVelocity

local gameSpeed = Game.gameSpeed

local reissueOrder = Game.Commands.ReissueOrder
local CMD_REMOVE = CMD.REMOVE
local CMD_UNIT_CANCEL_TARGET = GameCMD.UNIT_CANCEL_TARGET
local CMDOPT_ALT = CMD.OPT_ALT

local commands = {
	[CMD.ATTACK] = true,
	[GameCMD.UNIT_SET_TARGET] = true,
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = true,
}

local cancelCommands = {
	[GameCMD.UNIT_SET_TARGET] = true,
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = true,
}

-- air bombers can still attack air units cause their onlytargetcategory doesnt exclude them (notsub)

local isBomber = {}
local isAir = {}

for udid, unitDef in pairs(UnitDefs) do
	if unitDef.modCategories and unitDef.modCategories['vtol'] then
		isAir[udid] = true
	end
	if unitDef.canFly and not unitDef.hoverAttack and unitDef.weapons and unitDef.weapons[1] then
		for i = 1, #unitDef.weapons do
			local wDef = WeaponDefs[unitDef.weapons[i].weaponDef]
			if wDef.type == "AircraftBomb" or wDef.type == "TorpedoLauncher" then
				isBomber[udid] = true
				break
			end
		end
	end
end

local landedAirTargets = {}
local bomberAirTargets = {}

local function isLanded(unitID)
	-- Use a quick heuristic instead of relying on move type data.
	local ux, uy, uz = spGetUnitPosition(unitID)
	local vx, vy, vz, speed = spGetUnitVelocity(unitID)
	return speed < 0.01 and math_abs(uy - spGetGroundHeight(ux, uz)) <= 10 -- allow some base point offset
end

local function getPositionOnGround(targetID, teamID)
	-- Do not leak exact positions when enemies are not visible.
	local _, _, _, ux, uy, uz = CallAsTeam(teamID, spGetUnitPosition, targetID, false, true)
	if ux and uz then
		return ux, spGetGroundHeight(ux, uz), uz
	end
end

local function removeBomberOrder(bomberID, targetID)
	local orders = bomberAirTargets[bomberID]

	if orders and orders[targetID] then
		local order = orders[targetID]
		orders[targetID] = nil

		-- todo: check that bomberTeam has LOS or access on targetID

		local p1, p2, p3, cmdID = order[1], order[2], order[3], order[4]

		if cancelCommands[cmdID] then
			-- todo: should be a call to GG.SetTarget.Cancel or similar
			Spring.GiveOrderToUnit(bomberID, CMD_UNIT_CANCEL_TARGET, { p1, p2, p3 })
			return
		end

		for index = 1, Spring.GetUnitCommandCount(bomberID) do
			local command, options, tag, c1, c2, c3 = Spring.GetUnitCurrentCommand(bomberID, index)
			if cmdID == command then
				-- Commands with a death dependence set the params to all-nil.
				-- The target may not be dead -- in which case check position.
				if not c1 then
					Spring.GiveOrderToUnit(bomberID, CMD_REMOVE, tag)
				elseif p1 == c1 and p2 == c2 and p3 == c3 then
					Spring.GiveOrderToUnit(bomberID, CMD_REMOVE, tag)
					return -- canceled the exact command
				end
			end
		end
	end
end

local function removeBadTargets()
	-- Remove commands that no longer target grounded air units.
	for targetID, bomberList in pairs(landedAirTargets) do
		if spGetUnitIsDead(targetID) ~= false or not isLanded(targetID) then
			for bomberID in pairs(bomberList) do
				removeBomberOrder(bomberID, targetID)
				bomberList[bomberID] = nil
			end
			landedAirTargets[targetID] = nil
		end
	end
end

function gadget:Initialize()
	for cmdID in pairs(commands) do
		gadgetHandler:RegisterAllowCommand(cmdID)
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua, fromInsert)
	-- Block bombers from attacking air units (single-target only, not ground attack)
	if isBomber[unitDefID] and cmdParams[1] and not cmdParams[2] then
		local targetID = cmdParams[1]
		local targetDefID = spGetUnitDefID(targetID)
		if targetDefID and isAir[targetDefID] then
			if isLanded(targetID) then
				-- Move the target onto the ground, whenever possible.
				local x, y, z = getPositionOnGround(targetID, unitTeam)
				if x then
					cmdParams[1], cmdParams[2], cmdParams[3] = x, y, z
					reissueOrder(unitID, cmdID, cmdParams, cmdOptions, cmdTag, fromInsert);
					ensureTable(bomberAirTargets, unitID)[targetID] = { x, y, z, cmdID }
					ensureTable(landedAirTargets, targetID)[unitID] = true
				end
			end
			return false
		end
	end
	return true
end

function gadget:GameFrame(frame)
	if frame % gameSpeed == 0 then
		removeBadTargets(frame)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if landedAirTargets[unitID] then
		local bomberList = landedAirTargets[unitID]
		for bomberID in pairs(bomberList) do
			removeBomberOrder(bomberID, unitID)
			bomberList[bomberID] = nil
		end
		landedAirTargets[unitID] = nil
	end
	bomberAirTargets[unitID] = nil
end
