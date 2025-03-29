local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Onoff for Hound and trajectory",
		desc = "onoff action will now work with units affected by the cmd_onoffdesc.lua",
		author = "Lexon",
		date = "19.08.2022",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetUnitStates = Spring.GetUnitStates
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local unitOnOffable = {}
for udid, ud in pairs(UnitDefs) do
	unitOnOffable[udid] = ud.onOffable
end

local function onoff(_, _, args)
	local state = args[1]
	if state ~= nil and (state ~= "0" and state ~= "1") then return end

	-- Should return { [number unitDefID] = { [1] = [number unitID], etc... }, ... }
	local selectedUnitsSorted = spGetSelectedUnitsSorted()
	local anyOnOffable = false

	for unitDefId, units in pairs(selectedUnitsSorted) do
		if unitOnOffable[unitDefId] then
			anyOnOffable = true

			if state == nil then
				local isActive = spGetUnitStates(units[1])["active"]
				if isActive then state = 0 else state = 1 end
			end

			for _, unit in pairs(units) do
				spGiveOrderToUnit(unit, CMD.ONOFF, { state }, 0)
			end
		end
	end
	return anyOnOffable		-- we only halt the chain when at least one unit responds to this action
end

function widget:Initialize()
	widgetHandler:AddAction("onoff", onoff, nil, "p")
end
