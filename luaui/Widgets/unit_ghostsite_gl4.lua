local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Ghost Site GL4",
		desc      = "Displays ghosted buildings for buildings in progress",	-- engine nowadays already draws it, but we can add a highlight effect to distinct it!
		author    = "very_bad_soldier, Bluestone, Floris (GL4)",
		date      = "April 7, 2009",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

local shapeOpacity = 0.15
local highlightAmount = 0.11
local updateRate = 1

local spGetUnitDefID = Spring.GetUnitDefID
local spIsUnitAllied = Spring.IsUnitAllied
local spGetUnitDirection = Spring.GetUnitDirection
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetPositionLosState = Spring.GetPositionLosState
local math_deg = math.deg
local math_atan2 = math.atan2
local math_rad = math.rad

local sec = 0
local ghostSites = {}
local unitshapes = {}
local spec,specFullView = Spring.GetSpectatingState()

local includedUnitDefIDs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isBuilding then
		if unitDef.model and unitDef.model.textures and unitDef.model.textures.tex1:lower() == "arm_color.dds" then
			includedUnitDefIDs[unitDefID] = true
		elseif unitDef.model and unitDef.model.textures and unitDef.model.textures.tex1:lower() == "cor_color.dds" then
			includedUnitDefIDs[unitDefID] = true
		end
	end
end

local function removeUnitShape(unitID)
	if unitshapes[unitID] then
		WG.StopDrawUnitShapeGL4(unitshapes[unitID])
		unitshapes[unitID] = nil
	end
end

local function addUnitShape(unitID, unitDefID, px, py, pz, rotationY, teamID)
	if unitshapes[unitID] then
		removeUnitShape(unitID)
	end
	unitshapes[unitID] = WG.DrawUnitShapeGL4(unitDefID, px, py+0.1, pz, math_rad(rotationY), shapeOpacity, teamID, nil, highlightAmount)
	return unitshapes[unitID]
end

function widget:UnitEnteredLos(unitID, teamID)
	if ghostSites[unitID] then
		removeUnitShape(unitID)
	end
	if specFullView or spIsUnitAllied(unitID) then
		return
	end
    local unitDefID = spGetUnitDefID(unitID)
	if includedUnitDefIDs[unitDefID] and Spring.GetUnitIsBeingBuilt(unitID) then
		local x, y, z = spGetUnitBasePosition(unitID)
		local dx,_,dz = spGetUnitDirection(unitID)
		local angle = math_deg(math_atan2(dx,dz))
		ghostSites[unitID] = { unitDefID=unitDefID, x=x, y=y, z=z, teamID=teamID, angle=angle }
	end
end

function widget:UnitLeftLos(unitID, unitTeam)
	if ghostSites[unitID] then
		local site = ghostSites[unitID]
		addUnitShape(unitID, site.unitDefID, site.x, site.y, site.z, site.angle, site.teamID)
	end
end

-- check is units are still under construction
local function updateGhostSites()
	for unitID, site in pairs(ghostSites) do
		if not unitshapes[unitID] then
			local _,inLos,_ = spGetPositionLosState(site.x, site.y, site.z)
			if inLos and not Spring.GetUnitIsBeingBuilt(unitID) then
				removeUnitShape(unitID)
				ghostSites[unitID] = nil
			end
		end
	end
end

function widget:Update(dt)
	if specFullView then return end
	if not WG.DrawUnitShapeGL4 then
		widgetHandler:RemoveWidget()
	end
	sec = sec + dt
	if sec > updateRate then
		sec = 0
		updateGhostSites()
	end
end

function widget:PlayerChanged()
	spec,specFullView = Spring.GetSpectatingState()
	if specFullView then
		for unitID, _ in pairs(unitshapes) do
			removeUnitShape(unitID)
		end
	end
end

function widget:Initialize()
	if not WG.DrawUnitShapeGL4 then
		widgetHandler:RemoveWidget()
	end
	for unitID, site in pairs(ghostSites) do
		local _,inLos,_ = spGetPositionLosState(site.x, site.y, site.z)
		if not inLos then
			addUnitShape(unitID, site.unitDefID, site.x, site.y, site.z, site.angle, site.teamID)
		end
	end
end

function widget:Shutdown()
	if WG.StopDrawUnitShapeGL4 then
		for unitID, _ in pairs(unitshapes) do
			removeUnitShape(unitID)
		end
	end
end

function widget:GetConfigData()
	return {
		ghostSites = ghostSites,
	}
end

function widget:SetConfigData(data)
	if Spring.GetGameFrame() > 0 and data.ghostSites ~= nil then
		ghostSites = data.ghostSites
	end
end
