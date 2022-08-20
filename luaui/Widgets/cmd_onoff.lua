function widget:GetInfo()
	return {
		name = "Onoff for Hound and trajectory",
		desc = "onoff action will now work with units affected by the cmd_onoffdesc.lua",
		author = "Lexon",
		date = "19.08.2022",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true, --enabled by default
	}
end

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitStates = Spring.GetUnitStates
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local function onoff()
	local selectedUnits = spGetSelectedUnits()

	if selectedUnits[1] == nil then return end

	local weapon = spGetUnitStates(selectedUnits[1])["active"]

	if weapon == true then
		weapon = 0
	elseif weapon == false then
		weapon = 1
	else
		return
	end

	for _, unit in pairs(selectedUnits) do
		spGiveOrderToUnit(unit, CMD.ONOFF, { weapon }, 0)
	end

	return true
end

function widget:Initialize()
	widgetHandler:AddAction("onoff", onoff, nil, "t")
end