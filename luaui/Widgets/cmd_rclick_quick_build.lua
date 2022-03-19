function widget:GetInfo()
	return {
		name = "RClick Quick Build",
		desc = "Adds ability to place/upgrade mex by right clicking.",
		author = "Google Frog, NTG (file handling), Chojin (metal map), Doo (multiple enhancements), Floris (mex placer/upgrader), Tarte (maintenance)",
		date = "Oct 23, 2010, (last update: March 3, 2022)",
		license = "GNU GPL, v2 or later",
		handler = true,
		layer = 0,
		enabled = true  --  loaded by default?
	}
end


local CMD_MOVE = CMD.MOVE
local CMD_GUARD = CMD.GUARD

local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID

local moveIsAreaMex = true		-- auto make move cmd an area mex cmd
local addShift = false	-- when single clicking a sequence of mexes, no longer needed to hold shift!
local mexPlacementRadius = 1600	-- (not actual ingame distance)
local mexPlacementDragRadius = 20000	-- larger size so you can drag a move line over/near mex spots and it will auto queue mex there more easily

local chobbyInterface, activeUnitShape, lastInsertedOrder

local function Distance(x1, z1, x2, z2)
	return (x1 - x2) * (x1 - x2) + (z1 - z2) * (z1 - z2)
end

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

	-- display mouse cursor/mex unitshape when hovering over a metalspot
	if doUpdate then
		if not WG.customformations_linelength or WG.customformations_linelength < 10 then	-- dragging multi-unit formation-move-line
			local type, params = Spring.TraceScreenRay(mx, my)
			local isT1Mex = (type == 'unit' and WG['helperBuildResourceSpot'].GetMexIds()[spGetUnitDefID(params)] and WG['helperBuildResourceSpot'].GetMexIds()[spGetUnitDefID(params)] < 0.002)
			local closestMex, unitID
			if type == 'unit' then
				unitID = params
				params = { spGetUnitPosition(unitID)}
			end
			if isT1Mex or type == 'ground' then
				local proceed = false
				if type == 'ground' then
					closestMex = WG['helperBuildResourceSpot'].GetClosestPosition(params[1], params[3], WG.metalSpots)
					if closestMex and Distance(params[1], params[3], closestMex.x, closestMex.z) < mexPlacementRadius then
						proceed = true
					end
				end
				if isT1Mex or proceed then
					local hasT1builder, hasT2builder = false, false
					-- search for builders
					for k,v in pairs(WG['helperBuildResourceSpot'].GetSelectedUnitsCount()) do
						if k ~= 'n' then
							if WG['helperBuildResourceSpot'].GetMexBuilderDef()[k] then
								hasT1builder = true
								break
							end
							if WG['helperBuildResourceSpot'].GetMexBuilderT2()[k] then
								hasT2builder = true
								break
							end
						end
					end
					if hasT1builder or hasT2builder then
						local queuedMexes = WG['helperBuildResourceSpot'].BuildMetalExtractors({ params[1], params[2], params[3]}, {}, false, true)
						if queuedMexes and #queuedMexes > 0 then
							drawUnitShape = { queuedMexes[1][2], queuedMexes[1][3], queuedMexes[1][4], queuedMexes[1][5], queuedMexes[1][6] }
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

	-- transform move into area-mex command
	local moveReturn = false
	if WG['helperBuildResourceSpot'].GetMexBuilder()[WG['helperBuildResourceSpot'].GetSelectedUnits()[1]] then
		if isGuard then
			local ux, uy, uz = spGetUnitPosition(params[1])
			isGuard = { x = ux, y = uy, z = uz }
			params[1], params[2], params[3] = ux, uy, uz
			id = CMD_CONSTRUCT_MEX
			params[4] = 30 		-- increase this too if you want to increase mexPlacementRadius
			if addShift then
				options.shift = true	-- this allows for separate clicks (of mex spot queuing).
			end
			lastInsertedOrder = nil
		elseif isMove and moveIsAreaMex then
			local closestMex = WG['helperBuildResourceSpot'].GetClosestPosition(params[1], params[3], WG.metalSpots)
			local spotRadius = mexPlacementRadius
			if #(WG['helperBuildResourceSpot'].GetSelectedUnits()) == 1 and #Spring.GetCommandQueue(WG['helperBuildResourceSpot'].GetSelectedUnits()[1], 8) > 1 then
				if not lastInsertedOrder or (closestMex.x ~= lastInsertedOrder[1] and closestMex.z ~= lastInsertedOrder[2]) then
					spotRadius = mexPlacementDragRadius		-- make move drag near mex spots be less strict
				elseif lastInsertedOrder then
					spotRadius = 0
				end
			else
				lastInsertedOrder = nil
			end
			if spotRadius > 0 and closestMex and Distance(params[1], params[3], closestMex.x, closestMex.z) < spotRadius then
				id = CMD_CONSTRUCT_MEX
				params[4] = 120		-- increase this too if you want to increase mexPlacementDragRadius
				moveReturn = true
				if addShift then
					options.shift = true	-- this allows for separate clicks (of mex spot queuing). When movedragging: this is also dont to fix doing area mex twice undoing a queued mex
				end
			else
				return false
			end
		end
	end

	if id == CMD_CONSTRUCT_MEX then
		local queuedMexes = WG['helperBuildResourceSpot'].BuildMetalExtractors(params, options, isGuard)
		if moveReturn and not queuedMexes[1] then	-- used when area_mex isnt queuing a mex, to let the move cmd still pass through
			return false
		end
		return true
	end
end
