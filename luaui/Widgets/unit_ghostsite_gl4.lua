local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Ghost Site GL4",
		desc = "Displays ghosted buildings for buildings in progress", -- engine nowadays already draws it, but we can add a highlight effect to distinct it!
		author = "very_bad_soldier, Bluestone, Floris (GL4)",
		date = "April 7, 2009",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spGetSpectatingState = Spring.GetSpectatingState

local shapeOpacity = 0.15
local highlightAmount = 0.11
local updateFrames = 30 -- sim frames between site checks

local spGetUnitDefID = Spring.GetUnitDefID
local spIsUnitAllied = Spring.IsUnitAllied
local spGetUnitDirection = Spring.GetUnitDirection
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitRadius = Spring.GetUnitRadius
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spIsPosInLos = Spring.IsPosInLos
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetTeamAllyTeamID = Spring.GetTeamAllyTeamID
local math_deg = math.deg
local math_atan2 = math.atan2
local math_rad = math.rad

local ghostSites = {} ---@type table<UnitID, table?>
local siteCount = 0
local unitshapes = {} ---@type table<UnitID, integer?>
local _, fullview = spGetSpectatingState()
local myAllyTeamID = spGetMyAllyTeamID()
local shapeApi ---@type function? WG.DrawUnitShapeGL4 of the instance that issued our shape handles

-- the textures DrawUnitShape GL4 has shape buckets for
---@type table<string, boolean?>
local shapeTextures =
	{ ["arm_color.dds"] = true, ["cor_color.dds"] = true, ["leg_color.dds"] = true, ["legmech_color.dds"] = true }

local includedUnitDefIDs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isBuilding then
		local model = unitDef.model -- a new table on every access
		local tex1 = model and model.textures and model.textures.tex1
		if tex1 and shapeTextures[tex1:lower()] then
			includedUnitDefIDs[unitDefID] = true
		end
	end
end

-- a reloaded DrawUnitShape does not know our handles anymore
local function shapeApiValid()
	if shapeApi ~= nil and WG.DrawUnitShapeGL4 == shapeApi then
		return true
	end
	if shapeApi ~= nil then
		shapeApi = nil
		widgetHandler:RemoveWidget()
	end
	return false
end

local function removeUnitShape(unitID)
	local shape = unitshapes[unitID]
	if shape then
		unitshapes[unitID] = nil
		if shapeApiValid() then
			WG.StopDrawUnitShapeGL4(shape)
		end
	end
end

local function addUnitShape(unitID, site)
	removeUnitShape(unitID)
	if shapeApiValid() then
		unitshapes[unitID] = WG.DrawUnitShapeGL4(
			site.unitDefID,
			site.x,
			site.y + 0.1,
			site.z,
			math_rad(site.angle),
			shapeOpacity,
			site.teamID,
			0,
			highlightAmount
		)
	end
end

-- UnitEnteredLos runs unless spectating with fullview, UnitLeftLos and GameFrame only while there are sites
local trackingCallIns, siteCallIns = true, true

local function updateCallIns()
	local tracking = not fullview
	if tracking ~= trackingCallIns then
		trackingCallIns = tracking
		if tracking then
			widgetHandler:UpdateCallIn("UnitEnteredLos")
		else
			widgetHandler:RemoveCallIn("UnitEnteredLos")
		end
	end
	local sites = tracking and siteCount > 0
	if sites ~= siteCallIns then
		siteCallIns = sites
		if sites then
			widgetHandler:UpdateCallIn("UnitLeftLos")
			widgetHandler:UpdateCallIn("GameFrame")
		else
			widgetHandler:RemoveCallIn("UnitLeftLos")
			widgetHandler:RemoveCallIn("GameFrame")
		end
	end
end

local function removeSite(unitID)
	removeUnitShape(unitID)
	ghostSites[unitID] = nil
	siteCount = siteCount - 1
	updateCallIns()
end

local function clearSites()
	for unitID in pairs(unitshapes) do
		removeUnitShape(unitID)
	end
	ghostSites = {}
	siteCount = 0
	updateCallIns()
end

function widget:UnitEnteredLos(unitID, teamID)
	local site = ghostSites[unitID]
	local unitDefID = spGetUnitDefID(unitID)
	if includedUnitDefIDs[unitDefID] and spGetUnitIsBeingBuilt(unitID) and not spIsUnitAllied(unitID) then
		local x, y, z, _, midY = spGetUnitPosition(unitID, true)
		local dx, _, dz = spGetUnitDirection(unitID)
		removeUnitShape(unitID)
		if not site then
			siteCount = siteCount + 1
		end
		ghostSites[unitID] = {
			unitDefID = unitDefID,
			x = x,
			y = y,
			z = z,
			teamID = teamID,
			angle = math_deg(math_atan2(dx, dz)),
			-- fully submerged units also need sonar to be seen, LOS on their spot proves nothing
			underwater = midY + (spGetUnitRadius(unitID) or 0) < 0,
		}
		updateCallIns()
	elseif site then
		-- finished, captured, or its unitID was reused
		removeSite(unitID)
	end
end

function widget:UnitLeftLos(unitID, unitTeam)
	local site = ghostSites[unitID]
	if site then
		addUnitShape(unitID, site)
	end
end

-- forget sites that finished or died in sight, and those whose spot is back in LOS without the unit showing up
-- (the engine drops its own ghosts of dead buildings the same way)
function widget:GameFrame(n)
	if n % updateFrames ~= 0 or not shapeApiValid() then
		return
	end
	for unitID, site in pairs(ghostSites) do
		if unitshapes[unitID] then
			if not site.underwater and spIsPosInLos(site.x, site.y, site.z) then
				removeSite(unitID)
			end
		elseif not spGetUnitIsBeingBuilt(unitID) then
			removeSite(unitID)
		end
	end
end

-- sites were recorded through the previous view's LOS
function widget:PlayerChanged()
	local _, newFullview = spGetSpectatingState()
	local newAllyTeamID = spGetMyAllyTeamID()
	if newFullview ~= fullview or newAllyTeamID ~= myAllyTeamID then
		fullview, myAllyTeamID = newFullview, newAllyTeamID
		clearSites()
	end
end

-- remove ghostsites for dead allyteams
function widget:TeamDied(teamID)
	-- Check if the entire allyteam is dead before removing ghost sites
	local allyTeamID = spGetTeamAllyTeamID(teamID)
	local allyTeamList = Spring.GetTeamList(allyTeamID)
	if not allyTeamList then
		return
	end

	-- Check if all teams in this allyteam are dead
	local allyTeamDead = true
	for _, checkTeamID in ipairs(allyTeamList) do
		-- Check if team is still alive (not dead)
		if checkTeamID ~= teamID and not select(3, Spring.GetTeamInfo(checkTeamID, false)) then
			allyTeamDead = false
			break
		end
	end

	-- Only remove ghost sites if the entire allyteam is dead
	if allyTeamDead then
		for unitID, site in pairs(ghostSites) do
			if spGetTeamAllyTeamID(site.teamID) == allyTeamID then
				removeSite(unitID)
			end
		end
	end
end

function widget:Initialize()
	shapeApi = WG.DrawUnitShapeGL4
	if shapeApi == nil then
		widgetHandler:RemoveWidget()
		return
	end
	if fullview then
		ghostSites = {}
	end
	for unitID, site in pairs(ghostSites) do
		siteCount = siteCount + 1
		if not spIsPosInLos(site.x, site.y, site.z) then
			addUnitShape(unitID, site)
		end
	end
	updateCallIns()
end

function widget:Shutdown()
	if shapeApi ~= nil and WG.DrawUnitShapeGL4 == shapeApi then
		for _, shape in pairs(unitshapes) do
			WG.StopDrawUnitShapeGL4(shape)
		end
	end
end

function widget:GetConfigData()
	return {
		ghostSites = ghostSites,
	}
end

function widget:SetConfigData(data)
	-- only before Initialize: a running widget's site count and shapes would no longer match
	if shapeApi == nil and Spring.GetGameFrame() > 0 and data.ghostSites ~= nil then
		ghostSites = data.ghostSites
	end
end
