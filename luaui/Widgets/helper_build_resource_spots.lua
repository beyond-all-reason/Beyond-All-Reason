function widget:GetInfo()
	return {
		name = "Helper - Build on Resource Spots",
		desc = "Provides shared methods/variables that are used to build extractors on resource spots",
		author = "Google Frog, NTG (file handling), Chojin (metal map), Doo (multiple enhancements), Floris (mex placer/upgrader), Tarte (maintenance)",
		date = "Oct 23, 2010 (last update: March 3, 2022)",
		license = "GNU GPL, v2 or later",
		handler = true,
		layer = 0,
		enabled = true  --  loaded by default?
	}
end

local CMD_STOP = CMD.STOP
local CMD_GUARD = CMD.GUARD
local CMD_OPT_RIGHT = CMD.OPT_RIGHT

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetSelectedUnitsCounts = Spring.GetSelectedUnitsCounts
local spGetGroundHeight = Spring.GetGroundHeight
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetTeamUnits = Spring.GetTeamUnits
local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID

local selectedUnits = spGetSelectedUnits()
local selUnitsCount = spGetSelectedUnitsCounts()

local lastInsertedOrder

local tasort = table.sort
local taremove = table.remove

local Game_extractorRadius = Game.extractorRadius

local metalMap = false
local mexBuilder = {}
local mexBuilderDef = {}
local mexBuilderT2 = {}
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
			mexBuilderT2[udid] = true
		end
	end
end

function widget:SelectionChanged(sel)
	selectedUnits = sel
	selUnitsCount = spGetSelectedUnitsCounts()
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

local function Distance(x1, z1, x2, z2)
	return (x1 - x2) * (x1 - x2) + (z1 - z2) * (z1 - z2)
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


local function BuildMetalExtractors(params, options, isGuard, justDraw)		-- when isGuard: needs to be a table of the unit pos: { x = ux, y = uy, z = uz }
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
				if z then
					ux, uz = ux+x, uz+z
					lastprocessedbestbuilder = id
					mainBuildersCount = mainBuildersCount + 1
					mainBuilders[mainBuildersCount] = id
				end
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
				local targetPos, targetOwner
				local occupiedMex = IsSpotOccupied({x = command.x, z =command.z})
				if occupiedMex then
					targetPos = { spGetUnitPosition(occupiedMex) }
					targetOwner = Spring.GetUnitTeam(occupiedMex)	-- because gadget "Mex Upgrade Reclaimer" will share a t2 mex build upon ally t1 mex
				else
					targetPos = GetClosestMexPosition(GetClosestMetalSpot(command.x, command.z), command.x, command.z, -mexBuilder[id].building[j], "s")
					targetOwner = spGetMyTeamID()
				end
				if targetPos then
					local newx, newz = targetPos[1], targetPos[3]
					queuedMexes[#queuedMexes+1] = { id, math.abs(mexBuilder[id].building[j]), newx, spGetGroundHeight(newx, newz), newz, targetOwner }
					if not justDraw then
						spGiveOrderToUnit(id, mexBuilder[id].building[j], { newx, spGetGroundHeight(newx, newz), newz }, { "shift" })
						lastInsertedOrder = { command.x, command.z}
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



function widget:Initialize()
	if not WG.metalSpots or (#WG.metalSpots > 0 and #WG.metalSpots <= 2) then
		metalMap = true
	end
	local units = spGetTeamUnits(spGetMyTeamID())
	for i = 1, #units do
		local id = units[i]
		widget:UnitCreated(id, spGetUnitDefID(id))
	end


	--make interfaces available to other widgets:
	WG['helperBuildResourceSpot'] = { }


	WG['helperBuildResourceSpot'].Distance = function(x1, z1, x2, z2)
		return Distance (x1, z1, x2, z2)
	end

	WG['helperBuildResourceSpot'].GetClosestMetalSpot = function(x, z)
		return GetClosestMetalSpot (x, z)
	end

	WG['helperBuildResourceSpot'].BuildMetalExtractors = function(params, options, isGuard, justDraw)
		return BuildMetalExtractors (params, options, isGuard, justDraw)
	end

	WG['helperBuildResourceSpot'].GetSelectedUnits = function()
		return selectedUnits
	end

	WG['helperBuildResourceSpot'].GetSelectedUnitsCount = function()
		return selUnitsCount
	end

	WG['helperBuildResourceSpot'].isMetalMap = function()
		return metalMap
	end

	WG['helperBuildResourceSpot'].GetMexBuilder = function()
		return mexBuilder
	end

	WG['helperBuildResourceSpot'].GetMexBuilderDef = function()
		return mexBuilderDef
	end

	WG['helperBuildResourceSpot'].GetMexBuilderT2 = function()
		return mexBuilderT2
	end

	WG['helperBuildResourceSpot'].GetMexIds = function()
		return mexIds
	end
end
