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

local CMD_SHARE_UNIT = GameCMD.SHARE_UNIT

if gadgetHandler:IsSyncedCode() then
	local spGetUnitTeam = Spring.GetUnitTeam
	local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
	local spGetTeamInfo = Spring.GetTeamInfo
	local spAreTeamsAllied = Spring.AreTeamsAllied
	local spGetGameFrame = Spring.GetGameFrame
	local spTransferUnit = Spring.TransferUnit
	local spSetUnitRulesParam = Spring.SetUnitRulesParam
	local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc

	local gaiaTeamID = Spring.GetGaiaTeamID()

	local shareUnitCmdDesc = {
		id = CMD_SHARE_UNIT,
		type = CMDTYPE.ICON_UNIT_OR_MAP,
		name = "quicksharetotarget",
		tooltip = "quicksharetotarget_tooltip",
		action = "quicksharetotarget",
		cursor = "settarget",
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

	local alliedAccess = { allied = true }

	local function isShareTarget(teamID, targetTeamID)
		return targetTeamID ~= nil
			and targetTeamID ~= teamID
			and targetTeamID ~= gaiaTeamID
			and spAreTeamsAllied(teamID, targetTeamID)
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams)
		-- accepts: CMD_SHARE_UNIT, params are { targetTeamID }
		-- the widget resolves the clicked unit or spot into a team, raw targets are rejected
		-- factories queue it for the units they build, like a move order
		return #cmdParams == 1 and isShareTarget(teamID, cmdParams[1])
	end

	function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, cmdParams)
		if cmdID ~= CMD_SHARE_UNIT then
			return false
		end
		if spGetUnitIsBeingBuilt(unitID) then
			return true, false
		end

		local targetTeamID = cmdParams[1]
		if isShareTarget(teamID, targetTeamID) and not select(3, spGetTeamInfo(targetTeamID, false)) then
			-- lets widgets tell these shares apart, e.g. gui_chat doesn't announce them
			spSetUnitRulesParam(unitID, "shareCommandFrame", spGetGameFrame(), alliedAccess)
			spTransferUnit(unitID, targetTeamID, true)
		end
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
