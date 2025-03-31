local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Unit Groups - Clear selection on empty",
		desc = "Clears selection when selecting an empty unit group",
		author = "verybadsoldier",
		date = "2021-10-10",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

local spGetGroupUnitsCount = Spring.GetGroupUnitsCount
local spSelectUnitMap = Spring.SelectUnitMap
local spGetModKeyState = Spring.GetModKeyState

local function ClearSelectionIfGroupSelected(groupIndex)
	if spGetGroupUnitsCount(groupIndex) > 0 then return end

	spSelectUnitMap({}, false)
end

local function OnGroupSelected(_, _, args)
	if not args then return end

	local unitGroupArgIdx = 1
	-- variant: if "select" is first argument, then unit group is second
	if args[1] == "select" then
		unitGroupArgIdx = 2
	end

	local groupIndex = tonumber(args[unitGroupArgIdx])

	-- 2nd arg can also be e.g. "set" - but we only want to react to a selection
	if not groupIndex then return end

	ClearSelectionIfGroupSelected(groupIndex)
end

local function OnGroupNSelected(cmd)
	local alt, ctrl, meta, shift = spGetModKeyState()

	-- When ctrl engine handles for group assignment, when any other mod key let
	-- it be handled elsewhere
	if ctrl or alt or meta or shift then return end

	local groupIndex = tonumber(string.sub(cmd, 6, 6))

	if not groupIndex then return end

	ClearSelectionIfGroupSelected(groupIndex)
end

local function ManageAction(doAdd)
	-- Support old group actions in format groupN
	for i = 0, 9 do
		if doAdd then
			widgetHandler:AddAction("group" .. i, OnGroupNSelected, nil, 'p')
		else
			widgetHandler:RemoveAction("group" .. i, OnGroupNSelected, 'p')
		end
	end

	if doAdd then
		widgetHandler:AddAction("group", OnGroupSelected, nil, 'p')
	else
		widgetHandler:RemoveAction("group", OnGroupSelected, 'p')
	end
end

function widget:Initialize()
	ManageAction(true)
end

function widget:Shutdown()
	ManageAction(false)
end
