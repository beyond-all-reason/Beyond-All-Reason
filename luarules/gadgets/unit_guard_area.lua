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
	local spEditUnitCmdDesc = Spring.EditUnitCmdDesc
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitTeam = Spring.GetUnitTeam
	local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
	local spAreTeamsAllied = Spring.AreTeamsAllied
	local spValidUnitID = Spring.ValidUnitID
	local spGiveOrderToUnit = Spring.GiveOrderToUnit
	local spGetUnitCommands = Spring.GetUnitCommands
	local spGetAllUnits = Spring.GetAllUnits

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
		if not unitDefID then return {} end

		-- local guardersIsAir = isAirDef[unitDefID] or false
		local allyTeamID = spGetUnitAllyTeam(unitID)

		local unitsInArea = spGetUnitsInCylinder(x, z, radius)
		if not unitsInArea then return {} end

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

	local function giveGuardOrders(unitID, targets)
		if #targets == 0 then return end

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

		for _, targetID in ipairs(targets) do
			if not alreadyGuarded[targetID] then
				spGiveOrderToUnit(unitID, CMD_GUARD, { targetID }, { "shift" })
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Replace engine GUARD button with our area-guard version

	local function replaceGuardCommand(unitID)
		local guardIndex = spFindUnitCmdDesc(unitID, CMD_GUARD)
		if guardIndex then
			-- Hide engine GUARD but keep it so right-click default on allies still works
			spEditUnitCmdDesc(unitID, guardIndex, { hidden = true })
			-- Insert our AREA_GUARD button in its place
			spInsertUnitCmdDesc(unitID, guardIndex, areaGuardCmdDesc)
		end
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

	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
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
				spGiveOrderToUnit(unitID, CMD_GUARD, { targetID }, cmdOptions.coded or 0)
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
	local spIsUnitAllied = Spring.IsUnitAllied
	local spGetSelectedUnitsCounts = Spring.GetSelectedUnitsCounts

	function gadget:Initialize()
		spSetCustomCommandDrawData(CMD_AREA_GUARD, "Guard", { 136/255, 251/255, 255, 0.7 }, true)
	end

	function gadget:DefaultCommand(type, id)
		if type ~= "unit" then return end
		if not spIsUnitAllied(id) then return end
		for unitDefID in pairs(spGetSelectedUnitsCounts()) do
			if canGuardDefs[unitDefID] then
				return CMD_AREA_GUARD
			end
		end
	end

end
