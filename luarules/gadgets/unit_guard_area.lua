local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Guard Area",
		desc = "Overrides GUARD with area support.",
		author = "uBdead",
		date = "2026-04-11",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local CMD_AREA_GUARD = GameCMD.AREA_GUARD
local CMD_GUARD = CMD.GUARD

-- Set of UnitDefIDs that should never be selected (decorative objects, etc.)
local ignoreUnits = {}
-- Which unitDefIDs can guard (shared between synced and unsynced)
local canGuardDefs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canGuard then
		canGuardDefs[unitDefID] = true
	end
	if unitDef.modCategories and unitDef.modCategories['object']
      or (unitDef.customParams and unitDef.customParams.objectify) then
    ignoreUnits[unitDefID] = true
  end
end

if gadgetHandler:IsSyncedCode() then

	local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
	local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
	local spRemoveUnitCmdDesc = Spring.RemoveUnitCmdDesc
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitTeam = Spring.GetUnitTeam
	local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
	local spAreTeamsAllied = Spring.AreTeamsAllied
	local spValidUnitID = Spring.ValidUnitID
	local spGiveOrderToUnit = Spring.GiveOrderToUnit
	local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit
	local spGetUnitCommands = Spring.GetUnitCommands
	local spGetAllUnits = Spring.GetAllUnits
    local spEcho = Spring.Echo

	-- Maximum number of guard orders we'll issue in one area-guard operation
	local MAX_GUARD_ORDERS = 200

	--------------------------------------------------------------------------------
	-- Command description (replaces engine GUARD button)

	local areaGuardCmdDesc = {
		id = CMD_AREA_GUARD,
		type = CMDTYPE.ICON_UNIT_OR_AREA,
		name = 'Guard',
		action = 'areaguard',
		cursor = 'Guard',
		tooltip = 'Guard a unit or area.\nDrag to issue multiple guard orders in an area.',
		hidden = false,
	}

	--------------------------------------------------------------------------------
	-- Helpers

	local function isAllied(unitID, targetID)
		local ownTeam = spGetUnitTeam(unitID)
		local targetTeam = spGetUnitTeam(targetID)
		return ownTeam and targetTeam and spAreTeamsAllied(ownTeam, targetTeam)
	end

	local function findGuardTargets(unitID, x, z, radius)
		local unitDefID = spGetUnitDefID(unitID)
		if not unitDefID then return nil end

		-- local guardersIsAir = isAirDef[unitDefID] or false
		local allyTeamID = spGetUnitAllyTeam(unitID)

		local unitsInArea = spGetUnitsInCylinder(x, z, radius)
		if not unitsInArea then return nil end

		local targets = {}
		for i = 1, #unitsInArea do
			local targetID = unitsInArea[i]
			if targetID ~= unitID then
				local targetDefID = spGetUnitDefID(targetID)
				if targetDefID then
					local targetAllyTeam = spGetUnitAllyTeam(targetID)
					-- Skip decorative/objectified units
					if targetAllyTeam == allyTeamID and not ignoreUnits[targetDefID] then
						targets[#targets + 1] = targetID
					end
				end
			end
		end

		return targets
	end

	local function giveGuardOrders(unitID, targets, append)
		if not targets or #targets == 0 then return end

		-- Build set of targets already in the command queue
		local alreadyGuarded = {}
		local cmds = spGetUnitCommands(unitID, -1)
		if cmds then
			for _, cmd in ipairs(cmds) do
				if cmd.id == CMD_GUARD and cmd.params then
					alreadyGuarded[cmd.params[1]] = true
				end
			end
		end

		-- Build list of new targets (exclude ones already guarded)
		local newTargets = {}
		for i = 1, #targets do
			local targetID = targets[i]
			if not alreadyGuarded[targetID] then
				newTargets[#newTargets + 1] = targetID
			end
		end

		local attempted = #newTargets
		local truncated = false
		if attempted > MAX_GUARD_ORDERS then
			truncated = true
			for i = MAX_GUARD_ORDERS + 1, attempted do
				newTargets[i] = nil
			end
		end

		-- Build command array and send in one call to avoid many GiveOrder calls.
		local cmdArray = {}
		for i = 1, #newTargets do
			local targetID = newTargets[i]
			local options = CMD.OPT_SHIFT
			if #cmdArray == 0 then
				-- First command: only shift if user requested append
				if not append then
					options = 0
				end
			end
			cmdArray[#cmdArray + 1] = { CMD_GUARD, targetID, options }
		end

		if #cmdArray > 0 then
			spGiveOrderArrayToUnit(unitID, cmdArray)
		end

		if truncated then
			spEcho(string.format("Area guard: attempted %d guard targets, truncated to %d.", attempted, MAX_GUARD_ORDERS))
		end
	end

	--------------------------------------------------------------------------------
	-- Replace engine GUARD button with our area-guard version

	local function replaceGuardCommand(unitID)
		-- If we've already inserted our AREA_GUARD button, skip
		if spFindUnitCmdDesc(unitID, CMD_AREA_GUARD) then
			return
		end

		local guardIndex = spFindUnitCmdDesc(unitID, CMD_GUARD)
		if not guardIndex then
			return
		end

		-- Remove engine GUARD button and insert our AREA_GUARD in its place
		spRemoveUnitCmdDesc(unitID, guardIndex)
		spInsertUnitCmdDesc(unitID, guardIndex, areaGuardCmdDesc)
	end

	--------------------------------------------------------------------------------
	-- Lifecycle

	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_AREA_GUARD)
		gadgetHandler:RegisterAllowCommand(CMD_AREA_GUARD)
		gadgetHandler:RegisterAllowCommand(CMD_GUARD)

		-- Replace guard button on existing units
		local allUnits = spGetAllUnits()
		for i = 1, #allUnits do
			local unitID = allUnits[i]
			local unitDefID = spGetUnitDefID(unitID)
			if canGuardDefs[unitDefID] then
				replaceGuardCommand(unitID)
			end
		end
	end

	-- Use UnitFinished to ensure the engine has added its default commands first
	function gadget:UnitFinished(unitID, unitDefID, unitTeam)
		if canGuardDefs[unitDefID] then
			replaceGuardCommand(unitID)
		end
	end

	-- Handle transfer of units between teams (capture/share)
	function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
		if canGuardDefs[unitDefID] then
			replaceGuardCommand(unitID)
		end
	end

	function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
		if canGuardDefs[unitDefID] then
			replaceGuardCommand(unitID)
		end
	end

	--------------------------------------------------------------------------------
	-- Command handling

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		if not canGuardDefs[unitDefID] then
			return cmdID == CMD_GUARD -- let engine handle GUARD for non-guard-capable units
		end

		-- Engine CMD_GUARD (e.g. right-click on ally): let engine handle it
		if cmdID == CMD_GUARD then
			return true
		end

		-- CMD_AREA_GUARD handling
		local numParams = #cmdParams

		if numParams == 1 then
			-- Direct click on a unit via AREA_GUARD button: forward as engine CMD.GUARD
			local targetID = cmdParams[1]
			if spValidUnitID(targetID) and isAllied(unitID, targetID) then
				spGiveOrderToUnit(unitID, CMD_GUARD, targetID, cmdOptions.coded or 0)
			end
			return false

		elseif numParams == 4 then
			-- Area drag: x, y, z, radius
			local x, y, z, radius = cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4]

			local targets = findGuardTargets(unitID, x, z, radius)
			giveGuardOrders(unitID, targets, cmdOptions.shift or false)
			return false
		end

		return true
	end

else -- UNSYNCED
	local spSetCustomCommandDrawData = Spring.SetCustomCommandDrawData

	function gadget:Initialize()
		spSetCustomCommandDrawData(CMD_AREA_GUARD, "Guard", { 136/255, 251/255, 255, 0.7 }, true)
	end

	function gadget:DefaultCommand(type, id, defaultCmd)
		if defaultCmd == CMD_GUARD then
			return CMD_AREA_GUARD
		end
	end

end
