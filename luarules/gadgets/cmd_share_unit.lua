local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Share Unit Command",
		desc = "Queueable command that gives the unit to an allied team. \
		When issued with shift on a factory, adds the command to its rally commands",
		author = "SuperKitowiec",
		date = "2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local CMD_SHARE_UNIT = GameCMD.SHARE_UNIT

if gadgetHandler:IsSyncedCode() then
	local spGetUnitTeam = Spring.GetUnitTeam
	local spGiveOrderToUnit = Spring.GiveOrderToUnit
	local spGetTeamInfo = Spring.GetTeamInfo
	local spAreTeamsAllied = Spring.AreTeamsAllied
	local spGetGameFrame = Spring.GetGameFrame
	local spTransferUnit = Spring.TransferUnit
	local spSetUnitRulesParam = Spring.SetUnitRulesParam
	local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc

	local gaiaTeamID = Spring.GetGaiaTeamID()
	local IS_RALLY_SHARE = 1

	local shareUnitCmdDesc = {
		id = CMD_SHARE_UNIT,
		type = CMDTYPE.ICON_UNIT_OR_MAP,
		name = "quicksharetotarget",
		tooltip = "quicksharetotarget_tooltip",
		action = "quicksharetotarget",
		cursor = "settarget",
		queueing = true,
	}

	local teamHasAllies = {}
	for _, teamID in ipairs(Spring.GetTeamList() or {}) do
		local allyTeamID = Spring.GetTeamAllyTeamID(teamID)
		for _, otherTeamID in ipairs((allyTeamID and Spring.GetTeamList(allyTeamID)) or {}) do
			if otherTeamID ~= teamID and otherTeamID ~= gaiaTeamID then
				teamHasAllies[teamID] = true
				break
			end
		end
	end

	local alliesCanSeeParam = { allied = true }

	local isFactory = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.isFactory then
			isFactory[unitDefID] = true
		end
	end

	local function isShareTarget(teamID, targetTeamID)
		return targetTeamID ~= nil
			and targetTeamID ~= teamID
			and targetTeamID ~= gaiaTeamID
			and spAreTeamsAllied(teamID, targetTeamID)
	end

	local function shareUnit(unitID, targetTeamID, shouldNotAnnounce)
		-- team became invalid
		if select(3, spGetTeamInfo(targetTeamID, false)) then
			return
		end
		if shouldNotAnnounce then
			-- lets widgets tell these shares apart, e.g. gui_chat doesn't announce them
			spSetUnitRulesParam(unitID, "shareCommandFrame", spGetGameFrame(), alliesCanSeeParam)
		end
		spTransferUnit(unitID, targetTeamID, true)
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
		-- accepts: CMD_SHARE_UNIT, params are { targetTeamID } or { targetTeamID, IS_RALLY_SHARE }
		-- the widget resolves the clicked unit or spot into a team, raw targets are rejected
		local paramCount = #cmdParams
		if paramCount < 1 or paramCount > 2 or not isShareTarget(teamID, cmdParams[1]) then
			return false
		end

		-- already marked below, this is how a factory holds it and hands it to its units
		if paramCount == 2 then
			return true
		end

		if isFactory[unitDefID] then
			if cmdOptions.shift then
				-- rally share commands shouldn't spam the chat
				spGiveOrderToUnit(unitID, CMD_SHARE_UNIT, { cmdParams[1], IS_RALLY_SHARE }, cmdOptions.coded)
			else
				shareUnit(unitID, cmdParams[1])
			end
			return false
		end

		return true
	end

	function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, cmdParams)
		if cmdID ~= CMD_SHARE_UNIT then
			return false
		end
		shareUnit(unitID, cmdParams[1], cmdParams[2] == IS_RALLY_SHARE)
		-- the engine takes (used, remove), the library type declares one return
		---@diagnostic disable-next-line: redundant-return-value
		return true, true
	end

	local function insertShareCmdDesc(unitID, teamID)
		if teamHasAllies[teamID] then
			spInsertUnitCmdDesc(unitID, shareUnitCmdDesc)
		end
	end

	function gadget:UnitCreated(unitID, unitDefID, teamID)
		insertShareCmdDesc(unitID, teamID)
	end

	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_SHARE_UNIT)
		gadgetHandler:RegisterAllowCommand(CMD_SHARE_UNIT)
		local allUnits = Spring.GetAllUnits()
		for i = 1, #allUnits do
			local unitID = allUnits[i]
			insertShareCmdDesc(unitID, spGetUnitTeam(unitID))
		end
	end
end
