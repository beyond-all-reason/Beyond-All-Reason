--DEFEND FIRESTATE REWORK: Remove modoption branching; always use the enabled virtual-index tables, always issue CMD_USER_FIRESTATE, and delete the disabled-variant tables.

local CustomFirestateDefs = VFS.Include("modules/custom_firestate_defs.lua")
local UserFirestateCommands = VFS.Include("luaui/Include/user_firestate_commands.lua")

local mathBitOr = math.bit_or
local mathFloor = math.floor
local CMD_FIRE_STATE = CMD.FIRE_STATE

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetModKeyState = Spring.GetModKeyState
local spGetUnitDefID = Spring.GetUnitDefID
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spGetUnitTeam = Spring.GetUnitTeam
local spGetLocalTeamID = Spring.GetLocalTeamID
local spIsGodModeEnabled = Spring.IsGodModeEnabled
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetSpectatingState = Spring.GetSpectatingState

local CYCLE_COUNT = 3
local PIP_COUNT = 3
local DIRECT_BIND_MAX = 5

local remappingFirestate = false
local onOrderGiven
local cachedUnitDefsHaveCommand = {}

local descrByState = {
	["Hold fire"] = "firestate_hold_fire_descr",
	["Return fire"] = "firestate_return_fire_descr",
	Defend = "firestate_defend_descr",
	["Fire at will"] = "firestate_fire_at_will_descr",
	["Fire at all"] = "firestate_fire_at_all_descr",
}

local virtualIndexByStateDisabled = {
	[CustomFirestateDefs.HOLD_FIRE] = 1,
	[CustomFirestateDefs.RETURN_FIRE] = 2,
	[CustomFirestateDefs.FIRE_AT_WILL] = 3,
	[CustomFirestateDefs.DEFEND] = 4,
	[CustomFirestateDefs.FIRE_AT_ALL] = 5,
}

local virtualIndexByStateEnabled = {
	[CustomFirestateDefs.HOLD_FIRE] = 1,
	[CustomFirestateDefs.DEFEND] = 2,
	[CustomFirestateDefs.FIRE_AT_WILL] = 3,
	[CustomFirestateDefs.RETURN_FIRE] = 4,
	[CustomFirestateDefs.FIRE_AT_ALL] = 5,
}

local stateByVirtualIndexDisabled = {
	[1] = CustomFirestateDefs.HOLD_FIRE,
	[2] = CustomFirestateDefs.RETURN_FIRE,
	[3] = CustomFirestateDefs.FIRE_AT_WILL,
	[4] = CustomFirestateDefs.DEFEND,
	[5] = CustomFirestateDefs.FIRE_AT_ALL,
}

local stateByVirtualIndexEnabled = {
	[1] = CustomFirestateDefs.HOLD_FIRE,
	[2] = CustomFirestateDefs.DEFEND,
	[3] = CustomFirestateDefs.FIRE_AT_WILL,
	[4] = CustomFirestateDefs.RETURN_FIRE,
	[5] = CustomFirestateDefs.FIRE_AT_ALL,
}

local labelByVirtualIndexDisabled = {
	[1] = "Hold fire",
	[2] = "Return fire",
	[3] = "Fire at will",
	[4] = "Defend",
	[5] = "Fire at all",
}

local labelByVirtualIndexEnabled = {
	[1] = "Hold fire",
	[2] = "Defend",
	[3] = "Fire at will",
	[4] = "Return fire",
	[5] = "Fire at all",
}

local function unitIsControllable(unitID)
	local unitTeam = spGetUnitTeam(unitID)
	if unitTeam == nil then
		return false
	end
	if unitTeam == spGetLocalTeamID() then
		return true
	end
	if spGetSpectatingState() then
		return true
	end
	local godMode, controlAllies, controlEnemies = spIsGodModeEnabled()
	if not godMode then
		return false
	end
	if controlAllies == nil and controlEnemies == nil then
		return true
	end
	if spAreTeamsAllied(unitTeam, spGetLocalTeamID()) then
		return controlAllies == true
	end
	return controlEnemies == true
end

local function unitHasCommand(unitID, cmdID)
	if not unitIsControllable(unitID) then
		return false
	end
	local unitDefID = spGetUnitDefID(unitID)
	if unitDefID == nil then
		return false
	end
	local byDef = cachedUnitDefsHaveCommand[cmdID]
	if byDef == nil then
		byDef = {}
		cachedUnitDefsHaveCommand[cmdID] = byDef
	end
	local hasCommand = byDef[unitDefID]
	if hasCommand == nil then
		hasCommand = spFindUnitCmdDesc(unitID, cmdID) ~= nil
		byDef[unitDefID] = hasCommand
	end
	return hasCommand
end

local function resolveVirtualIndex(unitID)
	local userFirestate = tonumber(CustomFirestateDefs.getUnitUserFirestate(unitID))
	if userFirestate == nil then
		return nil
	end
	local virtualIndexByState = Spring.GetModOptions().experimental_defend_firestate and virtualIndexByStateEnabled
		or virtualIndexByStateDisabled
	return virtualIndexByState[userFirestate]
end

local function pipBit(pipIndex)
	return mathFloor(2 ^ (pipIndex - 1))
end

local function pipMaskFromVirtualIndex(virtualIndex)
	if virtualIndex == 1 then
		return pipBit(1)
	elseif virtualIndex == 2 then
		return pipBit(2)
	elseif virtualIndex == 3 then
		return pipBit(3)
	elseif virtualIndex == 4 then
		return mathBitOr(pipBit(2), pipBit(3))
	end
	return 0
end

local function resolveSelection(unitIDs)
	if not unitIDs then
		return nil, 0, false
	end
	local sharedVirtualIndex
	local isMixed = false
	local pipMask = 0
	for index = 1, #unitIDs do
		local unitID = unitIDs[index]
		if unitHasCommand(unitID, CMD_FIRE_STATE) then
			local virtualIndex = resolveVirtualIndex(unitID)
			if virtualIndex ~= nil then
				if sharedVirtualIndex == nil then
					sharedVirtualIndex = virtualIndex
				elseif virtualIndex ~= sharedVirtualIndex then
					isMixed = true
				end
				pipMask = mathBitOr(pipMask, pipMaskFromVirtualIndex(virtualIndex))
			end
		end
	end
	if sharedVirtualIndex == nil then
		return nil, 0, false
	end
	if isMixed then
		return nil, pipMask, true
	end
	return sharedVirtualIndex, pipMask, false
end

local function buildCmdDesc(command, virtualIndex, pipMask, isMixed)
	local cmdDesc = table.copy(command)
	local labels = Spring.GetModOptions().experimental_defend_firestate and labelByVirtualIndexEnabled
		or labelByVirtualIndexDisabled
	cmdDesc.params = {
		virtualIndex and (virtualIndex - 1) or -1,
		labels[1],
		labels[2],
		labels[3],
	}
	cmdDesc.virtualIndex = virtualIndex
	cmdDesc.pipMask = pipMask or pipMaskFromVirtualIndex(virtualIndex)
	cmdDesc.pipCount = PIP_COUNT
	cmdDesc.isMixed = isMixed
	return cmdDesc
end

local function buildSelectionCmdDesc(command, unitIDs)
	local virtualIndex, pipMask, isMixed = resolveSelection(unitIDs)
	return buildCmdDesc(command, virtualIndex, pipMask, isMixed)
end

local function stateLabel(cmd)
	local virtualIndex = cmd.virtualIndex
	if cmd.isMixed or virtualIndex == nil or virtualIndex < 1 then
		return nil
	end
	local labels = Spring.GetModOptions().experimental_defend_firestate and labelByVirtualIndexEnabled
		or labelByVirtualIndexDisabled
	return labels[cmd.virtualIndex]
end

local function giveVirtualIndex(virtualIndex, cmdOptions, opts)
	local defendFirestateEnabled = Spring.GetModOptions().experimental_defend_firestate
	local stateByVirtualIndex = defendFirestateEnabled and stateByVirtualIndexEnabled or stateByVirtualIndexDisabled
	local state = stateByVirtualIndex[virtualIndex]
	if state == nil then
		return false
	end
	opts = opts or {}
	if opts.userInitiated == nil then
		opts.userInitiated = true
	end
	if not defendFirestateEnabled then
		remappingFirestate = true
	end
	UserFirestateCommands.setSelectionFirestate(state, spGetSelectedUnits(), opts)
	if not defendFirestateEnabled then
		remappingFirestate = false
	end
	if onOrderGiven then
		onOrderGiven()
	end
	return true
end

local function nextCycledVirtualIndex(virtualIndex, reverse)
	if virtualIndex and virtualIndex > CYCLE_COUNT then
		return reverse and CYCLE_COUNT or 1
	end
	local currentPip = virtualIndex or 0
	if reverse then
		if currentPip <= 1 then
			return CYCLE_COUNT
		end
		return currentPip - 1
	end
	if currentPip >= CYCLE_COUNT then
		return 1
	end
	return currentPip + 1
end

local function hotkeyHandler(cmd, optLine, optWords, data, isRepeat, release)
	if release then
		return false
	end
	if WG.gridmenu and WG.gridmenu.getActiveBuilder and WG.gridmenu.getActiveBuilder() ~= nil then
		return false
	end
	local selectedUnits = spGetSelectedUnits()
	if #selectedUnits == 0 then
		return false
	end
	local virtualIndex, _, isMixed = resolveSelection(selectedUnits)
	if not isMixed and virtualIndex == nil then
		return false
	end
	local param = optWords[1] and tonumber(optWords[1])
	if param ~= nil then
		local targetIndex = param + 1
		if targetIndex < 1 or targetIndex > DIRECT_BIND_MAX then
			return false
		end
		giveVirtualIndex(targetIndex, 0)
		return false
	end
	local _, _, shift = spGetModKeyState()
	local nextIndex = nextCycledVirtualIndex(virtualIndex, shift)
	giveVirtualIndex(nextIndex, 0)
	return false
end

local function hasMatchingStagedFirestate(engineParam)
	local stagedFirestateByUnitId = WG.firestate and WG.firestate.stagedFirestateByUnitId
	if not stagedFirestateByUnitId then
		return false
	end
	local selectedUnits = spGetSelectedUnits()
	for index = 1, #selectedUnits do
		local stagedFirestate = stagedFirestateByUnitId[selectedUnits[index]]
		if stagedFirestate then
			local stagedEngineParam = CustomFirestateDefs.toEngineFirestate(stagedFirestate.userState)
			if stagedEngineParam == engineParam then
				return true
			end
		end
	end
	return false
end

local function commandNotify(cmdID, cmdParams, cmdOptions)
	if remappingFirestate or cmdID ~= CMD_FIRE_STATE or not cmdParams then
		return false
	end
	local engineParam = tonumber(cmdParams[1])
	if engineParam == nil or engineParam < 0 or engineParam > 2 then
		return false
	end
	if hasMatchingStagedFirestate(engineParam) then
		return false
	end
	return giveVirtualIndex(engineParam + 1, cmdOptions)
end

return {
	descrByState = descrByState,
	init = function(opts)
		onOrderGiven = opts.onOrderGiven
	end,
	buildSelectionCmdDesc = buildSelectionCmdDesc,
	stateLabel = stateLabel,
	nextCycledVirtualIndex = nextCycledVirtualIndex,
	giveVirtualIndex = giveVirtualIndex,
	hotkeyHandler = hotkeyHandler,
	commandNotify = commandNotify,
}
