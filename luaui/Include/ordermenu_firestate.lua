--DEFEND FIRESTATE REWORK: Remove modoption branching; always use the enabled virtual-index tables, always issue CMD_USER_FIRESTATE, and delete the disabled-variant tables.

local CustomFirestateDefs = VFS.Include("modules/custom_firestate_defs.lua")
local UserFirestateCommands = VFS.Include("luaui/Include/user_firestate_commands.lua")

local CMD_FIRE_STATE = CMD.FIRE_STATE

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetModKeyState = Spring.GetModKeyState

local CYCLE_COUNT = 3
local PIP_COUNT = 3
local DIRECT_BIND_MAX = 5

local remappingFirestate = false
local onOrderGiven

local descrByState = {
	["Hold fire"] = "firestate_hold_fire_descr",
	["Return fire"] = "firestate_return_fire_descr",
	["Defend"] = "firestate_defend_descr",
	["Fire at will"] = "firestate_fire_at_will_descr",
	["Fire at all"] = "firestate_fire_at_all_descr",
}

local virtualIndexByStateDisabled = {
	[CustomFirestateDefs.HOLD_FIRE] = 1,
	[CustomFirestateDefs.RETURN_FIRE] = 2,
	[CustomFirestateDefs.AGGRESSIVE] = 3,
	[CustomFirestateDefs.DEFEND] = 4,
	[CustomFirestateDefs.FIRE_AT_ALL] = 5,
}

local virtualIndexByStateEnabled = {
	[CustomFirestateDefs.HOLD_FIRE] = 1,
	[CustomFirestateDefs.DEFEND] = 2,
	[CustomFirestateDefs.AGGRESSIVE] = 3,
	[CustomFirestateDefs.RETURN_FIRE] = 4,
	[CustomFirestateDefs.FIRE_AT_ALL] = 5,
}

local stateByVirtualIndexDisabled = {
	[1] = CustomFirestateDefs.HOLD_FIRE,
	[2] = CustomFirestateDefs.RETURN_FIRE,
	[3] = CustomFirestateDefs.AGGRESSIVE,
	[4] = CustomFirestateDefs.DEFEND,
	[5] = CustomFirestateDefs.FIRE_AT_ALL,
}

local stateByVirtualIndexEnabled = {
	[1] = CustomFirestateDefs.HOLD_FIRE,
	[2] = CustomFirestateDefs.DEFEND,
	[3] = CustomFirestateDefs.AGGRESSIVE,
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

local function resolveVirtualIndex(unitID)
	local userFirestate = CustomFirestateDefs.getUnitUserFirestate(unitID)
	if userFirestate == nil then
		return nil
	end
	local virtualIndexByState = Spring.GetModOptions().experimental_defend_firestate and virtualIndexByStateEnabled or virtualIndexByStateDisabled
	return virtualIndexByState[userFirestate]
end

local function pipFill(virtualIndex)
	if virtualIndex == 1 then
		return 1, 1
	elseif virtualIndex == 2 then
		return 2, 2
	elseif virtualIndex == 3 then
		return 3, 3
	elseif virtualIndex == 4 then
		return 2, 3
	elseif virtualIndex == 5 then
		return 1, 3
	end
	return 1, 1
end

local function buildCmdDesc(command, virtualIndex)
	local cmdDesc = table.copy(command)
	local labels = Spring.GetModOptions().experimental_defend_firestate and labelByVirtualIndexEnabled or labelByVirtualIndexDisabled
	cmdDesc.params = {
		virtualIndex - 1,
		labels[1],
		labels[2],
		labels[3],
	}
	cmdDesc.virtualIndex = virtualIndex
	cmdDesc.pipFillMin, cmdDesc.pipFillMax = pipFill(virtualIndex)
	return cmdDesc
end

local function stateLabel(cmd)
	if cmd.virtualIndex then
		local labels = Spring.GetModOptions().experimental_defend_firestate and labelByVirtualIndexEnabled or labelByVirtualIndexDisabled
		return labels[cmd.virtualIndex]
	end
	return nil
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
	UserFirestateCommands.giveFirestateToSelection(state, spGetSelectedUnits(), opts)
	if not defendFirestateEnabled then
		remappingFirestate = false
	end
	if onOrderGiven then
		onOrderGiven()
	end
	return true
end

local function nextCycledVirtualIndex(virtualIndex, reverse)
	if virtualIndex > CYCLE_COUNT then
		return reverse and CYCLE_COUNT or 1
	end
	if reverse then
		if virtualIndex <= 1 then
			return CYCLE_COUNT
		end
		return virtualIndex - 1
	end
	if virtualIndex >= CYCLE_COUNT then
		return 1
	end
	return virtualIndex + 1
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
	local virtualIndex = resolveVirtualIndex(selectedUnits[1])
	if virtualIndex == nil then
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
	local stagedFirestateByUnitId = WG['firestate'] and WG['firestate'].stagedFirestateByUnitId
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
	CYCLE_COUNT = CYCLE_COUNT,
	PIP_COUNT = PIP_COUNT,
	descrByState = descrByState,
	init = function(opts)
		onOrderGiven = opts.onOrderGiven
	end,
	buildCmdDesc = buildCmdDesc,
	stateLabel = stateLabel,
	pipFill = pipFill,
	resolveVirtualIndex = resolveVirtualIndex,
	nextCycledVirtualIndex = nextCycledVirtualIndex,
	giveVirtualIndex = giveVirtualIndex,
	hotkeyHandler = hotkeyHandler,
	commandNotify = commandNotify,
}
