function widget:GetInfo()
	return {
		name = "RClick Quick Build (geo)",
		desc = "Adds ability to place/upgrade geothermal by right clicking.",
		author = "Tarte",
		date = "2022-04-10",
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

local moveIsAreaGeo = true		-- auto make move cmd an area mex cmd
local addShift = false	-- when single clicking a sequence, no longer needed to hold shift!
local geoPlacementRadius = 5000	-- (not actual ingame distance)
local geoPlacementDragRadius = 20000	-- larger size so you can drag a move line over/near geo spots and it will auto queue geo there more easily

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

------------------------------------------------------------
-- Turn right click (move command) into build order
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

	-- display mouse cursor/geo unitshape when hovering over a geospot
	if doUpdate then
		if not WG.customformations_linelength or WG.customformations_linelength < 10 then	-- dragging multi-unit formation-move-line
			local type, params = Spring.TraceScreenRay(mx, my)
			local isT1Geo = (type == 'unit' and WG['resource_spot_builder'].GetGeoBuildings()[spGetUnitDefID(params)] and WG['resource_spot_builder'].GetGeoBuildings()[spGetUnitDefID(params)] <= t1geoThreshold)
			local closestGeo, unitID
			if type == 'unit' then
				unitID = params
				params = { spGetUnitPosition(unitID)}
			end
			if isT1Geo or type == 'ground' then
				local proceed = false
				if type == 'ground' then
					closestGeo = WG['resource_spot_builder'].GetClosestPosition(params[1], params[3], WG['resource_spot_finder'].GetSpotsGeo())
					if closestGeo and Distance(params[1], params[3], closestGeo.x, closestGeo.z) < geoPlacementRadius then
						proceed = true
					end
				end
				if isT1Geo or proceed then
					local hasT1builder, hasT2builder = false, false
					-- search for builders
					for k,v in pairs(WG['resource_spot_builder'].GetSelectedUnitsCount()) do
						if k ~= 'n' then
							if WG['resource_spot_builder'].GetMexConstructorsDef()[k] then
								hasT1builder = true
								break
							end
							if WG['resource_spot_builder'].GetMexConstructorsT2()[k] then
								hasT2builder = true
								break
							end
						end
					end
					if hasT1builder or hasT2builder then
						local queuedGeoes = WG['resource_spot_builder'].BuildGeothermal({ params[1], params[2], params[3]}, {}, false, true)
						if queuedGeoes and #queuedGeoes > 0 then
							drawUnitShape = { queuedGeoes[1][2], queuedGeoes[1][3], queuedGeoes[1][4], queuedGeoes[1][5], queuedGeoes[1][6] }
							Spring.SetMouseCursor('upgmex')
						end
					end
				end
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

function widget:CommandNotify(id, params, options)
	local isMove = (id == CMD_MOVE)
	local isGuard = (id == CMD_GUARD)
	if not (isMove or isGuard) then
		return
	end

	if isGuard then
		local mx, my, mb = Spring.GetMouseState()
		local type, unitID = Spring.TraceScreenRay(mx, my)
		if not (type == 'unit' and WG['resource_spot_builder'].GetGeoBuildings()[spGetUnitDefID(unitID)] and WG['resource_spot_builder'].GetGeoBuildings()[spGetUnitDefID(unitID)] <= t1geoThreshold) then
			return
		end
	end

	-- transform move into small area-geo command
	local moveReturn = false
	if WG['resource_spot_builder'].GetGeoConstructors()[WG['resource_spot_builder'].GetSelectedUnits()[1]] then
		if isGuard then
			local ux, uy, uz = spGetUnitPosition(params[1])
			isGuard = { x = ux, y = uy, z = uz }
			params[1], params[2], params[3] = ux, uy, uz
			id = CMD_CONSTRUCT_GEO
			params[4] = 30 		-- increase this too if you want to increase geoPlacementRadius
			if addShift then
				options.shift = true	-- this allows for separate clicks (of geo spot queuing).
			end
			lastInsertedOrder = nil
		elseif isMove and moveIsAreaGeo then
			local closestGeo = WG['resource_spot_builder'].GetClosestPosition(params[1], params[3], WG['resource_spot_finder'].GetSpotsGeo())
			local spotRadius = geoPlacementRadius
			if #(WG['resource_spot_builder'].GetSelectedUnits()) == 1 and #Spring.GetCommandQueue(WG['resource_spot_builder'].GetSelectedUnits()[1], 8) > 1 then
				if not lastInsertedOrder or (closestGeo.x ~= lastInsertedOrder[1] and closestGeo.z ~= lastInsertedOrder[2]) then
					spotRadius = geoPlacementDragRadius		-- make move drag near geo spots be less strict
				elseif lastInsertedOrder then
					spotRadius = 0
				end
			else
				lastInsertedOrder = nil
			end
			if spotRadius > 0 and closestGeo and Distance(params[1], params[3], closestGeo.x, closestGeo.z) < spotRadius then
				id = CMD_CONSTRUCT_GEO
				params[4] = 120		-- increase this too if you want to increase geoPlacementDragRadius
				moveReturn = true
				if addShift then
					options.shift = true	-- this allows for separate clicks (of geo spot queuing). When movedragging: this is also dont to fix doing area geo twice undoing a queued geo
				end
			else
				return false
			end
		end
	end

	if id == CMD_CONSTRUCT_GEO then
		local queuedMexes = WG['resource_spot_builder'].BuildGeothermal(params, options, isGuard)
		if moveReturn and not queuedMexes[1] then	-- used when area_mex isnt queuing a mex, to let the move cmd still pass through
			return false
		end
		return true
	end
end


