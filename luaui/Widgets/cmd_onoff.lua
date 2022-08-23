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
local spGetUnitDefID = Spring.GetUnitDefID

local function onoff()
	local selectedUnits = spGetSelectedUnits()
	local firstOnoff = nil

	for _, unit in pairs(selectedUnits) do
		local unitDefID = spGetUnitDefID(unit)

		if UnitDefs[unitDefID].onOffable then
			if firstOnoff == nil then
				local isActive = spGetUnitStates(unit)["active"]
				if isActive then firstOnoff = 0 else firstOnoff = 1 end
			end
			spGiveOrderToUnit(unit, CMD.ONOFF, { firstOnoff }, 0)
		end
	end
	return true
end

function widget:Initialize()
	widgetHandler:AddAction("onoff", onoff, nil, "t")
end
