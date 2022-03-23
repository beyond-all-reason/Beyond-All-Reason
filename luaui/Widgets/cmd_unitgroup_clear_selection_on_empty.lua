
function widget:GetInfo()
	return {
		name = "Unit Groups - Clear selection on empty",
		desc = "Clears selection when selecting an empty unit group",
		author = "verybadsoldier",
		date = "2021-10-10",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true  --  loaded by default
	}
end

local spGetGroupUnitsCount = Spring.GetGroupUnitsCount
local spSelectUnitMap = Spring.SelectUnitMap
local spGetModKeyState = Spring.GetModKeyState

local function OnGroupSelected(cmd)
	local alt, ctrl, meta, shift = spGetModKeyState()

	-- When ctrl engine handles for group assignment, when any other mod key let
	-- it be handled elsewhere
	if ctrl or alt or meta or shift then return end

	if spGetGroupUnitsCount(string.sub(cmd, 6, 6)) == 0 then
		spSelectUnitMap({}, false)
	end

	return true
end

local function ManageAction(doAdd)
	for i = 0, 9 do
		if doAdd then
			widgetHandler:AddAction("group" .. i, OnGroupSelected, nil, 'p')
		else
			widgetHandler:RemoveAction("group" .. i, OnGroupSelected, 'p')
		end
	end
end

function widget:Initialize()
	ManageAction(true)
end

function widget:Shutdown()
	ManageAction(false)
end
