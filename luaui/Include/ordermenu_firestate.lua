--DEFEND FIRESTATE REWORK: Remove modoption branching; always use the enabled virtual-index tables, always issue CMD_USER_FIRESTATE, and delete the disabled-variant tables plus defendFirestateEnabled().

local Firestates = VFS.Include("modules/firestates.lua")
local FirestateApi = VFS.Include("luaui/Include/firestate_api.lua")

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
	[Firestates.HOLD_FIRE] = 1,
	[Firestates.RETURN_FIRE] = 2,
	[Firestates.AGGRESSIVE] = 3,
	[Firestates.DEFEND] = 4,
	[Firestates.FIRE_AT_ALL] = 5,
}

local virtualIndexByStateEnabled = {
	[Firestates.HOLD_FIRE] = 1,
	[Firestates.DEFEND] = 2,
	[Firestates.AGGRESSIVE] = 3,
	[Firestates.RETURN_FIRE] = 4,
	[Firestates.FIRE_AT_ALL] = 5,
}

local stateByVirtualIndexDisabled = {
	[1] = Firestates.HOLD_FIRE,
	[2] = Firestates.RETURN_FIRE,
	[3] = Firestates.AGGRESSIVE,
	[4] = Firestates.DEFEND,
	[5] = Firestates.FIRE_AT_ALL,
}

local stateByVirtualIndexEnabled = {
	[1] = Firestates.HOLD_FIRE,
	[2] = Firestates.DEFEND,
	[3] = Firestates.AGGRESSIVE,
	[4] = Firestates.RETURN_FIRE,
	[5] = Firestates.FIRE_AT_ALL,
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

local function defendFirestateEnabled()
	return Spring.GetModOptions().experimental_defend_firestate
end

local function virtualIndexByState()
	if defendFirestateEnabled() then
		return virtualIndexByStateEnabled
	end
	return virtualIndexByStateDisabled
end

local function stateByVirtualIndex()
	if defendFirestateEnabled() then
		return stateByVirtualIndexEnabled
	end
	return stateByVirtualIndexDisabled
end

local function labelByVirtualIndex()
	if defendFirestateEnabled() then
		return labelByVirtualIndexEnabled
	end
	return labelByVirtualIndexDisabled
end

local function resolveVirtualIndex(unitID)
	local userFirestate = Firestates.resolveUserFirestate(unitID)
	if userFirestate == nil then
		return nil
	end
	return virtualIndexByState()[userFirestate]
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
	local labels = labelByVirtualIndex()
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
		return labelByVirtualIndex()[cmd.virtualIndex]
	end
	return nil
end

local function giveVirtualIndex(virtualIndex, cmdOptions, opts)
	local state = stateByVirtualIndex()[virtualIndex]
	if state == nil then
		return false
	end
	opts = opts or {}
	if opts.userInitiated == nil then
		opts.userInitiated = true
	end
	if not defendFirestateEnabled() then
		remappingFirestate = true
	end
	FirestateApi.giveFirestate(state, spGetSelectedUnits(), opts)
	if not defendFirestateEnabled() then
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

local function shouldDeferToGridMenu()
	if not WG.gridmenu or not WG.gridmenu.getActiveBuilder then
		return false
	end
	return WG.gridmenu.getActiveBuilder() ~= nil
end

local function hotkeyHandler(cmd, optLine, optWords, data, isRepeat, release)
	if release then
		return false
	end
	if shouldDeferToGridMenu() then
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

local function hasMatchingPendingFirestate(engineParam)
	local pendingCommandMeta = WG['firestate'] and WG['firestate'].pendingCommandMeta
	if not pendingCommandMeta then
		return false
	end
	local selectedUnits = spGetSelectedUnits()
	for index = 1, #selectedUnits do
		local pendingMeta = pendingCommandMeta[selectedUnits[index]]
		if pendingMeta then
			local pendingEngineParam = Firestates.toEngineFirestate(pendingMeta.userState)
			if pendingEngineParam == engineParam then
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
	if hasMatchingPendingFirestate(engineParam) then
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
