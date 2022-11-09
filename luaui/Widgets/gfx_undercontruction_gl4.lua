function widget:GetInfo()
	return {
		name = "Under Construction gfx GL4",
		desc = "",
		author = "Floris, Beherith",
		date = "May 2018",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

local highlightAlpha = 0.4
local edgeExponent = 1.45
local edgeAlpha = 0.55
local animAmount = 0.3

local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitHealth = Spring.GetUnitHealth
local unitshapes = {}

local teamColor = {}
local function loadTeamColors()
	local teams = Spring.GetTeamList()
	for i = 1, #teams do
		local r, g, b = Spring.GetTeamColor(teams[i])
		local min = 0.12
		teamColor[teams[i]] = { math.max(r, min), math.max(g, min), math.max(b, min) }
	end
end

function widget:Initialize()
	if (not WG.HighlightUnitGL4) or (not WG['unittrackerapi']) then
		Spring.Echo("Under Construction gfx GL4 requires WG.HighlightUnitGL4 and WG.unittrackerapi")
		widgetHandler:RemoveWidget()
	end
	loadTeamColors()
	widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	widget:Shutdown()
	for unitID, unitDefID in pairs(extVisibleUnits) do 
		widget:VisibleUnitAdded(unitID, unitDefID)
	end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	local buildProgress = select(5, spGetUnitHealth(unitID))
	if buildProgress and buildProgress < 1 then
		local teamID = unitTeam or spGetUnitTeam(unitID) -- as unitTeam is passed except on VisibleUnitsChanged
		local r, g, b = teamColor[teamID][1], teamColor[teamID][2], teamColor[teamID][3]
		unitshapes[unitID] = WG.HighlightUnitGL4(unitID, 'unitID', r, g, b, highlightAlpha, edgeAlpha, edgeExponent, animAmount)
	end
end

function widget:VisibleUnitRemoved(unitID) 
	if unitID and unitshapes[unitID] then
		WG.StopHighlightUnitGL4(unitshapes[unitID])
		unitshapes[unitID] = nil
	end
end

function widget:Shutdown()
	for unitID, _ in pairs(unitshapes) do
		widget:VisibleUnitRemoved(unitID, true)
	end
	WG.RefreshHighlightUnitGL4()
end
