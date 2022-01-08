function widget:GetInfo()
	return {
		name = "Area Mex",
		desc = "Adds a command to cap mexes in an area.",
		author = "Google Frog, NTG (file handling), Chojin (metal map), Doo (multiple enhancements), Floris (mex placer/upgrader)",
		date = "Oct 23, 2010",
		license = "GNU GPL, v2 or later",
		handler = true,
		layer = 0,
		enabled = true  --  loaded by default?
	}
end

local moveIsAreamex = true		-- auto make move cmd an area mex cmd

local mexPlacementRadius = 1500	-- (not actual ingame distance)
local mexPlacementDragRadius = 20000	-- larger size so you can drag a move line over/near mex spots and it will auto queue mex there more easily

local CMD_AREA_MEX = 10100
local CMD_MOVE = CMD.MOVE
local CMD_STOP = CMD.STOP
local CMD_GUARD = CMD.GUARD
local CMD_OPT_RIGHT = CMD.OPT_RIGHT

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetSelectedUnitsCounts = Spring.GetSelectedUnitsCounts
local spGetGroundHeight = Spring.GetGroundHeight
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitPosition = Spring.GetUnitPosition
local spGetTeamUnits = Spring.GetTeamUnits
local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitDefID = Spring.GetUnitDefID

local spGetActiveCommand = Spring.GetActiveCommand
local spGetMapDrawMode = Spring.GetMapDrawMode
local spSendCommands = Spring.SendCommands

local toggledMetal, retoggleLos, chobbyInterface, lastInsertedOrder, activeUnitShape

local tasort = table.sort
local taremove = table.remove

local metalmap = false
local mexBuilder = {}
local Game_extractorRadius = Game.extractorRadius

local mexIds = {}
local unitWaterDepth = {}
local unitXsize = {}
for udid, ud in pairs(UnitDefs) do
	if ud.extractsMetal > 0 then
		mexIds[udid] = ud.extractsMetal
	end
	if ud.isBuilding then
		unitWaterDepth[udid] = { ud.minWaterDepth, ud.maxWaterDepth }
		unitXsize[udid] = ud.xsize
	end
end

local mexBuilderDef = {}
local t2mexBuilder = {}
for udid, ud in pairs(UnitDefs) do
	if ud.buildOptions then
		local maxExtractmetal = 0
		for i, option in ipairs(ud.buildOptions) do
			if mexIds[option] then
				maxExtractmetal = math.max(maxExtractmetal, mexIds[option])
				if mexBuilderDef[udid] then
					mexBuilderDef[udid].buildings = mexBuilderDef[udid].buildings + 1
					mexBuilderDef[udid].building[mexBuilderDef[udid].buildings] = option * -1
				else
					mexBuilderDef[udid] = { buildings = 1, building = { [1] = option * -1 } }
				end
			end
		end
		if maxExtractmetal > 0.002 then
			t2mexBuilder[udid] = true
		end
	end
end

local function Distance(x1, z1, x2, z2)
	return (x1 - x2) * (x1 - x2) + (z1 - z2) * (z1 - z2)
end

function widget:UnitCreated(unitID, unitDefID)
	if mexBuilderDef[unitDefID] then
		mexBuilder[unitID] = mexBuilderDef[unitDefID]
		return
	elseif mexBuilderDef[unitDefID] then
		mexBuilder[unitID] = mexBuilderDef[unitDefID]
	end
end

function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	if not mexBuilder[unitID] then
		widget:UnitCreated(unitID, unitDefID, newTeam)
	end
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if not mexBuilder[unitID] then
		widget:UnitCreated(unitID, unitDefID, newTeam)
	end
end

local function GetClosestMetalSpot(x, z)
	local bestSpot
	local bestDist = math.huge
	local metalSpots = WG.metalSpots
	for i = 1, #metalSpots do
		local spot = metalSpots[i]
		local dx, dz = x - spot.x, z - spot.z
		local dist = dx * dx + dz * dz
		if dist < bestDist then
			bestSpot = spot
			bestDist = dist
		end
	end
	return bestSpot
end

-- Is there any better and allied mex at this location? (returns false if there is)
local function NoAlliedMex(x, z, batchextracts)
	local mexesatspot = Spring.GetUnitsInCylinder(x, z, Game_extractorRadius)
	for i = 1, #mexesatspot do
		local uid = mexesatspot[i]
		if mexIds[spGetUnitDefID(uid)] and Spring.AreTeamsAllied(spGetMyTeamID(), Spring.GetUnitTeam(uid)) and mexIds[spGetUnitDefID(uid)] >= batchextracts then
			return false
		end
	end
	return true
end

local function GetClosestMexPosition(spot, x, z, uDefID, facing)
	local bestPos
	local bestDist = math.huge
	local positions = WG.GetMexPositions(spot, uDefID, facing, true)
	for i = 1, #positions do
		local pos = positions[i]
		local dx, dz = x - pos[1], z - pos[3]
		local dist = dx * dx + dz * dz
		if dist < bestDist then
			bestPos = pos
			bestDist = dist
		end
	end
	return bestPos
end

local function IsSpotOccupied(spot)
	local units = Spring.GetUnitsInCylinder(spot.x, spot.z, Game_extractorRadius)
	for j=1, #units do
		if mexIds[spGetUnitDefID(units[j])]  then
			return units[j]
		end
	end
	return false
end

local selectedUnits = spGetSelectedUnits()
local selUnitCounts = spGetSelectedUnitsCounts()
function widget:SelectionChanged(sel)
	selectedUnits = sel
	selUnitCounts = spGetSelectedUnitsCounts()
end

local function doAreaMexCommand(params, options, isGuard, justDraw)		-- when isGuard: needs to be a table of the unit pos: { x = ux, y = uy, z = uz }
	local cx, cy, cz, cr = params[1], params[2], params[3], params[4]
	if not cr or cr < Game_extractorRadius then cr = Game_extractorRadius end
	local units = selectedUnits

	-- Get highest producing mex builder
	local maxbatchextracts = 0
	local lastprocessedbestbuilder
	for i = 1, #units do
		local id = units[i]
		if mexBuilder[id] then
			if mexIds[(mexBuilder[id].building[1]) * -1] > maxbatchextracts then
				maxbatchextracts = mexIds[(mexBuilder[id].building[1]) * -1]
				lastprocessedbestbuilder = id
			end
		end
	end

	-- Add highest producing mex builders to mainBuilders table + give guard orders to "inferior" builders
	local mainBuilders = {}
	local mainBuildersCount = 0
	local ux, uz, aveX, aveZ = 0, 0, 0, 0
	for i = 1, #units do
		local id = units[i]
		if mexBuilder[id] then
			if mexIds[(mexBuilder[id].building[1]) * -1] == maxbatchextracts then
				local x, _, z = spGetUnitPosition(id)
				ux, uz = ux+x, uz+z
				lastprocessedbestbuilder = id
				mainBuildersCount = mainBuildersCount + 1
				mainBuilders[mainBuildersCount] = id
			else
				-- guard to a main builder
				if not justDraw then
					if not options.shift then
						spGiveOrderToUnit(id, CMD_STOP, {}, CMD_OPT_RIGHT)
					end
					spGiveOrderToUnit(id, CMD_GUARD, { lastprocessedbestbuilder }, { "shift" })
				end
			end
		end
	end
	if mainBuildersCount == 0 then return end
	aveX, aveZ = ux/mainBuildersCount, uz/mainBuildersCount

	-- Get available mex spots within area
	local commands = {}
	local commandsCount = 0
	local mexes = isGuard and { isGuard } or WG.metalSpots -- only need the mex/spot we guard if that is the case
	for k = 1, #mexes do
		local mex = mexes[k]
		if not (mex.x % 16 == 8) then mexes[k].x = mexes[k].x + 8 - (mex.x % 16) end
		if not (mex.z % 16 == 8) then mexes[k].z = mexes[k].z + 8 - (mex.z % 16) end
		mex.x, mex.z = mexes[k].x, mexes[k].z
		if Distance(cx, cz, mex.x, mex.z) < cr * cr then
			if NoAlliedMex(mex.x, mex.z, maxbatchextracts) then
				commandsCount = commandsCount + 1
				commands[commandsCount] = { x = mex.x, z = mex.z, d = Distance(aveX, aveZ, mex.x, mex.z) }
			end
		end
	end

	-- Order available mex spots based on distance
	local orderedCommands = {}
	while commandsCount > 0 do
		tasort(commands, function(a, b)
			return a.d < b.d
		end)
		orderedCommands[#orderedCommands + 1] = commands[1]
		aveX, aveZ = commands[1].x, commands[1].z
		taremove(commands, 1)
		for k, com in pairs(commands) do
			com.d = Distance(aveX, aveZ, com.x, com.z)
		end
		commandsCount = commandsCount - 1
	end

	-- Shift key not used = give stop command first
	if not justDraw and not options.shift then
		for ct = 1, mainBuildersCount do
			spGiveOrderToUnit(mainBuilders[ct], CMD_STOP, {}, CMD_OPT_RIGHT)
		end
	end

	-- Give the actual mex build orders
	local queuedMexes = {}
	for ct = 1, mainBuildersCount do
		local id = mainBuilders[ct]
		for i = 1, #orderedCommands do
			local command = orderedCommands[i]
			for j = 1, mexBuilder[id].buildings do
				local targetPos
				local occupiedMex = IsSpotOccupied({x = command.x, z =command.z})
				if occupiedMex then
					targetPos = { spGetUnitPosition(occupiedMex) }
				else
					targetPos = GetClosestMexPosition(GetClosestMetalSpot(command.x, command.z), command.x, command.z, -mexBuilder[id].building[j], "s")
				end
				if targetPos then
					local newx, newz = targetPos[1], targetPos[3]
					queuedMexes[#queuedMexes+1] = {id, math.abs(mexBuilder[id].building[j]), newx, spGetGroundHeight(newx, newz), newz }
					if not justDraw then
						spGiveOrderToUnit(id, mexBuilder[id].building[j], { newx, spGetGroundHeight(newx, newz), newz }, { "shift" })
						lastInsertedOrder = {command.x, command.z}
					end
					break
				end
			end
		end
	end

	if isGuard and #queuedMexes == 0 then
		return		-- no mex buildorder made so let move go through!
	end
	return queuedMexes
end

local sec = 0
function widget:Update(dt)
	if chobbyInterface then return end

	local updateDrawUnitShape = activeUnitShape ~= nil
	sec = sec + dt
	if sec > 0.05 then
		sec = 0
		updateDrawUnitShape = true
	end

	local drawUnitShape = false
	local _, cmd, _ = spGetActiveCommand()
	if cmd == CMD_AREA_MEX then
		if spGetMapDrawMode() ~= 'metal' then
			if Spring.GetMapDrawMode() == "los" then
				retoggleLos = true
			end
			spSendCommands('ShowMetalMap')
			toggledMetal = true
		end
	else
		if toggledMetal then
			spSendCommands('ShowStandard')
			if retoggleLos then
				Spring.SendCommands("togglelos")
				retoggleLos = nil
			end
			toggledMetal = false
		end

		-- display mouse cursor/mex unitshape when hovering over a metalspot
		if not WG.customformations_linelength or WG.customformations_linelength < 10 then	-- dragging multi-unit formation-move-line
			local mx, my, mb = Spring.GetMouseState()
			local type, params = Spring.TraceScreenRay(mx, my)
			local isT1Mex = (type == 'unit' and mexIds[spGetUnitDefID(params)] and mexIds[spGetUnitDefID(params)] < 0.002)
			local closestMex, unitID
			if type == 'unit' then
				unitID = params
				params = {spGetUnitPosition(unitID)}
			end
			if isT1Mex or type == 'ground' then
				local proceed = false
				if type == 'ground' then
					closestMex = GetClosestMetalSpot(params[1], params[3])
					if closestMex and Distance(params[1], params[3], closestMex.x, closestMex.z) < mexPlacementRadius then
						proceed = true
					end
				end
				if isT1Mex or proceed then
					proceed = false
					local hasT1builder, hasT2builder = false, false
					-- search for builders
					for k,v in pairs(selUnitCounts) do
						if k ~= 'n' then
							if mexBuilderDef[k] then
								hasT1builder = true
							end
							if t2mexBuilder[k] then
								hasT2builder = true
								break
							end
						end
					end
					if isT1Mex then
						if hasT2builder then
							proceed = true
						end
					else
						if (hasT1builder or hasT2builder) and not IsSpotOccupied(closestMex) then
							proceed = true
						end
					end
					if proceed then
						if updateDrawUnitShape then
							local queuedMexes = doAreaMexCommand({params[1], params[2], params[3]}, {}, false, true)
							if queuedMexes and #queuedMexes > 0 then
								drawUnitShape = { queuedMexes[1][2], queuedMexes[1][3], queuedMexes[1][4], queuedMexes[1][5] }
								Spring.SetMouseCursor('upgmex')
							end
						end
					end
				end
			end
		end
	end

	if updateDrawUnitShape and WG.DrawUnitShapeGL4 then
		if drawUnitShape then
			if not activeUnitShape then
				activeUnitShape = {
					drawUnitShape[1],
					drawUnitShape[2],
					drawUnitShape[3],
					drawUnitShape[4],
					WG.DrawUnitShapeGL4(drawUnitShape[1], drawUnitShape[2], drawUnitShape[3], drawUnitShape[4], 0, 0.66, spGetMyTeamID(), 0.15, 0.3)
				}
			end
		elseif activeUnitShape then
			WG.StopDrawUnitShapeGL4(activeUnitShape[5])
			activeUnitShape = nil
		end
	end
end

function widget:Shutdown()
	if WG.DrawUnitShapeGL4 and activeUnitShape then
		WG.StopDrawUnitShapeGL4(activeUnitShape[5])
		activeUnitShape = nil
	end
end

function widget:CommandNotify(id, params, options)
	local isMove = (id == CMD_MOVE)
	local isGuard = (id == CMD_GUARD)
	if not (id == CMD_AREA_MEX or isMove or isGuard) then
		return
	end
	if isGuard then
		local mx, my = Spring.GetMouseState()
		local type, unitID = Spring.TraceScreenRay(mx, my)
		if not (type == 'unit' and mexIds[spGetUnitDefID(unitID)] and mexIds[spGetUnitDefID(unitID)] < 0.002) then
			return
		end
	end

	-- transform move into area-mex command
	local moveReturn = false
	if mexBuilder[selectedUnits[1]] then
		if isGuard then
			local ux, uy, uz = spGetUnitPosition(params[1])
			isGuard = { x = ux, y = uy, z = uz }
			params[1], params[2], params[3] = ux, uy, uz
			id = CMD_AREA_MEX
			params[4] = 30 		-- increase this too if you want to increase mexPlacementRadius
			lastInsertedOrder = nil
		elseif isMove and moveIsAreamex then
			local closestMex = GetClosestMetalSpot(params[1], params[3])
			local spotRadius = mexPlacementRadius
			if #selectedUnits == 1 and #Spring.GetCommandQueue(selectedUnits[1], 8) > 1 then
				if not lastInsertedOrder or (closestMex.x ~= lastInsertedOrder[1] and closestMex.z ~= lastInsertedOrder[2]) then
					spotRadius = mexPlacementDragRadius		-- make move drag near mex spots be less strict
				elseif lastInsertedOrder then
					spotRadius = 0
				end
			else
				lastInsertedOrder = nil
			end
			if spotRadius > 0 and closestMex and Distance(params[1], params[3], closestMex.x, closestMex.z) < spotRadius then
				id = CMD_AREA_MEX
				params[4] = 120		-- increase this too if you want to increase mexPlacementDragRadius
				moveReturn = true
			else
				return false
			end
		end
	end

	if id == CMD_AREA_MEX then
		local queuedMexes = doAreaMexCommand(params, options, isGuard)
		if moveReturn and not queuedMexes[1] then	-- used when area_mex isnt queuing a mex, to let the move cmd still pass through
			return false
		end
		return true
	end
end

function widget:CommandsChanged()
	if not metalmap then
		local unitCount = #selectedUnits
		if unitCount > 0 then
			local units = selectedUnits
			local customCommands = widgetHandler.customCommands
			for i = 1, unitCount do
				if mexBuilder[units[i]] then
					customCommands[#customCommands + 1] = {
						id = CMD_AREA_MEX,
						type = CMDTYPE.ICON_AREA,
						tooltip = 'Define an area (with metal spots in it) to make metal extractors in',
						name = 'Mex',
						cursor = 'areamex',
						action = 'areamex',
					}
					return
				end
			end
		end
	end
end

function widget:Initialize()
	if not WG.metalSpots or (#WG.metalSpots > 0 and #WG.metalSpots <= 2) then
		metalmap = true
		--widgetHandler:RemoveWidget(self)
		--return
	end
	local units = spGetTeamUnits(spGetMyTeamID())
	for i = 1, #units do
		local id = units[i]
		widget:UnitCreated(id, spGetUnitDefID(id))
	end
end
