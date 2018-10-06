local versionNumber = "v2.5 - Doo Edit, BA specific"

function widget:GetInfo()
  return {
    name      = "Area Mex",
    desc      = versionNumber .. " Adds a command to cap mexes in an area.",
    author    = "Google Frog, NTG (file handling), Chojin (metal map), Doo Edit on Dec 13, 2017 (multiple enhancements)",
    date      = "Oct 23, 2010",
    license   = "GNU GPL, v2 or later",
    handler   = true,
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--changelog (starting from 2.4)
-- v2.5 (21/04/2018)
-- Use Mex Snap's code to detect available positions for mexes
--
-- v2.4 (03/19/18 - Doo)
-- Using WG.metalSpots instead of analyzing map at initialize()
-- Erased non BA configs (since this version is only packed within BA)


local maxMetalData = 40000 --2500000
local pathToSave = "LuaUI/Widgets_BA/MetalMaps/" -- where to store mexmaps (MaDDoX: edited for BA 9.5x)
-----------------
--command notification and mex placement

local CMD_AREA_MEX       = 10100

local CMD_OPT_SHIFT = CMD.OPT_SHIFT

local spGetSelectedUnits = Spring.GetSelectedUnits
local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spGetGroundHeight = Spring.GetGroundHeight
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitPosition = Spring.GetUnitPosition 
local spGetTeamUnits = Spring.GetTeamUnits
local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitDefID = Spring.GetUnitDefID
local team = Spring.GetMyTeamID()
local spTestBuildOrder = Spring.TestBuildOrder

local spGetActiveCommand = Spring.GetActiveCommand
local spGetMapDrawMode = Spring.GetMapDrawMode
local spSendCommands = Spring.SendCommands

local toggledMetal

local mexIds = {}
local mexes = {}

local sqrt = math.sqrt
local tasort = table.sort
local taremove = table.remove

local mexBuilderDef = {}

local mexBuilder = {}


local function Distance(x1,z1,x2,z2)
	local dis = (x1-x2)*(x1-x2)+(z1-z2)*(z1-z2)
	return dis
end

function widget:UnitCreated(unitID, unitDefID)

	local ud = UnitDefs[unitDefID]
	if mexBuilderDef[ud] then
		mexBuilder[unitID] = mexBuilderDef[ud]
		return
	end

	if ud.buildOptions then
		for i, option in ipairs(ud.buildOptions) do
			if mexIds[option] then
				if mexBuilderDef[ud] then
					mexBuilderDef[ud].buildings = mexBuilderDef[ud].buildings+1
					mexBuilderDef[ud].building[mexBuilderDef[ud].buildings] = mexIds[option]*-1
				else
					mexBuilderDef[ud] = {buildings = 1, building = {[1] = mexIds[option]*-1}}
				end
				mexBuilder[unitID] = mexBuilderDef[ud]
			end
		end
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

function widget:Update()
	local _,cmd,_ = spGetActiveCommand()
	if (cmd == CMD_AREA_MEX) then
		if (spGetMapDrawMode() ~= 'metal') then
			if Spring.GetMapDrawMode() == "los" then
				retoggleLos = true
			end
			spSendCommands({'ShowMetalMap'})
			toggledMetal = true
		end
	else
		if toggledMetal then
			spSendCommands({'ShowStandard'})
		    if retoggleLos then
		        Spring.SendCommands("togglelos")
				retoggleLos = nil
		    end
			toggledMetal = false
		end
	end
end

function AreAlliedUnits(unitID) -- Is unitID allied with me ?
return Spring.AreTeamsAllied(Spring.GetMyTeamID(), Spring.GetUnitTeam(unitID))
end

function NoAlliedMex(x,z, batchextracts) -- Is there any better and allied mex at this location (returns false if there is)
	local mexesatspot = Spring.GetUnitsInCylinder(x,z, Game.extractorRadius)
		for ct, uid in pairs(mexesatspot) do
			if mexIds[Spring.GetUnitDefID(uid)] and AreAlliedUnits(uid) and UnitDefs[Spring.GetUnitDefID(uid)].extractsMetal >= batchextracts then
				return false
			end	
		end
	return true
end
local function GetClosestMetalSpot(x, z)
	local bestSpot
	local bestDist = math.huge
	local metalSpots = WG.metalSpots
	for i = 1, #metalSpots do
		local spot = metalSpots[i]
		local dx, dz = x - spot.x, z - spot.z
		local dist = dx*dx + dz*dz
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
		local dist = dx*dx + dz*dz
		if dist < bestDist then
			bestPos = pos
			bestDist = dist
		end
	end
	return bestPos
end

function widget:CommandNotify(id, params, options)	
	if (id == CMD_AREA_MEX) then
	mexes = WG.metalSpots

		local cx, cy, cz, cr = params[1], params[2], params[3], params[4]
		if (not cr) or (cr < Game.extractorRadius) then
			cr = Game.extractorRadius
		end
		local cr = cr
		
		local xmin = cx-cr
		local xmax = cx+cr
		local zmin = cz-cr
		local zmax = cz+cr
		
		local commands = {}
		local orderedCommands = {}
		local dis = {}
		
		local ux = 0
		local uz = 0
		local us = 0
		
		local aveX = 0
		local aveZ = 0
		
		local units=spGetSelectedUnits()
		local maxbatchextracts = 0
		local batchMexBuilder = {}
		local lastprocessedbestbuilder = nil
		
		for i, id in pairs(units) do 
		if mexBuilder[id] then -- Get best extract rates, save best builderID
			if UnitDefs[(mexBuilder[id].building[1])*-1].extractsMetal > maxbatchextracts then
				maxbatchextracts = UnitDefs[(mexBuilder[id].building[1])*-1].extractsMetal
				lastprocessedbestbuilder = id
			end
		end
		end
		
		local batchSize = 0
		local shift = options.shift

		for i, id in pairs(units) do -- Check position, apply guard orders to "inferiors" builders and adds superior builders to current batch builders
			if mexBuilder[id] then
				if UnitDefs[(mexBuilder[id].building[1])*-1].extractsMetal == maxbatchextracts then
				local x,_,z = spGetUnitPosition(id)
				ux = ux+x
				uz = uz+z
				us = us+1
				lastprocessedbestbuilder = id
				batchSize = batchSize + 1
				batchMexBuilder[batchSize] = id
				else
					if not shift then 
					spGiveOrderToUnit(id, CMD.STOP, {} , CMD.OPT_RIGHT )
					end
				local cmdQueue = Spring.GetUnitCommands(id, 1)
				spGiveOrderToUnit(id, CMD.GUARD, {lastprocessedbestbuilder} , {"shift"})
				end
			end
		end
		
	
		if (us == 0) then
			return
		else
			aveX = ux/us
			aveZ = uz/us
		end
	
		for k, mex in pairs(mexes) do		
			if not (mex.x%16 == 8) then
				mexes[k].x = mexes[k].x + 8 - (mex.x%16)
			end
			if not (mex.z%16 == 8) then
				mexes[k].z = mexes[k].z + 8 - (mex.z%16)
			end
			mex.x = mexes[k].x
			mex.z = mexes[k].z
			if (Distance(cx,cz,mex.x,mex.z) < cr^2) then -- circle area, slower
				if NoAlliedMex(mex.x, mex.z, maxbatchextracts) == true then
					commands[#commands+1] = {x = mex.x, z = mex.z, d = Distance(aveX,aveZ,mex.x,mex.z)}
				end
			
			end
		end
	
		local noCommands = #commands
		while noCommands > 0 do
	  
			tasort(commands, function(a,b) return a.d < b.d end)
			orderedCommands[#orderedCommands+1] = commands[1]
			aveX = commands[1].x
			aveZ = commands[1].z
			taremove(commands, 1)
			for k, com in pairs(commands) do		
				com.d = Distance(aveX,aveZ,com.x,com.z)
			end
			noCommands = noCommands-1
		end
	
		local shift = options.shift
		local ctrl = options.ctrl or options.meta
		for ct, id in pairs(batchMexBuilder) do
			if not shift then 
				spGiveOrderToUnit(id, CMD.STOP, {} , CMD.OPT_RIGHT )
			end
		end
		
			local shift = true
		for ct, id in pairs(batchMexBuilder) do 

				for i, command in ipairs(orderedCommands) do
					local Y = Spring.GetGroundHeight(command.x, command.z)
					local spotSize = 0 -- GetSpotSize(x, z)
					if ((i % batchSize == ct % batchSize or i % #orderedCommands == ct % #orderedCommands) and ctrl) or not ctrl then
					for j=1, mexBuilder[id].buildings do
						local def = UnitDefs[-mexBuilder[id].building[j]]
						local buildable = 0
						newx, newz = command.x, command.z
						if not (buildable ~= 0) then -- If location unavailable, check surroundings (extractorRadius - 25). Should consider replacing 25 with avg mex x,z sizes
							local bestPos = GetClosestMexPosition(GetClosestMetalSpot(newx, newz), newx-2*Game.extractorRadius, newz-2*Game.extractorRadius, -mexBuilder[id].building[j], "s")
							if bestPos then
								newx, newz = bestPos[1], bestPos[3]
								buildable = true
							end
						end

						-- for ox = 0, Game.extractorRadius do
								-- for oz = 0, Game.extractorRadius do
										-- if math.sqrt(ox^2 + oz^2) <= math.sqrt(Game.extractorRadius^2)-spotSize and spTestBuildOrder(-mexBuilder[id].building[j],command.x + ox,spGetGroundHeight(command.x + ox,command.z + oz),command.z + oz,1) ~= 0 then
											-- buildable = spTestBuildOrder(-mexBuilder[id].building[j],command.x + ox,spGetGroundHeight(command.x + ox,command.z + oz),command.z + oz,1)
											-- newx = command.x + ox
											-- newz = command.z + oz
											-- break
										-- elseif math.sqrt(ox^2 + oz^2) <= math.sqrt(Game.extractorRadius^2)-spotSize and spTestBuildOrder(-mexBuilder[id].building[j],command.x - ox,spGetGroundHeight(command.x - ox,command.z + oz),command.z + oz,1) ~= 0 then
											-- buildable = spTestBuildOrder(-mexBuilder[id].building[j],command.x + ox,spGetGroundHeight(command.x + ox,command.z + oz),command.z + oz,1)
											-- newx = command.x - ox
											-- newz = command.z + oz
											-- break
										
										-- elseif math.sqrt(ox^2 + oz^2) <= math.sqrt(Game.extractorRadius^2)-spotSize and spTestBuildOrder(-mexBuilder[id].building[j],command.x + ox,spGetGroundHeight(command.x + ox,command.z - oz),command.z - oz,1) ~= 0 then
											-- buildable = spTestBuildOrder(-mexBuilder[id].building[j],command.x + ox,spGetGroundHeight(command.x + ox,command.z + oz),command.z + oz,1)
											-- newx = command.x + ox
											-- newz = command.z - oz
											-- break
										
										-- elseif math.sqrt(ox^2 + oz^2) <= math.sqrt(Game.extractorRadius^2)-spotSize and spTestBuildOrder(-mexBuilder[id].building[j],command.x - ox,spGetGroundHeight(command.x - ox,command.z - oz),command.z - oz,1) ~= 0 then
											-- buildable = spTestBuildOrder(-mexBuilder[id].building[j],command.x + ox,spGetGroundHeight(command.x + ox,command.z + oz),command.z + oz,1)
											-- command.x = command.x - ox
											-- command.z = command.z - oz
											-- break
										-- end			
									-- if buildable ~= 0 then
										-- break
									-- end
								-- end
								-- if buildable ~= 0 then
									-- break
								-- end
							-- end
						-- end
						if buildable ~= 0 then
							spGiveOrderToUnit(id, mexBuilder[id].building[j], {newx,spGetGroundHeight(newx,newz),newz} , {"shift"})
							break
						elseif def.maxWaterDepth and -def.maxWaterDepth < Y and def.minWaterDepth and -def.minWaterDepth > Y then
							local hsize = def.xsize*4
							local unitsatmex = Spring.GetUnitsInRectangle(command.x-hsize, command.z-hsize, command.x+hsize, command.z + hsize)
							local blockers = {}
							for x = command.x - hsize, command.x + hsize, 8 do
								for z = command.z - hsize, command.z + hsize, 8 do
									local _,blocker = Spring.GetGroundBlocked(x,z,x+7,z+7)
									if blocker and not blockers[blocker] then 
										spGiveOrderToUnit(id, CMD.RECLAIM, {blocker}, {"shift"})
										blockers[blocker] = true
									end
								end
							end
							spGiveOrderToUnit(id, CMD.INSERT, {-1, mexBuilder[id].building[j], CMD.OPT_INTERNAL, command.x,spGetGroundHeight(command.x,command.z),command.z} , {shift = true, internal = true, alt = true})
							break
						end
					end
				end
				end
			end
		
  
		return true
  
	end
  
end

--------------------

function widget:CommandsChanged()
	local units=spGetSelectedUnits()
	for i, id in pairs(units) do 
		if mexBuilder[id] then
			local customCommands = widgetHandler.customCommands
			
			table.insert(customCommands, {			
				id      = CMD_AREA_MEX,
				type    = CMDTYPE.ICON_AREA,
				tooltip = 'Define an area to make mexes in',
				name    = 'Mex',
				cursor  = 'Repair',
				action  = 'areamex',
			})
			return
		end
	end
end

function widget:Initialize()
	if not WG.metalSpots then
		Spring.Echo("<Area Mex> This widget requires the 'Metalspot Finder' widget to run.")
		widgetHandler:RemoveWidget(self)
	end
	mexIds[UnitDefNames['armmex'].id] = UnitDefNames['armmex'].id 
	mexIds[UnitDefNames['cormex'].id] = UnitDefNames['cormex'].id 
	mexIds[UnitDefNames['armmoho'].id] = UnitDefNames['armmoho'].id 
	mexIds[UnitDefNames['cormoho'].id] = UnitDefNames['cormoho'].id 		
	mexIds[UnitDefNames['armuwmex'].id] = UnitDefNames['armuwmex'].id 
	mexIds[UnitDefNames['coruwmex'].id] = UnitDefNames['coruwmex'].id 
	mexIds[UnitDefNames['armuwmme'].id] = UnitDefNames['armuwmme'].id 
	mexIds[UnitDefNames['coruwmme'].id] = UnitDefNames['coruwmme'].id 
	local units = spGetTeamUnits(spGetMyTeamID())
	for i, id in ipairs(units) do 
		widget:UnitCreated(id, spGetUnitDefID(id))
	end
end