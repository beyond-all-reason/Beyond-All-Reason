local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Quick Build (mex/geo)",
		desc = "Adds ability to quickly place or upgrade mex/geothermal by right clicking.",
		author = "Hobo Joe, based on work by Google Frog, NTG, Chojin, Doo, Floris, and Tarte",
		version = "1.0",
		date = "Jan 2024",
		license = "GNU GPL, v2 or later",
		layer = 1000,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spTraceScreenRay = SpringUnsynced.TraceScreenRay
local spGetMouseState = SpringUnsynced.GetMouseState
local spSetMouseCursor = SpringUnsynced.SetMouseCursor
local spGetModKeyState = SpringUnsynced.GetModKeyState

local CMD_RECLAIM = CMD.RECLAIM

local spGetActiveCommand = SpringUnsynced.GetActiveCommand
local spGetUnitDefID = SpringShared.GetUnitDefID
local spGetUnitPosition = SpringShared.GetUnitPosition

local mathAbs = math.abs
local mathHuge = math.huge
local mathDistance2dSquared = math.distance2dSquared
local mathPiHalf = math.pi / 2

-- These are arbitrary values that feel right - basing this on the ever-changing values of mex radius results in a really confusing experience
local geoPlacementRadius = 5000
local mexPlacementRadius = 2000

local mexConstructors
local geoConstructors
local mexBuildings
local geoBuildings

local bestGeo
local bestMex

local unitShape = false
local activeShape

local selectedSpot
local selectedPos
local selectedMex
local selectedGeo

local metalMap = false
local buildCmd = {}

-- Pre-allocated reusable tables to avoid per-update allocations
local reusePos = { x = 0, y = 0, z = 0 }
local reuseCmdPos = { 0, 0, 0 }
local reuseUnitShape = { 0, 0, 0, 0, 0, 0 }

local updateTime = 0
local lastMx, lastMy = -1, -1
local selectionDirty = true

local isCloakableBuilder = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.buildOptions[1] and unitDef.canCloak then
		isCloakableBuilder[unitDefID] = true
	end
end
local spGetUnitStates = SpringShared.GetUnitStates
local function unitIsCloaked(uDefId)
	return isCloakableBuilder[spGetUnitDefID(uDefId)] and select(5, spGetUnitStates(uDefId, false, true))
end

local spotFinder
local spotBuilder

function widget:Initialize()
	if not WG.DrawUnitShapeGL4 then
		widgetHandler:RemoveWidget()
	end

	spotBuilder = WG.resource_spot_builder
	spotFinder = WG.resource_spot_finder

	mexConstructors = spotBuilder.GetMexConstructors()
	geoConstructors = spotBuilder.GetGeoConstructors()

	mexBuildings = spotBuilder.GetMexBuildings()
	geoBuildings = spotBuilder.GetGeoBuildings()

	local metalSpots = spotFinder.metalSpotsList
	if not metalSpots or (#metalSpots > 0 and #metalSpots <= 2) then
		metalMap = true
	end
end

local function clearGhostBuild()
	if WG.DrawUnitShapeGL4 and activeShape then
		WG.StopDrawUnitShapeGL4(activeShape)
		activeShape = nil
	end
	selectedMex = nil
	selectedGeo = nil
	selectedSpot = nil
	selectedPos = nil
	buildCmd[1] = nil
	lastMx, lastMy = -1, -1
end

local selectedUnits = SpringUnsynced.GetSelectedUnits()
function widget:SelectionChanged(sel)
	selectedUnits = sel
	bestMex = spotBuilder.GetBestExtractorFromBuilders(selectedUnits, mexConstructors, mexBuildings)
	bestGeo = spotBuilder.GetBestExtractorFromBuilders(selectedUnits, geoConstructors, geoBuildings)
	selectionDirty = true
end

function widget:Update(dt)
	if (selectedSpot or selectedPos) and (selectedMex or selectedGeo) then
		-- we want to do this every frame to avoid cursor flicker. Rest of work can be on a timer
		spSetMouseCursor(selectedMex and "upgmex" or "upgmex")
	end

	updateTime = updateTime + dt
	if updateTime < 0.05 then
		return
	end
	updateTime = 0

	if not selectedUnits or #selectedUnits == 0 then
		clearGhostBuild()
		return
	end

	-- Don't do anything with cloaked units
	if #selectedUnits == 1 and unitIsCloaked(selectedUnits[1]) then
		clearGhostBuild()
		return
	end

	local _, activeCmd = spGetActiveCommand()
	if activeCmd and (activeCmd < 0 or activeCmd == CMD_RECLAIM) then
		clearGhostBuild()
		return
	end

	if not bestMex and not bestGeo then
		clearGhostBuild()
		return
	end

	local mx, my = spGetMouseState()

	-- Skip all expensive work if mouse hasn't moved and selection hasn't changed
	if mx == lastMx and my == lastMy and not selectionDirty then
		return
	end
	lastMx, lastMy = mx, my
	selectionDirty = false

	local extractor

	-- First check unit under cursor. If it's an extractor, see if there's valid upgrades
	-- If it's not an extractor, simply exit
	local type, rayParams = spTraceScreenRay(mx, my)
	local unitUuid = type == "unit" and rayParams
	local unitDefID = type == "unit" and spGetUnitDefID(rayParams)

	if unitUuid and unitDefID then
		local unitIsMex = mexBuildings[unitDefID]
		local unitIsGeo = geoBuildings[unitDefID]
		if unitIsMex or unitIsGeo then
			local x, y, z = spGetUnitPosition(unitUuid)

			extractor = unitIsMex and bestMex or bestGeo
			local canUpgrade = spotBuilder.ExtractorCanBeUpgraded(unitUuid, extractor)
			if not canUpgrade then
				clearGhostBuild()
				return
			end

			reusePos.x = x
			reusePos.y = y
			reusePos.z = z
			selectedPos = reusePos
			if unitIsMex then
				selectedMex = bestMex
				selectedSpot = spotFinder.GetClosestMexSpot(x, z)
			else
				selectedGeo = bestGeo
				selectedSpot = spotFinder.GetClosestGeoSpot(x, z)
			end
		else
			clearGhostBuild()
			return
		end
	elseif not metalMap then
		-- If no valid units, check cursor position against extractor spots
		local _, groundPos = spTraceScreenRay(mx, my, true, false, false, true)
		if not groundPos or not groundPos[1] then
			clearGhostBuild()
			return
		end
		local gpx, gpz = groundPos[1], groundPos[3]
		local nearestMex = spotFinder.GetClosestMexSpot(gpx, gpz)
		local nearestGeo = spotFinder.GetClosestGeoSpot(gpx, gpz)

		local mexDist = mathHuge
		local geoDist = mathHuge
		if nearestMex and bestMex then
			mexDist = mathDistance2dSquared(nearestMex.x, nearestMex.z, gpx, gpz)
		end
		if nearestGeo and bestGeo then
			geoDist = mathDistance2dSquared(nearestGeo.x, nearestGeo.z, gpx, gpz)
		end

		-- Figure out if mex or geo is in range
		if mexDist < mathHuge and mexDist < geoDist and mexDist < mexPlacementRadius then
			selectedMex = bestMex
			extractor = bestMex
			selectedSpot = nearestMex
		elseif geoDist < mathHuge and geoDist < mexDist and geoDist < geoPlacementRadius then
			selectedGeo = bestGeo
			extractor = bestGeo
			selectedSpot = nearestGeo
		else
			clearGhostBuild()
			return
		end

		local canBuild = spotBuilder.ExtractorCanBeBuiltOnSpot(selectedSpot, extractor)
		if not canBuild then
			clearGhostBuild()
			return
		end
	end

	-- Set up ghost
	if extractor and (selectedSpot or (selectedPos and metalMap)) then
		-- we only want to build on the center, so we pass the spot in for the position, instead of the groundPos
		local src = selectedPos or selectedSpot
		reuseCmdPos[1] = src.x
		reuseCmdPos[2] = src.y
		reuseCmdPos[3] = src.z
		local cmd = spotBuilder.PreviewExtractorCommand(reuseCmdPos, extractor, selectedSpot, metalMap)
		if not cmd then
			clearGhostBuild()
			return
		end
		buildCmd[1] = cmd
		local newDef = mathAbs(extractor)
		local newX, newY, newZ = cmd[2], cmd[3], cmd[4]
		-- check equality by position
		if unitShape and (unitShape[2] ~= newX or unitShape[3] ~= newY or unitShape[4] ~= newZ) then
			clearGhostBuild()
		end
		reuseUnitShape[1] = newDef
		reuseUnitShape[2] = newX
		reuseUnitShape[3] = newY
		reuseUnitShape[4] = newZ
		reuseUnitShape[5] = cmd[5]
		reuseUnitShape[6] = cmd[6]
		unitShape = reuseUnitShape
	else
		unitShape = false
	end

	-- Draw ghost
	if WG.DrawUnitShapeGL4 then
		if unitShape then
			if not activeShape then
				activeShape = WG.DrawUnitShapeGL4(unitShape[1], unitShape[2], unitShape[3], unitShape[4], unitShape[5] * mathPiHalf, 0.66, unitShape[6], 0.15, 0.3)
			end
		elseif activeShape then
			clearGhostBuild()
		end
	end
end

function widget:MousePress(x, y, button)
	if not bestMex and not bestGeo then
		clearGhostBuild()
		return
	end

	-- update runs on a timer for performance reasons, but this can result in edge-cases where if
	-- the click happens at a certain time, the build commands won't be ready yet, and a guard
	-- command will be issued. We force an update on click to make sure that all the data needed is here and ready
	lastMx, lastMy = -1, -1 -- force fresh update
	widget:Update(1)

	if not buildCmd or not buildCmd[1] then
		return
	end

	if button == 3 then
		local _, _, _, shift = spGetModKeyState()
		if selectedMex then
			spotBuilder.ApplyPreviewCmds(buildCmd, mexConstructors, shift)
			return true
		end
		if selectedGeo then
			spotBuilder.ApplyPreviewCmds(buildCmd, geoConstructors, shift)
			return true
		end
	end
end

function widget:Shutdown()
	clearGhostBuild()
end
