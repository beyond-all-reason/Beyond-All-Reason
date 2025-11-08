local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Set Target by Unit Type",
		desc = "Hold down Alt and give an area set target order centered on a unit of the type to target",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end


-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame

local spGetUnitDefID = Spring.GetUnitDefID

local CMD_SET_TARGET = 34923

local gameStarted

function maybeRemoveSelf()
	if Spring.GetSpectatingState() and (spGetGameFrame() > 0 or gameStarted) then
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
	if Spring.IsReplay() or spGetGameFrame() > 0 then
		maybeRemoveSelf()
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if cmdID ~= CMD_SET_TARGET or #cmdParams ~= 4 or not cmdOpts.alt then
		return
	end

	local cmdX, cmdY, cmdZ = cmdParams[1], cmdParams[2], cmdParams[3]

	local mouseX, mouseY = Spring.WorldToScreenCoords(cmdX, cmdY, cmdZ)
	local targetType, targetId = Spring.TraceScreenRay(mouseX, mouseY)

	if targetType ~= "unit" then
		return
	end

	local cmdRadius = cmdParams[4]

	local filterUnitDefID = spGetUnitDefID(targetId)
	local areaUnits = Spring.GetUnitsInCylinder(cmdX, cmdZ, cmdRadius, -4)

	local newCmds = {}
	for i = 1, #areaUnits do
		local unitID = areaUnits[i]
		if spGetUnitDefID(unitID) == filterUnitDefID then
			local newCmdOpts = {}
			if #newCmds ~= 0 or cmdOpts.shift then
				newCmdOpts = { "shift" }
			end
			newCmds[#newCmds + 1] = { CMD_SET_TARGET, { unitID }, newCmdOpts }
		end
	end

	if #newCmds > 0 then
		Spring.GiveOrderArrayToUnitArray(Spring.GetSelectedUnits(), newCmds)
		return true
	end
end


