function widget:GetInfo()
	return {
		name = "Highlight Unit GL4",
		desc = "Highlights the unit or feature under the cursor",
		author = "Floris (original: trepan)",
		date = "January 2022",
		license = "GNU GPL, v2 or later",
		layer = -10000,
		enabled = true  --  loaded by default?
	}
end

local hideBelowGameframe = 100

local highlightAlpha = 0.1
local selectedHighlightAlpha = 0.09

local edgeAlpha = 1
local selectedEdgeAlpha = 0.75

local edgeExponent = 1.2
local selectedEdgeExponent = 1.45

local animationAlpha = 0.7
local selectedAnimationAlpha = 0.5

local useTeamcolor = true
local teamColorAlphaMult = 1.25
local teamColorMinAlpha = 0.7

local vsx, vsy = Spring.GetViewGeometry()

local selectedUnits = Spring.GetSelectedUnits()
local unitIsSelected = false

local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitTeam = Spring.GetUnitTeam

-- Beherith says: There can only be one!
local highlightunitID = nil
local highlightID = nil

local visibleUnits = {} -- table maintained based on unit tracker API calls

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

local function removeUnitShape()
	if not WG.StopHighlightUnitGL4 then
		widget:Shutdown("No API")
	elseif highlightunitID and highlightID then
		WG.StopHighlightUnitGL4(highlightID)
		highlightunitID = nil
		highlightID = nil
	end
end

local function addUnitShape(unitID)
	if (not Spring.ValidUnitID(unitID)) or (Spring.GetUnitIsDead(unitID) ~= false) or (visibleUnits[unitID] == nil) then
		-- remove old and bail
		removeUnitShape()
		return
	end
	if not WG.HighlightUnitGL4  then
		widget:Shutdown("No API")
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

		if highlightunitID or highlightID then
			removeUnitShape()
		end

		highlightunitID = unitID
		highlightID =  WG.HighlightUnitGL4(unitID, 'unitID', r,g,b, a,
				(unitIsSelected and selectedEdgeAlpha or edgeAlpha),
				(unitIsSelected and selectedEdgeExponent or edgeExponent),
				(unitIsSelected and selectedAnimationAlpha or animationAlpha),
				0,0,0,0,"mouseover")
		return highlightID
	end
end


local function processSelection()
	local prevUnitIsSelected = unitIsSelected
	unitIsSelected = isUnitSelected(highlightunitID)
	if highlightunitID and unitIsSelected ~= prevUnitIsSelected then
		addUnitShape(highlightunitID)
	end
end

function widget:SelectionChanged(sel)
	selectedUnits = sel
	processSelection()
end


function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam) -- E.g. when a unit dies
	visibleUnits[unitID] = unitDefID
end

function widget:VisibleUnitRemoved(unitID) -- E.g. when a unit dies
	if highlightunitID == unitID then
		removeUnitShape()
	end
	visibleUnits[unitID] = nil
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	-- Called when players are changed, better remove all of them now!
	visibleUnits = {}
	for unitID, unitDefID in pairs(extVisibleUnits) do
			visibleUnits[unitID] = unitDefID
	end
	removeUnitShape()
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
end

function widget:Update()
	if WG.StopHighlightUnitGL4 then
		local mx, my, _, mmb, _, mouseOffScreen, cameraPanMode  = spGetMouseState()
		if mouseOffScreen or cameraPanMode or mmb then
			removeUnitShape()
		else
			local type, data = spTraceScreenRay(mx, my)
			local unitID
			if type == 'unit' and not Spring.IsGUIHidden() then
				unitID = data
				if highlightunitID ~= unitID then
					addUnitShape(unitID)
				end
			else
				removeUnitShape()
			end

		end
	end
end

function widget:Initialize()
	if (not WG.HighlightUnitGL4) or (not WG['unittrackerapi']) then
		Spring.Echo("Highlight Unit GL4 requires WG.HighlightUnitGL4 and WG.unittrackerapi")
		widgetHandler:RemoveWidget()
	end
	widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
end

function widget:Shutdown(reason)
	Spring.Echo("Highlight Unit Widget Exiting", reason)
	if WG.StopHighlightUnitGL4 then
		removeUnitShape()
	end
end
