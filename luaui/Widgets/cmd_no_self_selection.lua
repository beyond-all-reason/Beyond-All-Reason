local widget = widget ---@class Widget

function widget:GetInfo()
	return {
		name    = "Ignore Self",
		desc    = "Avoid self-targeting with default commands (e.g. Guard on self)",
		author  = "efrec",
		date    = "2025-10-13",
		version = "v1.0",
		license = "GNU GPL, v2 or later",
		layer   = -1e9, -- before other w:DefaultCommand
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

---@type number in seconds
local doubleClickTime = Spring.GetConfigInt("DoubleClickTime", 200) / 1000
---@type integer in pixels, as the Manhattan norm
local doubleClickDist = 12
---@type table<CMD, true>
local allowSelfCommand = {
	-- None so far.
}

--------------------------------------------------------------------------------
-- Globals ---------------------------------------------------------------------

local math_abs = math.abs

local sp_GetActiveCommand = Spring.GetActiveCommand
local sp_GetMouseState = Spring.GetMouseState
local sp_GetUnitSelectionVolumeData = Spring.GetUnitSelectionVolumeData
local sp_SetUnitSelectionVolumeData = Spring.SetUnitSelectionVolumeData
local sp_TraceScreenRay = Spring.TraceScreenRay

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local selectedUnitID -- widget ignores/sees through only a single unit
local selectClickTime = 0
local cx, cy

local restoreVolumeData = {}
local isVolumeHidden = false
local inActiveCommand = false

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function cacheSelectionVolume(unitID)
	restoreVolumeData = { sp_GetUnitSelectionVolumeData(unitID) }
end

-- Prevent a unit from being hovered, clicked, or selected via raycast (e.g. by the cursor).
-- This way you cannot give nonsense commands, such as self-guard, and it becomes easy to
-- target things obscured by the unit (sub under battleship, things under large aircraft or tall buildings)
--
-- Since the camera can be rotated to extreme perspectives, even units that do not allow any
-- other unit underneath themselves will have their selection volumes shrunk to zero radius.
local function removeSelectionVolume(unitID)
	-- The xyz scale and volume shape are not kept; we want an unambiguous point volume.
	local _, _, _, ox, oy, oz, _, cont, axis = sp_GetUnitSelectionVolumeData(unitID)
	local shape = 1 -- spherical volume
	sp_SetUnitSelectionVolumeData(unitID, 0, 0, 0, ox, oy, oz, shape, cont, axis)
	isVolumeHidden = true
end

local function restoreSelectionVolume(unitID)
	sp_SetUnitSelectionVolumeData(unitID, unpack(restoreVolumeData))
	isVolumeHidden = false
end

local function inDoubleClickDistance(mx, my)
	return cx and math_abs(mx - cx) + math_abs(my - cy) <= doubleClickDist
end

---Determine the time delay to apply an effect so that double clicks can register.
local function getSingleClickDuration()
	local mx, my, leftButton = sp_GetMouseState()

	if leftButton then
		if selectClickTime <= 0 or not inDoubleClickDistance(mx, my) then
			-- Start of a new single- or double-click.
			cx, cy = mx, my
			return doubleClickTime
		else
			-- Double-click consumes the single-click.
			cx, cy = nil, nil
			return 0
		end
	end

	return 0
end

--------------------------------------------------------------------------------
-- Engine callins --------------------------------------------------------------

function widget:SelectionChanged(selected)
	local firstID = selected[1]
	local isSingleSelection = firstID and not selected[2]

	if (not isSingleSelection or firstID ~= selectedUnitID) and selectedUnitID then
		restoreSelectionVolume(selectedUnitID)
		selectedUnitID = nil
	end

	if isSingleSelection and not selectedUnitID then
		cacheSelectionVolume(firstID)
		selectedUnitID = firstID
		selectClickTime = getSingleClickDuration()
	end
end

function widget:MousePress(x, y, button)
	if button == 1 and isVolumeHidden then
		local _, commandID = sp_GetActiveCommand()
		if not commandID then
			restoreSelectionVolume(selectedUnitID)
			selectClickTime = doubleClickTime
		end
	end
end

function widget:Update(dt)
	if selectedUnitID then
		if selectClickTime > 0 then
			selectClickTime = selectClickTime - dt
		elseif not isVolumeHidden and not inActiveCommand then
			selectClickTime = 0
			removeSelectionVolume(selectedUnitID)
		end
	end
end

function widget:DefaultCommand(type, id, cmd)
	if selectedUnitID then
		if id == selectedUnitID and not allowSelfCommand[cmd] then
			return CMD.MOVE
		end
	end
end

function widget:ActiveCommandChanged(cmdid, type)
	if cmdid and allowSelfCommand[cmdid] then
		if isVolumeHidden then
			restoreSelectionVolume(selectedUnitID)
		end
		inActiveCommand = true
	elseif inActiveCommand then
		inActiveCommand = false
		if selectedUnitID then
			removeSelectionVolume(selectedUnitID)
		end
	end
end

-- Interwupget communications and compatability

---Get information about a ray traced from screen to world position.
--
-- This method is an override of the engine-provided TraceScreenRay,
-- and can peek selection volumes hidden by `cmd_no_self_selection`.
---@param screenX number position on x axis in mouse coordinates (origin on left border of view)
---@param screenY number position on y axis in mouse coordinates (origin on top border of view)
---@param onlyCoords boolean? (default: `false`) `result` includes only coordinates
---@param useMinimap boolean? (default: `false`) if position arguments are contained by minimap, use the minimap corresponding world position
---@param includeSky boolean? (default: `false`)
---@param ignoreWater boolean? (default: `false`)
---@param heightOffset number? (default: `0`)
---@return ("unit"|"feature"|"ground"|"sky")? description of traced object or position
---@return (integer|xyz)? result unitID or featureID (integer), or position triple (xyz)
local function traceScreenRay(screenX, screenY, onlyCoords, useMinimap, includeSky, ignoreWater, heightOffset)
	-- Explicitly check onlyCoords because `TraceScreenRay` accepts arguments (screenX, screenY, heightOffset).
	local hiddenID = (onlyCoords ~= true) and not useMinimap and isVolumeHidden and selectedUnitID

	if hiddenID then
		restoreSelectionVolume(hiddenID)
	end

	local description, result = sp_TraceScreenRay(screenX, screenY, onlyCoords, useMinimap, includeSky, ignoreWater, heightOffset)

	if hiddenID then
		removeSelectionVolume(hiddenID)
	end

	return description, result
end

local function naiveRemoveSelectionVolume()
	if not isVolumeHidden and selectedUnitID and selectClickTime <= 0 and not inActiveCommand then
		removeSelectionVolume(selectedUnitID)
	end
end

local function naiveRestoreSelectionVolume()
	if isVolumeHidden and selectedUnitID then
		restoreSelectionVolume(selectedUnitID)
	end
end

function widget:Initialize()
	WG.SpringTraceScreenRay = sp_TraceScreenRay
	Spring.TraceScreenRay = traceScreenRay
	widgetHandler:RegisterGlobal("RemoveSelectionVolume", naiveRemoveSelectionVolume)
	widgetHandler:RegisterGlobal("RestoreSelectionVolume", naiveRestoreSelectionVolume)
end

function widget:Shutdown()
	naiveRestoreSelectionVolume()
	Spring.TraceScreenRay = sp_TraceScreenRay
	widgetHandler:DeregisterGlobal("RemoveSelectionVolume")
	widgetHandler:DeregisterGlobal("RestoreSelectionVolume")
end
