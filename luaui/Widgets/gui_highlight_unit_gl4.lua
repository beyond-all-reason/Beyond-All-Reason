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
local fadeTime = 0.085

local vsx, vsy = Spring.GetViewGeometry()

local hidden = (Spring.GetGameFrame() <= hideBelowGameframe)
local selectedUnits = Spring.GetSelectedUnits()
local unitIsSelected = false

local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitTeam = Spring.GetUnitTeam

local unitshapes = {}
local fadeUnits = {}

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
	if not WG.HighlightUnitGL4 or not Spring.ValidUnitID(unitID) then
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
		local mult = 1
		if not unitshapes[unitID] then
			fadeUnits[unitID] = os.clock()
			mult = 0.13
		elseif fadeUnits[unitID] then
			if fadeUnits[unitID] > 0 then
				mult = 0.05 + (os.clock() - fadeUnits[unitID]) / fadeTime + ((1/Spring.GetFPS())/fadeTime)
				if mult >= 1 then
					mult = 1
					fadeUnits[unitID] = nil
				end
			else
				mult = 1 - ((os.clock() - math.abs(fadeUnits[unitID])) / fadeTime)
				if mult <= 0 then
					fadeUnits[unitID] = nil
				end
			end
		end
		if unitshapes[unitID] then
			WG.StopHighlightUnitGL4(unitshapes[unitID])
			unitshapes[unitID] = nil
		end
		if mult > 0 then
			unitshapes[unitID] = WG.HighlightUnitGL4(unitID, 'unitID', r,g,b, a*mult, (unitIsSelected and selectedEdgeAlpha or edgeAlpha)*mult, unitIsSelected and selectedEdgeExponent or edgeExponent, (unitIsSelected and selectedAnimationAlpha or animationAlpha) * mult)
			return unitshapes[unitID]
		end
	end
end

local function removeUnitShape(unitID, force)
	if not WG.StopHighlightUnitGL4 then
		widget:Shutdown()
	elseif unitID and unitshapes[unitID] then
		if force then
			WG.StopHighlightUnitGL4(unitshapes[unitID])
			unitshapes[unitID] = nil
			fadeUnits[unitID] = nil
		elseif not fadeUnits[unitID] then
			fadeUnits[unitID] = -os.clock()
		elseif fadeUnits[unitID] and fadeUnits[unitID] > 0 then
			local mult = 1 - ((os.clock() - math.abs(fadeUnits[unitID])) / fadeTime)
			fadeUnits[unitID] = -(os.clock() - (fadeTime * mult))
		end
	end
end

local function clearUnitshapes(keepUnitID, force)
	for unitID, _ in pairs(unitshapes) do
		if not keepUnitID or unitID ~= keepUnitID then
			removeUnitShape(unitID, force)
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

function widget:UnitDestroyed(unitID)
	if unitshapes[unitID] then
		removeUnitShape(unitID, true)
	end
end

function widget:SelectionChanged(sel)
	selectedUnits = sel
	processSelection()
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
end

function widget:Update()
	if hidden and Spring.GetGameFrame() > hideBelowGameframe then
		hidden = false
	end
	if WG.StopHighlightUnitGL4 then
		local mx, my = spGetMouseState()
		if mx == math.ceil(vsx/2) and my+1 == math.ceil(vsy/2) then	-- dont highlight unit when cursor is in center and we're likely camera-panning (cause I dont know how to detect that)
			clearUnitshapes(nil, true)
		else
			local type, data = spTraceScreenRay(mx, my)
			local unitID
			local addedUnitID
			if type == 'unit' and not Spring.IsGUIHidden() then
				unitID = data
				if not unitshapes[unitID] then
					addUnitShape(unitID)
					addedUnitID = unitID
				end
			end
			clearUnitshapes(unitID)

			for unitID, v in pairs(fadeUnits) do
				if unitID ~= addedUnitID then
					addUnitShape(unitID)
				end
			end
		end
	end
end

function widget:Initialize()
	if not WG.HighlightUnitGL4 then
		widgetHandler:RemoveWidget()
	end
end

function widget:Shutdown()
	if WG.StopHighlightUnitGL4 then
		clearUnitshapes(nil, true)
	end
end
