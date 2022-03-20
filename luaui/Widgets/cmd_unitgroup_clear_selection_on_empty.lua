
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

local function OnGroupSelected(cmd)
	if spGetGroupUnitsCount(string.sub(cmd, 6, 6)) == 0 then
		spSelectUnitMap({}, false)
	end

	return true
end

local function ManageAction(doAdd)
	for i = 0, 9 do
		if doAdd then
			widgetHandler:AddAction("group" .. i, OnGroupSelected)
		else
			widgetHandler:RemoveAction("group" .. i, OnGroupSelected)
		end
	end
end

function widget:Initialize()
	ManageAction(true)
end

function widget:Shutdown()
	ManageAction(false)
end
