local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Cycle Selected Units",
		desc = "Cycle camera focus through each unit in the current selection",
		author = "Zaffer",
		date = "April 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end


-- We use unitIndex as a cursor for cycling on subsequent triggers
local unitIndex = 0

-- Snapshot of the selection we're cycling through
local cycleUnits = {}

local function selectionChanged(currentSel)
	if #currentSel ~= #cycleUnits then
		return true
	end
	local currentSet = {}
	for _, uid in ipairs(currentSel) do
		currentSet[uid] = true
	end
	for _, uid in ipairs(cycleUnits) do
		if not currentSet[uid] then
			return true
		end
	end
	return false
end

local function resetCycle(currentSel)
	-- Copy before sorting so we don't mutate the caller's table
	cycleUnits = {}
	for i = 1, #currentSel do
		cycleUnits[i] = currentSel[i]
	end
	table.sort(cycleUnits)
	unitIndex = 0
end

local function focusUnit(unitID)
	local x, y, z = Spring.GetUnitPosition(unitID)
	if x then
		Spring.SetCameraTarget(x, y, z)
		return true
	end
	return false
end

local function handleCycleSelected(_, _, _, data)
	local currentSel = Spring.GetSelectedUnits()
	if #currentSel < 1 then
		return
	end

	if selectionChanged(currentSel) then
		resetCycle(currentSel)
	end

	local unitCount = #cycleUnits
	if unitCount < 1 then
		return
	end

	local direction = (data and data.direction) or 1

	-- Try up to unitCount times in case some IDs became invalid
	for _ = 1, unitCount do
		-- Advance cursor, wrapping around in either direction
		unitIndex = ((unitIndex - 1 + direction) % unitCount) + 1
		if focusUnit(cycleUnits[unitIndex]) then
			break
		end
	end

	-- Halt the action chain
	return true
end

function widget:Shutdown()
	widgetHandler:RemoveAction("cycleselected")
	widgetHandler:RemoveAction("cycleselected_prev")
end

function widget:Initialize()
	widgetHandler:AddAction("cycleselected", handleCycleSelected, { direction = 1 }, "p")
	widgetHandler:AddAction("cycleselected_prev", handleCycleSelected, { direction = -1 }, "p")
end
