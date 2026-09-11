local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Untargetable units",
		desc = "Lets gadgets make units untargetable: no auto-targeting, no manual attack orders, no attack cursor",
		date = "2026.08.25",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--[[
	API (synced):
		GG.SetUnitUntargetable(unitID, untargetable)
		GG.IsUnitUntargetable(unitID) -> boolean

	Implementation notes:
	Everything is done with per-unit engine flags, so there is no per-frame cost.
	AllowWeaponTarget was deliberately not used: the engine only dispatches it for
	weapon defs registered via Script.SetWatchAllowTarget, and watching every
	weapon def is both expensive (a Lua call per target candidate, game-wide) and
	changes what unit_aa_targeting_priority / unit_defend_firestate get called for.

	* Neutral: weapons and command AIs never auto-target neutral units, unless the
	  attacker uses fire state 3 ("fire at everything").
	* LOS/radar mask: fire state 3 is only used by non-player attackers (raptors,
	  scavengers, skirmish AIs), so the unit is additionally hidden from every
	  enemy allyteam without human players. Engine targeting requires LOS or
	  radar, which blocks those attackers regardless of fire state.
	* AllowCommand: refuses unit-targeted attack / manual fire orders on the unit.
	  Ground and area attacks stay allowed (area target selection respects the
	  above). Only subscribed while some unit is untargetable.
	* Unsynced DefaultCommand: shows the move cursor instead of the attack cursor
	  (the engine default command only looks at alliances, not the neutral flag).

	Known gap: an enemy fire state 3 unit sharing an allyteam with a human player
	(co-op skirmish AI ally) can still opportunistically fire at the unit, and the
	set-target command (unit_target_on_the_move) is not intercepted.
]]

local CMD_ATTACK = CMD.ATTACK
local CMD_MANUALFIRE = CMD.MANUALFIRE
local CMD_MOVE = CMD.MOVE

if gadgetHandler:IsSyncedCode() then
	local spValidUnitID = Spring.ValidUnitID
	local spGetUnitTeam = Spring.GetUnitTeam
	local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spGetUnitNeutral = Spring.GetUnitNeutral
	local spSetUnitNeutral = Spring.SetUnitNeutral
	local spGetUnitLosState = Spring.GetUnitLosState
	local spSetUnitLosMask = Spring.SetUnitLosMask
	local spSetUnitLosState = Spring.SetUnitLosState
	local spGetAllyTeamList = Spring.GetAllyTeamList
	local spGetTeamList = Spring.GetTeamList
	local spGetPlayerList = Spring.GetPlayerList
	local spGetPlayerInfo = Spring.GetPlayerInfo
	local spAreTeamsAllied = Spring.AreTeamsAllied
	local spGetAllUnits = Spring.GetAllUnits
	local spGetUnitCommandCount = Spring.GetUnitCommandCount
	local spGetUnitCommands = Spring.GetUnitCommands
	local spGiveOrderToUnit = Spring.GiveOrderToUnit

	local CMD_REMOVE = CMD.REMOVE

	-- Freeze the engine los/radar updates, then clear both bits:
	local LOS_HIDDEN_MASK = { los = true, radar = true }
	local LOS_HIDDEN_STATE = { los = false, radar = false }
	local LOS_MASK_DIVISOR = 16 -- raw los status: state bits in the low nibble, mask bits in the high nibble

	-- unitID -> { neutral = previous neutral flag, losMasks = { [allyTeamID] = previous mask bits } }
	---@type table<integer, table>
	local untargetableUnits = {}
	local untargetableCount = 0

	local function allyTeamHasHumanPlayer(allyTeamID)
		local playerIDs = spGetPlayerList()
		for i = 1, #playerIDs do
			local _, active, spectator, _, playerAllyTeamID = spGetPlayerInfo(playerIDs[i], false)
			if active and not spectator and playerAllyTeamID == allyTeamID then
				return true
			end
		end
		return false
	end

	local function hideFromAIAllyTeams(unitID, data)
		local unitTeamID = spGetUnitTeam(unitID)
		local unitAllyTeamID = spGetUnitAllyTeam(unitID)
		local losMasks = {}

		local allyTeamIDs = spGetAllyTeamList()
		for i = 1, #allyTeamIDs do
			local allyTeamID = allyTeamIDs[i]
			if allyTeamID ~= unitAllyTeamID then
				local teamIDs = spGetTeamList(allyTeamID)
				if teamIDs and teamIDs[1] and not spAreTeamsAllied(unitTeamID, teamIDs[1]) and not allyTeamHasHumanPlayer(allyTeamID) then
					losMasks[allyTeamID] = math.floor((spGetUnitLosState(unitID, allyTeamID, true) or 0) / LOS_MASK_DIVISOR)
					spSetUnitLosMask(unitID, allyTeamID, LOS_HIDDEN_MASK)
					spSetUnitLosState(unitID, allyTeamID, LOS_HIDDEN_STATE)
				end
			end
		end

		data.losMasks = losMasks
	end

	local function unhideFromAllyTeams(unitID, data)
		-- Restoring the previous mask makes the engine recompute visibility again.
		for allyTeamID, previousMaskBits in pairs(data.losMasks) do
			spSetUnitLosMask(unitID, allyTeamID, previousMaskBits)
		end
		data.losMasks = nil
	end

	-- Purge queued attack orders aimed at the unit (new ones are refused in AllowCommand).
	local function removeAttackOrdersTargeting(targetID)
		local unitIDs = spGetAllUnits()
		for i = 1, #unitIDs do
			local attackerID = unitIDs[i]
			if spGetUnitCommandCount(attackerID) > 0 then
				local commands = spGetUnitCommands(attackerID, -1)
				local removeTags = {}
				for j = 1, #commands do
					local command = commands[j]
					local params = command.params
					if (command.id == CMD_ATTACK or command.id == CMD_MANUALFIRE)
						and params
						and params[2] == nil
						and params[1] == targetID
					then
						removeTags[#removeTags + 1] = command.tag
					end
				end
				if #removeTags > 0 then
					spGiveOrderToUnit(attackerID, CMD_REMOVE, removeTags, 0)
				end
			end
		end
	end

	-- Refuse unit-targeted (single param) attack and manual fire orders.
	local function allowCommand(_, unitID, unitDefID, teamID, cmdID, cmdParams)
		if cmdParams[2] == nil and untargetableUnits[cmdParams[1]] then
			return false
		end
		return true
	end

	-- The AllowCommand callin is attached and registered only while some unit is
	-- untargetable. It has to be attached lazily: a gadget that defines
	-- AllowCommand without registering any command gets auto-registered for
	-- ALL commands by the gadget handler right after Initialize.
	local function setCommandBlocking(enabled)
		if enabled then
			gadget.AllowCommand = allowCommand
			gadgetHandler:RegisterAllowCommand(CMD_ATTACK)
			gadgetHandler:RegisterAllowCommand(CMD_MANUALFIRE)
			gadgetHandler:UpdateCallIn("AllowCommand")
		else
			gadgetHandler:DeregisterAllowCommands()
			gadgetHandler:RemoveCallIn("AllowCommand")
			gadget.AllowCommand = nil
		end
	end

	local function forgetUnit(unitID)
		untargetableUnits[unitID] = nil
		untargetableCount = untargetableCount - 1
		if untargetableCount == 0 then
			setCommandBlocking(false)
		end
	end

	local function setUnitUntargetable(unitID, untargetable)
		if not spValidUnitID(unitID) then
			return
		end

		local data = untargetableUnits[unitID]

		if untargetable then
			if data then
				return
			end
			data = { neutral = spGetUnitNeutral(unitID) }
			untargetableUnits[unitID] = data
			untargetableCount = untargetableCount + 1
			if untargetableCount == 1 then
				setCommandBlocking(true)
			end

			spSetUnitNeutral(unitID, true)
			hideFromAIAllyTeams(unitID, data)
			removeAttackOrdersTargeting(unitID)
		else
			if not data then
				return
			end
			forgetUnit(unitID)

			spSetUnitNeutral(unitID, data.neutral)
			unhideFromAllyTeams(unitID, data)
		end

		SendToUnsynced("UnitUntargetable", unitID, untargetable)
	end

	local function isUnitUntargetable(unitID)
		return untargetableUnits[unitID] ~= nil
	end

	function gadget:Initialize()
		GG.SetUnitUntargetable = setUnitUntargetable
		GG.IsUnitUntargetable = isUnitUntargetable
	end

	function gadget:Shutdown()
		GG.SetUnitUntargetable = nil
		GG.IsUnitUntargetable = nil
	end

	function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
		local data = untargetableUnits[unitID]
		if data then
			-- The engine reset the unit visibility for its new allegiance:
			hideFromAIAllyTeams(unitID, data)
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
		if untargetableUnits[unitID] then
			forgetUnit(unitID)
			SendToUnsynced("UnitUntargetable", unitID, false)
		end
	end
else
	-- Mirror of the synced state, to show the move cursor instead of the
	-- attack cursor when hovering an untargetable unit.
	---@type table<integer, boolean>
	local untargetableUnits = {}
	local untargetableCount = 0

	local function handleUnitUntargetableEvent(_, unitID, untargetable)
		if untargetable then
			if not untargetableUnits[unitID] then
				untargetableUnits[unitID] = true
				untargetableCount = untargetableCount + 1
			end
		elseif untargetableUnits[unitID] then
			untargetableUnits[unitID] = nil
			untargetableCount = untargetableCount - 1
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("UnitUntargetable", handleUnitUntargetableEvent)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("UnitUntargetable")
	end

	function gadget:DefaultCommand(type, id, cmd)
		if
			untargetableCount > 0
			and type == "unit"
			and untargetableUnits[id]
			and (cmd == CMD_ATTACK or cmd == CMD_MANUALFIRE)
		then
			return CMD_MOVE
		end
	end
end
