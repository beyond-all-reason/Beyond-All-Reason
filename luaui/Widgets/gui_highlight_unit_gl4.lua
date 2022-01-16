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

local hideBelowGameframe = 100
local highlightAlpha = 0.12
local selectedHighlightAlpha = 0.07
local edgeAlpha = 0.75
local selectedEdgeAlpha = 0.5
local edgeExponent = 1.25
local selectedEdgeExponent = 1.55
local animationAlpha = 0.55
local selectedAnimationAlpha = 0.4

local useTeamcolor = true
local teamColorAlphaMult = 1.25
local teamColorMinAlpha = 0.7

local hidden = (Spring.GetGameFrame() <= hideBelowGameframe)
local selectedUnits = Spring.GetSelectedUnits()
local unitIsSelected = false

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

local function isUnitSelected(unitID)
	for i, selUnitID in ipairs(selectedUnits) do
		if selUnitID == unitID then
			return true
		end
	end
	return false
end

local function addUnitShape(unitID)
	if not WG.HighlightUnitGL4 then
		widget:Shutdown()
	else
		local r,g,b
		unitIsSelected = isUnitSelected(unitID)
		local a = unitIsSelected and selectedHighlightAlpha or highlightAlpha
		if useTeamcolor then
			local teamID = spGetUnitTeam(unitID)
			if teamID then
				r, g, b = teamColor[teamID][1], teamColor[teamID][2], teamColor[teamID][3]
				a = a * teamColorAlphaMult
			end
		end
		unitshapes[unitID] = WG.HighlightUnitGL4(unitID, 'unitID', r,g,b, a, unitIsSelected and selectedEdgeAlpha or edgeAlpha, unitIsSelected and selectedEdgeExponent or edgeExponent, unitIsSelected and selectedAnimationAlpha or animationAlpha)
		return unitshapes[unitID]
	end
end

local function removeUnitShape(unitID)
	if not WG.StopHighlightUnitGL4 then
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

local function processSelection()
	local prevUnitIsSelected = unitIsSelected
	unitIsSelected = false
	for unitID, v in next, unitshapes, nil do
		if isUnitSelected(unitID) then
			unitIsSelected = true
		end
		if prevUnitIsSelected ~= unitIsSelected then
			removeUnitShape(unitID)
			addUnitShape(unitID)
		end
	end
end

function widget:SelectionChanged(sel)
	selectedUnits = sel
	processSelection()
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
