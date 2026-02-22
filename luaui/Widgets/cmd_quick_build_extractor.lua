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
		enabled = true
	}
end


-- Localized Spring API for performance
local spTraceScreenRay = Spring.TraceScreenRay

local CMD_RECLAIM = CMD.RECLAIM

local spGetActiveCommand = Spring.GetActiveCommand
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition

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

local updateTime = 0

local isCloakableBuilder = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.buildOptions[1] and unitDef.canCloak then
		isCloakableBuilder[unitDefID] = true
	end
end
local function unitIsCloaked(uDefId)
	return isCloakableBuilder[Spring.GetUnitDefID(uDefId)] and select(5,Spring.GetUnitStates(uDefId,false,true))
end


function widget:Initialize()
	if not WG.DrawUnitShapeGL4 then
		widgetHandler:RemoveWidget()
	end

	local builder = WG.resource_spot_builder

	mexConstructors = builder.GetMexConstructors()
	geoConstructors = builder.GetGeoConstructors()

	mexBuildings = builder.GetMexBuildings()
	geoBuildings = builder.GetGeoBuildings()

	local metalSpots = WG["resource_spot_finder"].metalSpotsList
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
	buildCmd = {}
end


local selectedUnits = Spring.GetSelectedUnits()
function widget:SelectionChanged(sel)
	selectedUnits = sel
	bestMex = WG['resource_spot_builder'].GetBestExtractorFromBuilders(selectedUnits, mexConstructors, mexBuildings)
	bestGeo = WG['resource_spot_builder'].GetBestExtractorFromBuilders(selectedUnits, geoConstructors, geoBuildings)
end


function widget:Update(dt)
	if(selectedSpot or selectedPos) then
		-- we want to do this every frame to avoid cursor flicker. Rest of work can be on a timer
		Spring.SetMouseCursor('upgmex')
	end

	updateTime = updateTime + dt
	if(updateTime < 0.05) then
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

	local extractor
	local mx, my = Spring.GetMouseState()

	-- First check unit under cursor. If it's an extractor, see if there's valid upgrades
	-- If it's not an extractor, simply exit
	local type, rayParams = spTraceScreenRay(mx, my)
	local unitUuid = type == 'unit' and rayParams
	local unitDefID = type == 'unit' and spGetUnitDefID(rayParams)

	if(unitUuid and unitDefID) then
		local unitIsMex = mexBuildings[unitDefID]
		local unitIsGeo = geoBuildings[unitDefID]
		if (unitIsMex or unitIsGeo) then
			local x, y, z = spGetUnitPosition(unitUuid)

			extractor = unitIsMex and bestMex or bestGeo
			local canUpgrade = WG['resource_spot_builder'].ExtractorCanBeUpgraded(unitUuid, extractor)
			if not canUpgrade then
				clearGhostBuild()
				return
			end

			if unitIsMex then
				selectedPos = { x = x, y = y, z = z }
				selectedMex = bestMex
				selectedSpot = WG['resource_spot_finder'].GetClosestMexSpot(x, z)
			else
				selectedPos = { x = x, y = y, z = z }
				selectedGeo = bestGeo
				selectedSpot = WG['resource_spot_finder'].GetClosestGeoSpot(x, z)
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
		local pos = { x = groundPos[1], y = groundPos[2], z = groundPos[3] }
		local nearestMex = WG["resource_spot_finder"].GetClosestMexSpot(pos.x, pos.z)
		local nearestGeo = WG["resource_spot_finder"].GetClosestGeoSpot(pos.x, pos.z)

		local mexDist = math.huge
		local geoDist = math.huge
		if nearestMex then
			mexDist = math.distance2dSquared(nearestMex.x, nearestMex.z, pos.x, pos.z)
		end
		if nearestGeo then
			geoDist = math.distance2dSquared(nearestGeo.x, nearestGeo.z, pos.x, pos.z)
		end

		-- Figure out if mex or geo is in range
		if mexDist < math.huge and mexDist < geoDist and mexDist < mexPlacementRadius then
			selectedMex = bestMex
			extractor = bestMex
			selectedSpot = nearestMex
		elseif geoDist < math.huge and geoDist < mexDist and geoDist < geoPlacementRadius then
			selectedGeo = bestGeo
			extractor = bestGeo
			selectedSpot = nearestGeo
		else
			clearGhostBuild()
			return
		end

		local canBuild = WG['resource_spot_builder'].ExtractorCanBeBuiltOnSpot(selectedSpot, extractor)
		if not canBuild then
			clearGhostBuild()
			return
		end
	end


	-- Set up ghost
	if extractor and (selectedSpot or (selectedPos and metalMap)) then
		-- we only want to build on the center, so we pass the spot in for the position, instead of the groundPos
		local cmdPos = selectedPos and { selectedPos.x, selectedPos.y, selectedPos.z } or { selectedSpot.x, selectedSpot.y, selectedSpot.z }
		local cmd = WG["resource_spot_builder"].PreviewExtractorCommand(cmdPos, extractor, selectedSpot, metalMap)
		if not cmd then
			clearGhostBuild()
			return
		end
		buildCmd[1] = cmd
		local newUnitShape = { math.abs(extractor), cmd[2], cmd[3], cmd[4], cmd[5], cmd[6] }
		-- check equality by position
		if unitShape and (unitShape[2] ~= newUnitShape[2] or unitShape[3] ~= newUnitShape[3] or unitShape[4] ~= newUnitShape[4]) then
			clearGhostBuild()
		end
		unitShape = newUnitShape
	else
		unitShape = false
	end

	-- Draw ghost
	if WG.DrawUnitShapeGL4 then
		if unitShape then
			if not activeShape then
				activeShape = WG.DrawUnitShapeGL4(unitShape[1], unitShape[2], unitShape[3], unitShape[4], unitShape[5] * (math.pi / 2), 0.66, unitShape[6], 0.15, 0.3)
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
	widget:Update(1)

	if not buildCmd or not buildCmd[1] then
		return
	end

	if (button == 3) then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		if selectedMex then
			WG['resource_spot_builder'].ApplyPreviewCmds(buildCmd, mexConstructors, shift)
			return true
		end
		if selectedGeo then
			WG['resource_spot_builder'].ApplyPreviewCmds(buildCmd, geoConstructors, shift)
			return true
		end
	end
end


function widget:Shutdown()
	clearGhostBuild()
end
