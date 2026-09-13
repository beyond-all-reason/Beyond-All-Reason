local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Share Unit Command",
		desc = "Queueable command that gives the unit to an allied team. On factories it is passed on to the built units as part of their rally",
		author = "SuperKitowiec",
		date = "2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- UI/target preview lives in luaui/Widgets/cmd_share_unit.lua
local CMD_SHARE_UNIT = GameCMD.SHARE_UNIT

if gadgetHandler:IsSyncedCode() then
	local spGetUnitTeam = Spring.GetUnitTeam
	local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
	local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
	local spGetTeamInfo = Spring.GetTeamInfo
	local spAreTeamsAllied = Spring.AreTeamsAllied
	local spValidUnitID = Spring.ValidUnitID
	local spTransferUnit = Spring.TransferUnit
	local spSetUnitRulesParam = Spring.SetUnitRulesParam
	local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
	local spGetUnitPosition = Spring.GetUnitPosition
	local reissueOrder = Game.Commands.ReissueOrder

	local gaiaTeamID = Spring.GetGaiaTeamID()
	local range = 200 -- same as the widget's preview radius

	local shareUnitCmdDesc = {
		id = CMD_SHARE_UNIT,
		type = CMDTYPE.ICON_UNIT_OR_MAP,
		name = "quicksharetotarget",
		tooltip = "quicksharetotarget_tooltip",
		action = "quicksharetotarget",
		cursor = "settarget",
	}

	local teamHasAllies = {}
	for _, teamID in ipairs(Spring.GetTeamList()) do
		for _, otherTeamID in ipairs(Spring.GetTeamList(Spring.GetTeamAllyTeamID(teamID))) do
			if otherTeamID ~= teamID and otherTeamID ~= gaiaTeamID then
				teamHasAllies[teamID] = true
				break
			end
		end
	end

	local pendingTransfers = {} -- unitID -> targetTeamID

	local function isShareTarget(teamID, targetTeamID)
		return targetTeamID ~= nil
			and targetTeamID ~= teamID
			and targetTeamID ~= gaiaTeamID
			and spAreTeamsAllied(teamID, targetTeamID)
	end

	-- picks the allied team with the most units around the target position
	local function findTeamInArea(teamID, x, z)
		local teamCounts = {}
		local selectedTeam, selectedCount
		local foundUnits = spGetUnitsInCylinder(x, z, range)
		for i = 1, #foundUnits do
			local unitTeamID = spGetUnitTeam(foundUnits[i])
			if isShareTarget(teamID, unitTeamID) then
				local count = (teamCounts[unitTeamID] or 0) + 1
				teamCounts[unitTeamID] = count
				if not selectedCount or count > selectedCount then
					selectedTeam, selectedCount = unitTeamID, count
				end
			end
		end
		return selectedTeam
	end

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
		fromLua,
		fromInsert
	)
		-- accepts: CMD_SHARE_UNIT
		local paramCount = #cmdParams
		if paramCount == 4 then
			-- target team already resolved: { x, y, z, targetTeamID }
			-- factories queue it for the units they build, like a move order
			return isShareTarget(teamID, cmdParams[4])
		end

		-- resolve the target team when the order is given, so a queued share still goes to
		-- that team even if its units have moved away by the time the command runs
		local x, y, z, targetTeamID
		if paramCount == 1 then
			x, y, z = spGetUnitPosition(cmdParams[1])
			targetTeamID = spGetUnitTeam(cmdParams[1])
		elseif paramCount == 3 then
			x, y, z = cmdParams[1], cmdParams[2], cmdParams[3]
			targetTeamID = findTeamInArea(teamID, x, z)
		end
		if x and isShareTarget(teamID, targetTeamID) then
			reissueOrder(unitID, CMD_SHARE_UNIT, { x, y, z, targetTeamID }, cmdOptions, cmdTag, fromInsert)
		end
		return false
	end

	function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, cmdParams)
		if cmdID ~= CMD_SHARE_UNIT then
			return false
		end
		if spGetUnitIsBeingBuilt(unitID) then
			return true, false
		end

		local targetTeamID = cmdParams[4]
		if isShareTarget(teamID, targetTeamID) and not select(3, spGetTeamInfo(targetTeamID, false)) then
			-- transfer outside of command processing
			pendingTransfers[unitID] = targetTeamID
		end
		return true, true
	end

	local alliedAccess = { allied = true }

	function gadget:GameFrame(frame)
		if next(pendingTransfers) == nil then
			return
		end
		for unitID, targetTeamID in pairs(pendingTransfers) do
			pendingTransfers[unitID] = nil
			if spValidUnitID(unitID) then
				-- lets widgets tell these shares apart, e.g. gui_chat doesn't announce them
				spSetUnitRulesParam(unitID, "shareCommandFrame", frame, alliedAccess)
				-- given, not captured, so AllowUnitTransfer sharing restrictions apply
				spTransferUnit(unitID, targetTeamID, true)
			end
		end
	end

	function gadget:UnitDestroyed(unitID)
		pendingTransfers[unitID] = nil
	end

	function gadget:UnitCreated(unitID, unitDefID, teamID)
		if teamHasAllies[teamID] then
			spInsertUnitCmdDesc(unitID, shareUnitCmdDesc)
		end
	end

	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_SHARE_UNIT)
		gadgetHandler:RegisterAllowCommand(CMD_SHARE_UNIT)
		local allUnits = Spring.GetAllUnits()
		for i = 1, #allUnits do
			local unitID = allUnits[i]
			gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), spGetUnitTeam(unitID))
		end
	end
else -- UNSYNCED
	function gadget:Initialize()
		-- no area circle: the 4th param is the target team, not a radius
		Spring.SetCustomCommandDrawData(CMD_SHARE_UNIT, "settarget", { 0.88, 0.88, 0.88, 0.8 }, false)
	end
end
