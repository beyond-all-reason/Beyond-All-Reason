function widget:GetInfo()
	return {
		name = "Highlight Unit GL4",
		desc = "Highlights the unit or feature under the cursor",
		author = "Floris (original: trepan)",
		date = "January 2022",
		license = "GNU GPL, v2 or later",
		layer = 5,
		enabled = true  --  loaded by default?
	}
end

local highlightAlpha = 0.08
local edgeAlpha = 0.5
local edgeExponent = 1.2
local hideBelowGameframe = 100
local useTeamcolor = true
local teamColorAlphaMult = 1.25
local teamColorMinAlpha = 0.7
local animationAlpha = 0.4

local hidden = (Spring.GetGameFrame() <= hideBelowGameframe)

local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitTeam = Spring.GetUnitTeam

local unitshapes = {}

local teamColor = {}
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local r, g, b = Spring.GetTeamColor(teams[i])
	local min = teamColorMinAlpha
	teamColor[teams[i]] = { math.max(r, min), math.max(g, min), math.max(b, min) }
end
teams = nil

local function addUnitShape(unitID)
	if not WG.DrawUnitShapeGL4 then
		widget:Shutdown()
	else
		local r,g,b
		local a = highlightAlpha
		if useTeamcolor then
			local teamID = spGetUnitTeam(unitID)
			if teamID then
				r, g, b = teamColor[teamID][1], teamColor[teamID][2], teamColor[teamID][3]
				a = a * teamColorAlphaMult
			end
		end
		unitshapes[unitID] = WG.HighlightUnitGL4(unitID, 'unitID', r,g,b, a, edgeAlpha, edgeExponent, animationAlpha)
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

local function clearUnitshapes(keepUnitID)
	for unitID, _ in pairs(unitshapes) do
		if not keepUnitID or unitID ~= keepUnitID then
			removeUnitShape(unitID)
		end
	end
end

function widget:Update()
	if hidden and Spring.GetGameFrame() > hideBelowGameframe then
		hidden = false
	end
	if WG.StopHighlightUnitGL4 then
		local mx, my = spGetMouseState()
		local type, data = spTraceScreenRay(mx, my)
		local unitID
		if type == 'unit' then
			unitID = data
			if not unitshapes[unitID] then
				addUnitShape(unitID)
			end
		end
		clearUnitshapes(unitID)
	end
end

function widget:Initialize()
	if not WG.HighlightUnitGL4 then
		widgetHandler:RemoveWidget()
	end
end

function widget:Shutdown()
	if WG.StopHighlightUnitGL4 then
		clearUnitshapes()
	end
end

function widget:UnitDestroyed(unitID)	-- maybe not needed if widget:SelectionChanged(sel) is fast enough, but lets not risk it
	if unitshapes[unitID] then
		removeUnitShape(unitID)
	end
end
