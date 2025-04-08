local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name 		= "Exclude walls from area set target",
		desc 		= "Stops walls from being included in area set target if units are present",
		date		= "April 2025",
		license 	= "GNU GPL, v2 or later",
		layer 		= 0,
		enabled 	= true
	}
end

--	excludedUnitsDef = {armdrag, armfdrag, armfort, cordrag, corfdrag, corfort, legdrag, legfort}
local excludedUnitsDefID = {74, 89, 102, 312, 328, 337, 558, 575}

local CMD_SET_TARGET = 34923

local gameStarted

local function contains(table, value)
	for i, DefID in ipairs(table) do
		if (DefID == value) then
		return true
		end
	end
	return false
end

function maybeRemoveSelf()
	if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
	end
end

function widget:GameStart()
	gameStarted = true
	maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
	maybeRemoveSelf()
end

function widget:Initialize()
	if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
		maybeRemoveSelf()
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if cmdID ~= CMD_SET_TARGET or #cmdParams ~= 4 then
		return
	end
	local cmdX, cmdY, cmdZ = cmdParams[1], cmdParams[2], cmdParams[3]

	local mouseX, mouseY = Spring.WorldToScreenCoords(cmdX, cmdY, cmdZ)

	local cmdRadius = cmdParams[4]

	local areaUnits = Spring.GetUnitsInCylinder(cmdX, cmdZ, cmdRadius, -4)

	local newCmds = {}
	for i = 1, #areaUnits do
		local unitID = areaUnits[i]
			local newCmdOpts = {}
			if #newCmds ~= 0 or cmdOpts.shift then
				newCmdOpts = { "shift" }
			end
			local unitDefID = Spring.GetUnitDefID(unitID)
			if not contains(excludedUnitsDefID, unitDefID) then
				newCmds[#newCmds + 1] = { CMD_SET_TARGET, { unitID }, newCmdOpts }
			end
	end

	if #newCmds > 0 then
		Spring.GiveOrderArrayToUnitArray(Spring.GetSelectedUnits(), newCmds)
		return true
	end
end


