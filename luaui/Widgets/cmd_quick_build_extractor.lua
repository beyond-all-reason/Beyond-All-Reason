function widget:GetInfo()
	return {
		name = "Quick Build (mex/geo)",
		desc = "Adds ability to quickly place or upgrade mex/geothermal by right clicking.",
		author = "Hobo Joe, based on work by Google Frog, NTG, Chojin, Doo, Floris, and Tarte",
		version = "1.0",
		date = "Jan 2024",
		license = "GNU GPL, v2 or later",
		handler = true,
		layer = 1000,
		enabled = true
	}
end

local CMD_MOVE = CMD.MOVE
local CMD_GUARD = CMD.GUARD
local CMD_RECLAIM = CMD.RECLAIM

local spGetActiveCommand = Spring.GetActiveCommand
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition

local geoPlacementRadius = 5000	-- (not actual ingame distance)
local mexPlacementRadius = 2000	-- (not actual ingame distance)

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
		widget:Shutdown()
	end

	mexConstructors = WG["resource_spot_builder"].GetMexConstructors()
	geoConstructors = WG["resource_spot_builder"].GetGeoConstructors()

	mexBuildings = WG["resource_spot_builder"].GetMexBuildings()
	geoBuildings = WG["resource_spot_builder"].GetGeoBuildings()

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
	if(selectedSpot) then
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
	local type, rayParams = Spring.TraceScreenRay(mx, my)
	local unitUuid = type == 'unit' and rayParams or nil
	local unitDefID = type == 'unit' and spGetUnitDefID(rayParams) or nil

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
				--selectedSpot = WG["resource_spot_finder"].GetClosestMexSpot(x, z)
				selectedPos = { x = x, y = y, z = z }
				selectedMex = bestMex
			else
				--selectedSpot = WG["resource_spot_finder"].GetClosestGeoSpot(x, z)
				selectedPos = { x = x, y = y, z = z }
				selectedGeo = bestGeo
			end
		else
			clearGhostBuild()
			return
		end
	elseif not metalMap then
		-- If no valid units, check cursor position against extractor spots
		local _, groundPos = Spring.TraceScreenRay(mx, my, true)
		if not groundPos or not groundPos[1] then
			clearGhostBuild()
			return
		end
		local pos = { x = groundPos[1], y = groundPos.y, z = groundPos[3] }
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
	if extractor and (selectedSpot or selectedPos) then
		-- we only want to build on the center, so we pass the spot in for the position, instead of the groundPos
		local cmdPos = selectedPos and { selectedPos.x, selectedPos.y, selectedPos.z } or { selectedSpot.x, selectedSpot.y, selectedSpot.z}
		local spotPos = selectedPos and selectedPos or selectedSpot -- When a specific mex is moused over, we use that position instead of the spot for previewing the command
		local cmd = WG["resource_spot_builder"].PreviewExtractorCommand(cmdPos, extractor, spotPos)
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


function widget:CommandNotify(id, params, options)
	if not buildCmd then
		return
	end
	local isMove = (id == CMD_MOVE)
	local isGuard = (id == CMD_GUARD)
	local isReclaim = (id == CMD_RECLAIM)
	if not (isMove or isGuard or isReclaim) or (isReclaim and params[2]) then
		return
	end

	if selectedMex then
		local cmd = WG['resource_spot_builder'].ApplyPreviewCmds(buildCmd, mexConstructors, options.shift)
		return cmd
	end
	if selectedGeo then
		local cmd = WG['resource_spot_builder'].ApplyPreviewCmds(buildCmd, geoConstructors, options.shift)
		return cmd
	end
end

function widget:Shutdown()
	clearGhostBuild()
end
