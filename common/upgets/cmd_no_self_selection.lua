local upget = gadget or widget ---@type Addon
local UG = (gadget and GG) or (widget and WG) or false

function upget:GetInfo()
	return {
		name    = "Ignore Self",
		desc    = "With only one unit selected, avoid self-targeting with default commands (e.g. self-Guard)",
		author  = "efrec",
		date    = "2025",
		license = "GNU GPL, v2 or later",
		layer   = -1e9, -- before wupgets that handle unit selections
		enabled = (not not UG),
	}
end

if gadget then
	if not gadgetHandler:IsSyncedCode() then
		return
	end
end

local selectedUnitID
local restoreVolumeData = {}

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

if widget then
	function widget:SelectionChanged(selected)
		if selectedUnitID ~= selected[1] then
			if selectedUnitID ~= nil then
				restoreSelectionVolume(selectedUnitID)
				selectedUnitID = nil
			end
			if selected[1] ~= nil and selected[2] == nil then
				removeSelectionVolume(selected[1])
				selectedUnitID = selected[1]
			end
		end
	end
end

-- Override API functions that need to restore the selection volume temporarily.

local sp_TraceScreenRay = Spring.TraceScreenRay

local getSelectedUnitID
if widget then
	getSelectedUnitID = function()
		return selectedUnitID
	end
elseif gadget then
	getSelectedUnitID = function()
		return Spring.GetSelectedUnitsCount() == 1 and Spring.GetSelectedUnits()[1]
	end
end

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
	local unitID = getSelectedUnitID()

	if unitID then
		restoreSelectionVolume(unitID)
	end

	local description, result = sp_TraceScreenRay(screenX, screenY, onlyCoords, useMinimap, includeSky, ignoreWater, heightOffset)

	if unitID then
		removeSelectionVolume(unitID)
	end

	return description, result
end

function upget:Shutdown()
	Spring.TraceScreenRay = sp_TraceScreenRay
end
