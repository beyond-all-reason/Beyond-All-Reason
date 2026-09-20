local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Air Flight Mode Labels",
		desc = "Debug: writes CRUISE or MANEUVER over every fixed-wing aircraft the engine flies with its agile flight regime. Toggle in the Air Flight Tuning panel or with /airmodelabels",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- A debug aid, not player UI: which of its two flight modes an aircraft is in right now, as the
-- engine reports it (Spring.GetUnitMoveTypeData(unitID).flightRegime, UnitFlightRegimeChanged).
-- On or off through WG.airFlightModeLabels, which the Air Flight Tuning panel has a switch for.

local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitRadius = Spring.GetUnitRadius
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetVisibleUnits = Spring.GetVisibleUnits
local spIsUnitIcon = Spring.IsUnitIcon

local glText = gl.Text
local glColor = gl.Color

local LABELS = {
	cruise = { text = "CRUISE", color = { 0.45, 0.85, 1.0, 0.95 } },
	agile = { text = "MANEUVER", color = { 1.0, 0.75, 0.25, 0.95 } },
}
local FONT_SIZE = 17 -- at 1080 lines of screen, scaled with the resolution
local MAX_LABELS = 250
local REFRESH_SECONDS = 0.5 -- for aircraft that changed mode before this widget could hear of it

local isStrafeAir = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	isStrafeAir[unitDefID] = unitDef.isStrafingAirUnit
end

local regimes = {} -- unitID -> "cruise" | "agile", only for aircraft that report one
local labelled = {} -- unitIDs in view, refreshed a few times a second
local sinceRefresh = math.huge

local fontScale = 1

local function enabled()
	return WG.airFlightModeLabels ~= false
end

local function readRegime(unitID)
	local moveType = spGetUnitMoveTypeData(unitID)
	-- (stock aircraft, and aircraft whose agile flight is switched off, have no mode to show)
	if moveType and moveType.agileFlight == true and LABELS[moveType.flightRegime] then
		return moveType.flightRegime
	end
	return nil
end

local function refresh()
	labelled = {}
	local count = 0
	local units = spGetVisibleUnits(-1, nil, false)
	for i = 1, #units do
		local unitID = units[i]
		if isStrafeAir[spGetUnitDefID(unitID) or -1] then
			regimes[unitID] = readRegime(unitID)
			if regimes[unitID] then
				count = count + 1
				labelled[count] = unitID
				if count >= MAX_LABELS then
					break
				end
			end
		end
	end
end

function widget:ViewResize()
	local _, vsy = Spring.GetViewGeometry()
	fontScale = math.max(0.75, (vsy or 1080) / 1080)
end

function widget:Initialize()
	widget:ViewResize()
	if WG.airFlightModeLabels == nil then
		WG.airFlightModeLabels = true
	end

	widgetHandler:AddAction("airmodelabels", function(_, _, params)
		local word = params and params[1]
		if word == "0" or word == "off" then
			WG.airFlightModeLabels = false
		elseif word == "1" or word == "on" then
			WG.airFlightModeLabels = true
		else
			WG.airFlightModeLabels = not enabled()
		end
		Spring.Echo("[airmodelabels] " .. (enabled() and "on" or "off"))
		return true
	end, nil, "t")
end

function widget:Shutdown()
	widgetHandler:RemoveAction("airmodelabels", "t")
end

-- the engine says so the moment an aircraft changes mode
function widget:UnitFlightRegimeChanged(unitID, unitDefID, unitTeam, regime)
	if regimes[unitID] ~= nil and LABELS[regime] then
		regimes[unitID] = regime
	end
end

function widget:UnitDestroyed(unitID)
	regimes[unitID] = nil
end

function widget:Update(dt)
	if not enabled() then
		return
	end
	sinceRefresh = sinceRefresh + dt
	if sinceRefresh >= REFRESH_SECONDS then
		sinceRefresh = 0
		refresh()
	end
end

function widget:DrawScreenEffects()
	if not enabled() or #labelled == 0 or Spring.IsGUIHidden() then
		return
	end

	for i = 1, #labelled do
		local unitID = labelled[i]
		local label = LABELS[regimes[unitID] or ""]
		if label then
			local x, y, z = spGetUnitViewPosition(unitID)
			if x then
				local sx, sy, sz = spWorldToScreenCoords(x, y + (spGetUnitRadius(unitID) or 20) * 1.2, z)
				if sz and sz < 1 then
					glColor(label.color)
					glText(label.text, sx, sy, (spIsUnitIcon(unitID) and FONT_SIZE * 0.8 or FONT_SIZE) * fontScale, "oc")
				end
			end
		end
	end
	glColor(1, 1, 1, 1)
end

function widget:GetConfigData()
	return { enabled = enabled() }
end

function widget:SetConfigData(data)
	if type(data) == "table" and data.enabled ~= nil then
		WG.airFlightModeLabels = (data.enabled == true)
	end
end
