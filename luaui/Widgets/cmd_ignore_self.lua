local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Ignore Self",
		desc    = "With only one unit selected, avoid self-targeting with default commands (e.g. self-Guard)",
		author  = "efrec",
		date    = "2025",
		license = "GNU GPL, v2 or later",
		layer   = -100, -- preempt widgets loading wrapped Spring func -- todo: override engine api funcs after setting up env
		enabled = true,
	}
end

local restoreVolumeData = {}
local selectedID

local function removeSelectionVolume(unitID)
	local sx, sy, sz, ox, oy, oz, shape, cont, axis = Spring.GetUnitSelectionVolumeData(unitID)

	local rvd = restoreVolumeData
	rvd[1] = sx
	rvd[2] = sy
	rvd[3] = sz
	rvd[4] = ox
	rvd[5] = oy
	rvd[6] = oz
	rvd[7] = shape
	rvd[8] = cont
	rvd[9] = axis

	---@diagnostic disable-next-line -- just not correct?
	Spring.SetUnitSelectionVolumeData(unitID, 0, 0, 0, ox, oy, oz, 1, cont, axis)
end

local function restoreSelectionVolume(unitID)
	Spring.SetUnitSelectionVolumeData(unitID, unpack(restoreVolumeData))
end

function widget:SelectionChanged(selected)
	if selectedID ~= selected[1] then
		if selectedID ~= nil then
			restoreSelectionVolume(selectedID)
			selectedID = nil
		end
		if selected[1] ~= nil and selected[2] == nil then
			removeSelectionVolume(selected[1])
			selectedID = selected[1]
		end
	end
end

-- todo: wrap TraceScreenRay in both gadget + widget space

local sp_TraceScreenRay = Spring.TraceScreenRay

---@param screenX number position on x axis in mouse coordinates (origin on left border of view)
---@param screenY number position on y axis in mouse coordinates (origin on top border of view)
---@param onlyCoords boolean? (Default: `false`) `result` includes only coordinates
---@param useMinimap boolean? (Default: `false`) if position arguments are contained by minimap, use the minimap corresponding world position
---@param includeSky boolean? (Default: `false`)
---@param ignoreWater boolean? (Default: `false`)
---@param heightOffset number? (Default: `0`)
---@return ("unit"|"feature"|"ground"|"sky")? description of traced object or position
---@return (number|xyz)? result unitID, featureID, or position triple; when `onlyCoords` is true, units/features also give position.
Spring.TraceScreenRay = function(screenX, screenY, onlyCoords, useMinimap, includeSky, ignoreWater, heightOffset)
	local unitID = selectedID

	if unitID then
		restoreSelectionVolume(unitID)
	end

	local description, xyzOrID = sp_TraceScreenRay(screenX, screenY, onlyCoords, useMinimap, includeSky, ignoreWater, heightOffset)

	if unitID then
		removeSelectionVolume(unitID)
	end

	return description, xyzOrID
end

function widget:Shutdown()
	Spring.TraceScreenRay = sp_TraceScreenRay
end
