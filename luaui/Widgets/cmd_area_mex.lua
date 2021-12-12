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

local mexPlacementRadius = 700	-- (not actual ingame distance)
local mexPlacementDragRadius = 20000	-- larger size so you can drag a move line over/near mex spots and it will auto queue mex there more easily

local CMD_AREA_MEX = 10100
local CMD_MOVE = CMD.MOVE
local CMD_STOP = CMD.STOP
local CMD_GUARD = CMD.GUARD
local CMD_OPT_RIGHT = CMD.OPT_RIGHT

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetSelectedUnitsCounts = Spring.GetSelectedUnitsCounts
local spGetGroundHeight = Spring.GetGroundHeight
local spGetGroundBlocked = Spring.GetGroundBlocked
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitPosition = Spring.GetUnitPosition
local spGetTeamUnits = Spring.GetTeamUnits
local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitDefID = Spring.GetUnitDefID

local spGetActiveCommand = Spring.GetActiveCommand
local spGetMapDrawMode = Spring.GetMapDrawMode
local spSendCommands = Spring.SendCommands

local toggledMetal, retoggleLos, chobbyInterface, lastInsertedOrder

local tasort = table.sort
local taremove = table.remove

local activeCmd = select(4, spGetActiveCommand())
local buildmenuMexSelected = false

local mexes = {}
local mexBuilder = {}

local mexIds = {}
local unitWaterDepth = {}
local unitXsize = {}
--local isCommander = {}
for udid, ud in pairs(UnitDefs) do
	if ud.extractsMetal > 0 then
		mexIds[udid] = ud.extractsMetal
	end
	if ud.isBuilding then
		unitWaterDepth[udid] = { ud.minWaterDepth, ud.maxWaterDepth }
		unitXsize[udid] = ud.xsize
	end
	--if ud.customParams.iscommander then
	--	isCommander[udid] = true
	--end
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

local function NoAlliedMex(x, z, batchextracts)
	-- Is there any better and allied mex at this location (returns false if there is)
	local mexesatspot = Spring.GetUnitsInCylinder(x, z, Game.extractorRadius)
	for i = 1, #mexesatspot do
		local uid = mexesatspot[i]
		if mexIds[spGetUnitDefID(uid)] and Spring.AreTeamsAllied(Spring.GetMyTeamID(), Spring.GetUnitTeam(uid)) and mexIds[spGetUnitDefID(uid)] >= batchextracts then
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
	local scale = 0.77 + ((math.max(spot.maxX,spot.minX)-(math.min(spot.maxX,spot.minX))) * (math.max(spot.maxZ,spot.minZ)-(math.min(spot.maxZ,spot.minZ)))) / 10000
	local units = Spring.GetUnitsInSphere(spot.x, spot.y, spot.z, 115*scale)
	local occupied = false
	for j=1, #units do
		if mexIds[spGetUnitDefID(units[j])]  then
			occupied = true
			break
		end
	end
	return occupied
end

function widget:Update()
	if chobbyInterface then
		return
	end

	-- swap build command to area mex when mex is selected
	local prevActiveCmd = activeCmd
	activeCmd = select(2, spGetActiveCommand())
	if activeCmd ~= prevActiveCmd then
		if activeCmd and activeCmd < 0 and mexIds[activeCmd * -1] then
			buildmenuMexSelected = true
			-- only transform to areamex cmd after user starts dragging
		else
			buildmenuMexSelected = false
		end
	end

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


		-- mex-upgrade mouse cursor
		local mx, my = Spring.GetMouseState()
		local type, params = Spring.TraceScreenRay(mx, my)
		local isT1Mex = (type == 'unit' and mexIds[Spring.GetUnitDefID(params)] and mexIds[Spring.GetUnitDefID(params)] < 0.002)
		local closestMex
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
				local selUnitCounts = spGetSelectedUnitsCounts()
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
					Spring.SetMouseCursor('upgmex')
				end
			end
		end
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
		if not (type == 'unit' and mexIds[Spring.GetUnitDefID(unitID)] and mexIds[Spring.GetUnitDefID(unitID)] < 0.002) then
			return
		end
	end

	-- transform move (for mex builders) into area-mex command
	local units = spGetSelectedUnits()
	if (isGuard or (isMove and moveIsAreamex)) and mexBuilder[units[1]] then
		--local proceed = true --#units == 1 or isGuard
		--local selUnitCounts = spGetSelectedUnitsCounts()
		--for k,v in pairs(selUnitCounts) do
		--	if k ~= 'n' and not mexBuilderDef[k] then
		--		proceed = false
		--		break
		--	end
		--end
		-- transform move into area-mex command
		-- NOTE: not sure this is wanted for commanders ...when enemy is near
		--if proceed then
			if isGuard then
				local ux, uy, uz = Spring.GetUnitPosition(params[1])
				isGuard = { x = ux, y = uy, z = uz }
				params[1], params[2], params[3] = ux, uy, uz
				id = CMD_AREA_MEX
				params[4] = 25
				lastInsertedOrder = nil
			else
				local closestMex = GetClosestMetalSpot(params[1], params[3])
				local spotRadius = mexPlacementRadius
				if #units == 1 and #Spring.GetCommandQueue(units[1], 8) > 1 then
					if (not lastInsertedOrder or (closestMex.x ~= lastInsertedOrder[1] and closestMex.z ~= lastInsertedOrder[2])) then
						spotRadius = mexPlacementDragRadius		-- make move drag near mex spots be less strict
					else
						spotRadius = 0
					end
				else
					lastInsertedOrder = nil
				end
				if spotRadius > 0 and closestMex and Distance(params[1], params[3], closestMex.x, closestMex.z) < spotRadius then
					id = CMD_AREA_MEX
					params[4] = 25
				else
					return
				end
			end
		--end
	end

	if id == CMD_AREA_MEX then
		if isGuard then
			mexes = { isGuard }	-- only need the mex we guard
		else
			mexes = WG.metalSpots
		end
		local cx, cy, cz, cr = params[1], params[2], params[3], params[4]
		if not cr or cr < Game.extractorRadius then
			cr = Game.extractorRadius
		end

		local commands = {}
		local commandsCount = 0
		local orderedCommands = {}
		local ux, uz, us, aveX, aveZ = 0, 0, 0, 0, 0
		local maxbatchextracts = 0
		local batchMexBuilder = {}
		local lastprocessedbestbuilder = nil

		for i = 1, #units do
			local id = units[i]
			if mexBuilder[id] then
				-- Get best extract rates, save best builderID
				if mexIds[(mexBuilder[id].building[1]) * -1] > maxbatchextracts then
					maxbatchextracts = mexIds[(mexBuilder[id].building[1]) * -1]
					lastprocessedbestbuilder = id
				end
			end
		end

		local batchSize = 0
		local shift = options.shift
		for i = 1, #units do
			-- Check position, apply guard orders to "inferiors" builders and adds superior builders to current batch builders
			local id = units[i]
			if mexBuilder[id] then
				if mexIds[(mexBuilder[id].building[1]) * -1] == maxbatchextracts then
					local x, _, z = spGetUnitPosition(id)
					ux = ux + x
					uz = uz + z
					us = us + 1
					lastprocessedbestbuilder = id
					batchSize = batchSize + 1
					batchMexBuilder[batchSize] = id
				else
					if not shift then
						spGiveOrderToUnit(id, CMD_STOP, {}, CMD_OPT_RIGHT)
					end
					spGiveOrderToUnit(id, CMD_GUARD, { lastprocessedbestbuilder }, { "shift" })
				end
			end
		end

		if us == 0 then
			return
		end
		aveX = ux / us
		aveZ = uz / us

		for k = 1, #mexes do
			local mex = mexes[k]
			if not (mex.x % 16 == 8) then
				mexes[k].x = mexes[k].x + 8 - (mex.x % 16)
			end
			if not (mex.z % 16 == 8) then
				mexes[k].z = mexes[k].z + 8 - (mex.z % 16)
			end
			mex.x = mexes[k].x
			mex.z = mexes[k].z
			if Distance(cx, cz, mex.x, mex.z) < cr * cr then
				-- circle area, slower
				if NoAlliedMex(mex.x, mex.z, maxbatchextracts) == true then
					commandsCount = commandsCount + 1
					commands[commandsCount] = { x = mex.x, z = mex.z, d = Distance(aveX, aveZ, mex.x, mex.z) }
				end
			end
		end

		local noCommands = commandsCount
		while noCommands > 0 do
			tasort(commands, function(a, b)
				return a.d < b.d
			end)
			orderedCommands[#orderedCommands + 1] = commands[1]
			aveX = commands[1].x
			aveZ = commands[1].z
			taremove(commands, 1)
			for k, com in pairs(commands) do
				com.d = Distance(aveX, aveZ, com.x, com.z)
			end
			noCommands = noCommands - 1
		end

		local shift = options.shift
		local ctrl = options.ctrl or options.meta
		for ct = 1, #batchMexBuilder do
			local id = batchMexBuilder[ct]
			if not shift then
				spGiveOrderToUnit(id, CMD_STOP, {}, CMD_OPT_RIGHT)
			end
		end

		local mexQueued = false
		for ct = 1, #batchMexBuilder do
			local id = batchMexBuilder[ct]

			for i = 1, #orderedCommands do
				local command = orderedCommands[i]

				local Y = spGetGroundHeight(command.x, command.z)
				if ((i % batchSize == ct % batchSize or i % #orderedCommands == ct % #orderedCommands) and ctrl) or not ctrl then
					for j = 1, mexBuilder[id].buildings do
						local def = unitWaterDepth[-mexBuilder[id].building[j]]

						local buildable = 0
						local newx, newz = command.x, command.z
						if not buildable ~= 0 then
							-- If location unavailable, check surroundings (extractorRadius - 25). Should consider replacing 25 with avg mex x,z sizes
							--local bestPos = GetClosestMexPosition(GetClosestMetalSpot(newx, newz), newx - 2 * Game.extractorRadius, newz - 2 * Game.extractorRadius, -mexBuilder[id].building[j], "s")
							local bestPos = GetClosestMexPosition(GetClosestMetalSpot(newx, newz), newx, newz, -mexBuilder[id].building[j], "s")
							if bestPos then
								newx, newz = bestPos[1], bestPos[3]
								buildable = true
							end
						end

						if buildable ~= 0 then
							mexQueued = true
							spGiveOrderToUnit(id, mexBuilder[id].building[j], { newx, spGetGroundHeight(newx, newz), newz }, { "shift" })
							lastInsertedOrder = {command.x, command.z}
							break
						elseif def[2] and -def[2] < Y and def[1] and -def[1] > Y then
							local hsize = unitXsize[-mexBuilder[id].building[j]] * 4
							local blockers = {}
							for x = command.x - hsize, command.x + hsize, 8 do
								for z = command.z - hsize, command.z + hsize, 8 do
									local _, blocker = spGetGroundBlocked(x, z, x + 7, z + 7)
									if blocker and not blockers[blocker] then
										spGiveOrderToUnit(id, CMD.RECLAIM, { blocker }, { "shift" })
										blockers[blocker] = true
									end
								end
							end
							mexQueued = true
							spGiveOrderToUnit(id, CMD.INSERT, { -1, mexBuilder[id].building[j], CMD.OPT_INTERNAL, command.x, spGetGroundHeight(command.x, command.z), command.z }, { shift = true, internal = true, alt = true })
							lastInsertedOrder = {command.x, command.z}
							break
						end
					end
				end
			end
		end
		if (isMove or isGuard) and not mexQueued then
			return		-- no mex buildorder made so let move go through!
		end
		return true
	end
end

function widget:CommandsChanged()
	local units = spGetSelectedUnits()
	local unitCount = #units
	if unitCount > 0 then
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

function widget:Initialize()
	--if not WG.metalSpots or (#WG.metalSpots > 0 and #WG.metalSpots <= 2) then
	--	widgetHandler:RemoveWidget(self)
	--	return
	--end
	local units = spGetTeamUnits(spGetMyTeamID())
	for i = 1, #units do
		local id = units[i]
		widget:UnitCreated(id, spGetUnitDefID(id))
	end
end
