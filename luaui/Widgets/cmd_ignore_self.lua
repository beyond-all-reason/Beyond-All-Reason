local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Ignore Self",
		desc    = "With only one unit selected, avoid self-targeting with default commands (e.g. self-Guard)",
		author  = "efrec",
		date    = "2025",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

local restoreVolumeData = {}
local selectedID

local function removeSelectionVolume(unitID)
	local sx, sy, sz, ox, oy, oz, shape, cont, axis, ignoreHits = Spring.GetUnitSelectionVolumeData(unitID)

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
