function widget:GetInfo()
	return {
		name = "Under Construction gfx GL4",
		desc = "",
		author = "Floris",
		date = "May 2018",
		license = "GPL",
		layer = 0,
		enabled = true
	}
end

local highlightAlpha = 0.33
local edgeExponent = 1.4
local edgeAlpha = 0.6

local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitHealth = Spring.GetUnitHealth
local prevMyAllyTeamID = Spring.GetMyAllyTeamID()
local mySpec, prevMyFullView = Spring.GetSpectatingState()
local unitshapes = {}

local teamColor = {}
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local r, g, b = Spring.GetTeamColor(teams[i])
	local min = 0.12
	teamColor[teams[i]] = { math.max(r, min), math.max(g, min), math.max(b, min) }
end
teams = nil

local function addUnitShape(unitID)
	if not WG.DrawUnitShapeGL4 then
		widget:Shutdown()
	else
		local teamID = spGetUnitTeam(unitID)
		local r, g, b = teamColor[teamID][1], teamColor[teamID][2], teamColor[teamID][3]
		unitshapes[unitID] = WG.HighlightUnitGL4(unitID, 'unitID', r, g, b, highlightAlpha, edgeAlpha, edgeExponent)
		return unitshapes[unitID]
	end
end

local function removeUnitShape(unitID)
	if not WG.StopDrawUnitShapeGL4 then
		widget:Shutdown()
	elseif unitID and unitshapes[unitID] then
		WG.StopHighlightUnitGL4(unitshapes[unitID])
		unitshapes[unitID] = nil
	end
end

local function refresh()
	for unitID, _ in pairs(unitshapes) do
		removeUnitShape(unitID)
	end
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local buildProgress = select(5, spGetUnitHealth(unitID))
		if buildProgress and buildProgress < 1 then
			widget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), spGetUnitTeam(unitID))
		end
	end
end

function widget:Initialize()
	if not WG.HighlightUnitGL4 then
		widgetHandler:RemoveWidget()
	end
	refresh()
end

function widget:Shutdown()
	if WG.StopHighlightUnitGL4 then
		for id, _ in pairs(unitshapes) do
			removeUnitShape(id)
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	local buildProgress = select(5, spGetUnitHealth(unitID))
	if buildProgress and buildProgress < 1 then
		addUnitShape(unitID)
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if unitshapes[unitID] then
		removeUnitShape(unitID)
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if unitshapes[unitID] then
		removeUnitShape(unitID)
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitshapes[unitID] then
		removeUnitShape(unitID)
	end
end

function widget:Update(dt)
	if Spring.GetMyAllyTeamID() ~= prevMyAllyTeamID or select(2, Spring.GetSpectatingState()) ~= prevMyFullView then
		prevMyAllyTeamID = Spring.GetMyAllyTeamID()
		refresh()
	end
end
