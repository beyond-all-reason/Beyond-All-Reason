function widget:GetInfo()
	return {
		name = "RClick Quick Build (mex/geo)",
		desc = "Adds ability to quickly place or upgrade mex/geothermal by right clicking.",
		author = "Google Frog, NTG (file handling), Chojin (metal map), Doo (multiple enhancements), Floris (mex placer/upgrader), Tarte (maintenance/geothermal)",
		version = "2.0",
		date = "Oct 23, 2010; last update: April 13, 2022",
		license = "GNU GPL, v2 or later",
		handler = true,
		layer = 0,
		enabled = true  --  loaded by default?
	}
end

------------------------------------------------------------
-- Config
------------------------------------------------------------
local t1geoThreshold = 300 --any building producing this much or less is considered tier 1
local t1mexThreshold = 0.001 --any building producing this much or less is considered tier 1

local enableMoveIsQuickBuildGeo = true		-- auto make move cmd an area geo cmd
local enableMoveIsQuickBuildMex = true		-- auto make move cmd an area mex cmd

local addShift = false	-- when single clicking a sequence of mexes, no longer needed to hold shift!

local geoPlacementRadius = 5000	-- (not actual ingame distance)
local geoPlacementDragRadius = 20000	-- larger size so you can drag a move line over/near geo spots and it will auto queue geo there more easily
local mexPlacementRadius = 1600	-- (not actual ingame distance)
local mexPlacementDragRadius = 20000	-- larger size so you can drag a move line over/near mex spots and it will auto queue mex there more easily
------------------------------------------------------------
-- Speedups
------------------------------------------------------------
local CMD_MOVE = CMD.MOVE
local CMD_GUARD = CMD.GUARD

local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID

------------------------------------------------------------
-- Other variables
------------------------------------------------------------
local chobbyInterface, activeUnitShape, lastInsertedOrder

------------------------------------------------------------
-- Helper functions (Math stuff)
------------------------------------------------------------
local function Distance(x1, z1, x2, z2)
	return (x1 - x2) * (x1 - x2) + (z1 - z2) * (z1 - z2)
end

local function GetClosestPosition(x, z, positions)
	local bestPos
	local bestDist = math.huge
	for i = 1, #positions do
		local pos = positions[i]
		local dx, dz = x - pos.x, z - pos.z
		local dist = dx * dx + dz * dz
		if dist < bestDist then
			bestPos = pos
			bestDist = dist
		end
	end
	return bestPos
end

------------------------------------------------------------
-- Shared functions
------------------------------------------------------------
function CheckForBuildingOpportunity(type, params)
	local isT1Mex = (type == 'unit' and WG['resource_spot_builder'].GetMexBuildings()[spGetUnitDefID(params)] and WG['resource_spot_builder'].GetMexBuildings()[spGetUnitDefID(params)] <= t1mexThreshold)
	local isT1Geo = (type == 'unit' and WG['resource_spot_builder'].GetGeoBuildings()[spGetUnitDefID(params)] and WG['resource_spot_builder'].GetGeoBuildings()[spGetUnitDefID(params)] <= t1geoThreshold)
	local closestMex, closestGeo, unitID
	if type == 'unit' then
		unitID = params
		params = { spGetUnitPosition(unitID)}
	end

	local groundHasEmptyMetal, groundHasEmptyGeo = false, false
	if isT1Mex or isT1Geo or type == 'ground' then
		if type == 'ground' then
			closestMex = GetClosestPosition(params[1], params[3], WG['resource_spot_finder'].metalSpotsList)
			if closestMex and Distance(params[1], params[3], closestMex.x, closestMex.z) < mexPlacementRadius then
				groundHasEmptyMetal = true
			end
			closestGeo = GetClosestPosition(params[1], params[3], WG['resource_spot_finder'].geoSpotsList)
			if closestGeo and Distance(params[1], params[3], closestGeo.x, closestGeo.z) < geoPlacementRadius then
				groundHasEmptyGeo = true
			end
		end
	end

	return isT1Mex, isT1Geo, groundHasEmptyMetal, groundHasEmptyGeo, params
end

------------------------------------------------------------
-- display mouse cursor and unitshape when hovering over a resource spot
------------------------------------------------------------

local sec = 0
function widget:Update(dt)
	if chobbyInterface then return end

	local mx, my, mb, mmb, mb2 = Spring.GetMouseState()

	local doUpdate = activeUnitShape ~= nil
	sec = sec + dt
	if sec > 0.05 then
		sec = 0
		doUpdate = true
	end

	local drawUnitShape = false

	if doUpdate then
		if not WG.customformations_linelength or WG.customformations_linelength < 10 then	-- dragging multi-unit formation-move-line

			local type, rayParams = Spring.TraceScreenRay(mx, my)
			local isT1Mex, isT1Geo, groundHasEmptyMetal, groundHasEmptyGeo, params = CheckForBuildingOpportunity(type, rayParams)

			--put into a local function to reduce code redundancy
			local function TryConstructBuilding(upgradableT1, groundHasEmptySpot, constructorsT1, constructorsT2, BuildOrder)
				if upgradableT1 or groundHasEmptySpot then
					local hasT1constructor, hasT2constructor = false, false
					-- search for constructors
					local selUnitsCount = Spring.GetSelectedUnitsCounts()
					for k,v in pairs(selUnitsCount) do
						if k ~= 'n' then
							if constructorsT1[k] then
								hasT1constructor = true
								break
							end
							if constructorsT2[k] then
								hasT2constructor = true
								break
							end
						end
					end
					if hasT1constructor or hasT2constructor then
						local queuedBuildings = BuildOrder({ params[1], params[2], params[3]}, {}, false, true)
						if queuedBuildings and #queuedBuildings > 0 then
							drawUnitShape = { queuedBuildings[1][2], queuedBuildings[1][3], queuedBuildings[1][4], queuedBuildings[1][5], queuedBuildings[1][6] }
							Spring.SetMouseCursor('upgmex')
						end
					end
				end
			end

			if isT1Mex or groundHasEmptyMetal then
				TryConstructBuilding(
					isT1Mex,
					groundHasEmptyMetal,
					WG['resource_spot_builder'].GetMexConstructorsDef(),
					WG['resource_spot_builder'].GetMexConstructorsT2(),
					WG['resource_spot_builder'].BuildMex
				)
			end

			if isT1Geo or groundHasEmptyGeo then
				TryConstructBuilding(
					isT1Geo,
					groundHasEmptyGeo,
					WG['resource_spot_builder'].GetGeoConstructorsDef(),
					WG['resource_spot_builder'].GetGeoConstructorsT2(),
					WG['resource_spot_builder'].BuildGeothermal
				)
			end
		end

		if WG.DrawUnitShapeGL4 then
			if drawUnitShape then
				if not activeUnitShape then
					activeUnitShape = {
						drawUnitShape[1],
						drawUnitShape[2],
						drawUnitShape[3],
						drawUnitShape[4],
						drawUnitShape[5],
						WG.DrawUnitShapeGL4(drawUnitShape[1], drawUnitShape[2], drawUnitShape[3], drawUnitShape[4], 0, 0.66, drawUnitShape[5], 0.15, 0.3)
					}
				end
			elseif activeUnitShape then
				WG.StopDrawUnitShapeGL4(activeUnitShape[6])
				activeUnitShape = nil
			end
		end
	end
end

function widget:Shutdown()
	if WG.DrawUnitShapeGL4 and activeUnitShape then
		WG.StopDrawUnitShapeGL4(activeUnitShape[6])
		activeUnitShape = nil
	end
end


------------------------------------------------------------
-- Transform move/guard into a build order command
------------------------------------------------------------
function widget:CommandNotify(id, params, options)
	local isMove = (id == CMD_MOVE)
	local isGuard = (id == CMD_GUARD)
	if not (isMove or isGuard) then
		return
	end

	local mx, my, mb = Spring.GetMouseState()

	if isGuard then
		local type, unitID = Spring.TraceScreenRay(mx, my)
		if type == 'unit' then
			if not (WG['resource_spot_builder'].GetMexBuildings()[spGetUnitDefID(unitID)] and WG['resource_spot_builder'].GetMexBuildings()[spGetUnitDefID(unitID)] <= t1mexThreshold)
			and not (WG['resource_spot_builder'].GetGeoBuildings()[spGetUnitDefID(unitID)] and WG['resource_spot_builder'].GetGeoBuildings()[spGetUnitDefID(unitID)] <= t1geoThreshold) then
				return --no t1 buildings available
			end
		end
	end

	function TryConvertCmdToBuildOrder(cmd_id, enableQuickBuildOnMove, constructors, spots, BuildOrder, placementRadius, placementDragRadius)
		local moveReturn = false
		local selectedUnits = Spring.GetSelectedUnits()
		if constructors[selectedUnits[1]] then
			if isGuard then
				local ux, uy, uz = spGetUnitPosition(params[1])
				isGuard = { x = ux, y = uy, z = uz }
				params[1], params[2], params[3] = ux, uy, uz
				id = cmd_id
				params[4] = 30 		-- increase this too if you want to increase mexPlacementRadius/geoPlacementRadius
				if addShift then
					options.shift = true	-- this allows for separate clicks (of mex/geo spot queuing).
				end
				lastInsertedOrder = nil
			elseif isMove and enableQuickBuildOnMove then
				local closestSpot = GetClosestPosition(params[1], params[3], spots)
				local spotRadius = placementRadius
				if #selectedUnits == 1 and #Spring.GetCommandQueue(selectedUnits[1], 8) > 1 then
					if not lastInsertedOrder or (closestSpot.x ~= lastInsertedOrder[1] and closestSpot.z ~= lastInsertedOrder[2]) then
						spotRadius = placementDragRadius		-- make move drag near mex/geo spots be less strict
					elseif lastInsertedOrder then
						spotRadius = 0
					end
				else
					lastInsertedOrder = nil
				end
				if spotRadius > 0 and closestSpot and Distance(params[1], params[3], closestSpot.x, closestSpot.z) < spotRadius then
					id = cmd_id
					params[4] = 120		-- increase this too if you want to increase mexPlacementDragRadius/geoPlacementDragRadius
					moveReturn = true
					if addShift then
						options.shift = true	-- this allows for separate clicks (of mex/geo spot queuing). When movedragging: this is also to fix doing area mex twice undoing a queued mex
					end
				else
					return false
				end
			end
		end
		if id == cmd_id then
			local queuedBuildings = BuildOrder(params, options, isGuard, false)
			if moveReturn and not queuedBuildings[1] then	-- used when area_mex isnt queuing a mex, to let the move cmd still pass through
				return false
			end
			return true
		end
	end

	-- Decide if this is a mex or geo spot
	local type, rayParams = Spring.TraceScreenRay(mx, my)
	local isT1Mex, isT1Geo, groundHasEmptyMetal, groundHasEmptyGeo, unitPos = CheckForBuildingOpportunity(type, rayParams)

	if isT1Mex or groundHasEmptyMetal then
		return TryConvertCmdToBuildOrder(
			CMD_CONSTRUCT_MEX,
			enableMoveIsQuickBuildMex,
			WG['resource_spot_builder'].GetMexConstructors(),
			WG['resource_spot_finder'].metalSpotsList,
			WG['resource_spot_builder'].BuildMex,
			mexPlacementRadius,
			mexPlacementDragRadius
		)
	end

	if isT1Geo or groundHasEmptyGeo then
		return TryConvertCmdToBuildOrder(
			CMD_CONSTRUCT_GEO,
			enableMoveIsQuickBuildGeo,
			WG['resource_spot_builder'].GetGeoConstructors(),
			WG['resource_spot_finder'].geoSpotsList,
			WG['resource_spot_builder'].BuildGeothermal,
			geoPlacementRadius,
			geoPlacementDragRadius
		)
	end
end
