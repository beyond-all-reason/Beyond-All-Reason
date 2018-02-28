local versionNumber = "v2.3 - Doo Edit"

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

-- local function GetSpotSize(x, z)
	-- spotSize = 24
	-- if WG.metalSpots then
		-- local bestSpot
		-- local bestDist = math.huge
		-- local metalSpots = WG.metalSpots
		-- for i = 1, #metalSpots do
			-- local spot = metalSpots[i]
			-- local dx, dz = x - spot.x, z - spot.z
			-- local dist = dx*dx + dz*dz
			-- if dist < bestDist then
				-- bestSpot = spot
				-- bestDist = dist
			-- end
		-- end
		-- if bestSpot.maxZ and bestSpot.minZ then
		-- spotSize = math.abs(bestSpot.maxZ - bestSpot.minZ)/2
		-- end
	-- else
		-- spotSize = 24
	-- end
	-- return spotSize
-- end

function widget:UnitCreated(unitID, unitDefID)
  
	local ud = UnitDefs[unitDefID]
	--Spring.Echo((Spring.GetModOptions().mo_unba or "disabled") == "enabled")
	if (Spring.GetModOptions().mo_unba or "disabled") == "enabled" and (UnitDefs[unitDefID].name == "armcom" or UnitDefs[unitDefID].name == "corcom") then
		return
	else
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

function widget:CommandNotify(id, params, options)	
	
	if (id == CMD_AREA_MEX) then

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
			--if (mex.x > xmin) and (mex.x < xmax) and (mex.z > zmin) and (mex.z < zmax) then -- square area, should be faster
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
					local spotSize = 0 -- GetSpotSize(x, z)
					if ((i % batchSize == ct % batchSize or i % #orderedCommands == ct % #orderedCommands) and ctrl) or not ctrl then
					for j=1, mexBuilder[id].buildings do
						local buildable = spTestBuildOrder(-mexBuilder[id].building[j],command.x,spGetGroundHeight(command.x,command.z),command.z,1)
						newx, newz = command.x, command.z
						if not (buildable ~= 0) then -- If location unavailable, check surroundings (extractorRadius - 25). Should consider replacing 25 with avg mex x,z sizes
							for ox = 0, Game.extractorRadius do
								for oz = 0, Game.extractorRadius do
										if math.sqrt(ox^2 + oz^2) <= math.sqrt(Game.extractorRadius^2)-spotSize and spTestBuildOrder(-mexBuilder[id].building[j],command.x + ox,spGetGroundHeight(command.x + ox,command.z + oz),command.z + oz,1) ~= 0 then
											buildable = spTestBuildOrder(-mexBuilder[id].building[j],command.x + ox,spGetGroundHeight(command.x + ox,command.z + oz),command.z + oz,1)
											newx = command.x + ox
											newz = command.z + oz
											break
										elseif math.sqrt(ox^2 + oz^2) <= math.sqrt(Game.extractorRadius^2)-spotSize and spTestBuildOrder(-mexBuilder[id].building[j],command.x - ox,spGetGroundHeight(command.x - ox,command.z + oz),command.z + oz,1) ~= 0 then
											buildable = spTestBuildOrder(-mexBuilder[id].building[j],command.x + ox,spGetGroundHeight(command.x + ox,command.z + oz),command.z + oz,1)
											newx = command.x - ox
											newz = command.z + oz
											break
										
										elseif math.sqrt(ox^2 + oz^2) <= math.sqrt(Game.extractorRadius^2)-spotSize and spTestBuildOrder(-mexBuilder[id].building[j],command.x + ox,spGetGroundHeight(command.x + ox,command.z - oz),command.z - oz,1) ~= 0 then
											buildable = spTestBuildOrder(-mexBuilder[id].building[j],command.x + ox,spGetGroundHeight(command.x + ox,command.z + oz),command.z + oz,1)
											newx = command.x + ox
											newz = command.z - oz
											break
										
										elseif math.sqrt(ox^2 + oz^2) <= math.sqrt(Game.extractorRadius^2)-spotSize and spTestBuildOrder(-mexBuilder[id].building[j],command.x - ox,spGetGroundHeight(command.x - ox,command.z - oz),command.z - oz,1) ~= 0 then
											buildable = spTestBuildOrder(-mexBuilder[id].building[j],command.x + ox,spGetGroundHeight(command.x + ox,command.z + oz),command.z + oz,1)
											command.x = command.x - ox
											command.z = command.z - oz
											break
										end			
									if buildable ~= 0 then
										break
									end
								end
								if buildable ~= 0 then
									break
								end
							end
						end
						if buildable ~= 0 then
							spGiveOrderToUnit(id, mexBuilder[id].building[j], {newx,spGetGroundHeight(newx,newz),newz} , {"shift"})
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


----------------------
-- Mex detection from easymetal by carrepairer

local floor = math.floor

local spGetGroundInfo   = Spring.GetGroundInfo
local spGetGroundHeight = Spring.GetGroundHeight

local gridSize			= 4
local threshFraction		= 0.4
local metalExtraction		= 0.004

local mapWidth 			= floor(Game.mapSizeX)
local mapHeight 		= floor(Game.mapSizeZ)
local mapWidth2 		= floor(Game.mapSizeX / gridSize)
local mapHeight2 		= floor(Game.mapSizeZ / gridSize)

local metalMap 			= {}
local maxMetal 			= 0

local metalData 		= {}
local metalDataCount 		= 0

local snapDist			= 10000
local mexSize			= 25
local mexRad			= Game.extractorRadius > 125 and Game.extractorRadius or 125

local flagCount			= 0

local function NearFlag(px, pz, dist)
	if not mexes then return false end
	for k, flag in pairs(mexes) do		
		local fx, fz = flag.x, flag.z
		if (px-fx)^2 + (pz-fz)^2 < dist then
			return k
		end
	end
	return false
end

local function round(num, idp)
  local mult = 10^(idp or 0)
  return floor(num * mult + 0.5) / mult
end

local function mergeToFlag(flagNum, px, pz, pWeight)

	local fx = mexes[flagNum].x
	local fz = mexes[flagNum].z
	local fWeight = mexes[flagNum].weight
	
	local avgX, avgZ
	
	if fWeight > pWeight then
		local fStrength = round(fWeight / pWeight)
		avgX = (fx*fStrength + px) / (fStrength +1)
		avgZ = (fz*fStrength + pz) / (fStrength +1)
	else
		local pStrength = (pWeight / fWeight)
		avgX = (px*pStrength + fx) / (pStrength +1)
		avgZ = (pz*pStrength + fz) / (pStrength +1)		
	end
	
	mexes[flagNum].x = avgX
	mexes[flagNum].z = avgZ
	mexes[flagNum].weight = fWeight + pWeight
end

local function AnalyzeMetalMap()
	for mx_i = 1, mapWidth2 do
		metalMap[mx_i] = {}
		for mz_i = 1, mapHeight2 do
			local mx = mx_i * gridSize
			local mz = mz_i * gridSize
			local _, curMetal, curMetal2 = spGetGroundInfo(mx, mz)
            if type(curMetal) == 'string' then	-- Spring > v104
                curMetal = curMetal2
            end
			curMetal = floor(curMetal * 100)
			metalMap[mx_i][mz_i] = curMetal
			if (curMetal > maxMetal) then
				maxMetal = curMetal
			end
		end
	end

	local lowMetalThresh = floor(maxMetal * threshFraction)
	
	for mx_i = 1, mapWidth2 do
		for mz_i = 1, mapHeight2 do
			local mCur = metalMap[mx_i][mz_i]
			if mCur > lowMetalThresh then
				metalDataCount = metalDataCount +1
				metalData[metalDataCount] = {
					x = mx_i * gridSize,
					z = mz_i * gridSize,
					metal = mCur
				}
				if #metalData > maxMetalData then -- Probably a metal map, ceases to work
					Spring.Echo("Area Mex: widget auto-removed, too many spots found in map.")
					widgetHandler:RemoveWidget(self)
					return
				end
			end
		end
	end

--	--Spring.Echo("number of spots " .. #metalData)
--	if #metalData > maxMetalData then -- ceases to work
--		Spring.Echo("Removed Area Mex, too many spots.")
--		widgetHandler:RemoveWidget(self)
--		return
--	end
	
	table.sort(metalData, function(a,b) return a.metal > b.metal end)
	
	for index = 1, metalDataCount do
		
		local mx = metalData[index].x
		local mz = metalData[index].z
		local mCur = metalData[index].metal
		
		local nearFlagNum = NearFlag(mx, mz, mexRad*mexRad)
	
		if nearFlagNum then
			mergeToFlag(nearFlagNum, mx, mz, mCur)
		else
			flagCount = flagCount + 1
			mexes[flagCount] = {
				x = mx,
				z = mz,
				weight = mCur
			}
		end
	end
end

-- saving metalmap
local function SaveMetalMap(filename)
	local file = assert(io.open(filename,'w'), "Unable to save mexmap to "..filename)
	
	for k, mex in pairs(mexes) do
		file:write(mex.x)
		file:write("\n")
		file:write(mex.z)
		file:write("\n")
	end
	
	file:close()
	Spring.Echo("mexmap exported to ".. filename);
end

local function LoadMetalMap(filename)
	local file = assert(io.open(filename,'r'), "Unable to load mexmap from "..filename)
	mexes = {}
	index = 1
	while true do
		l1 = file:read()
		if not l1 then break end
		l2 = file:read()
		mexes[index] = {
			x = l1,
			z = l2
		}
		index = index+1
	end
	Spring.Echo("mexmap imported from ".. filename);
	
end

function widget:Initialize()
	
	local Gname = Game.modShortName
	
	if Gname == 'EvoRTS' then
		Spring.Echo("Area Mex: Loaded for Evo")
		mexIds[UnitDefNames['tmex2'].id] = UnitDefNames['tmex2'].id 
		mexIds[UnitDefNames['emex2'].id] = UnitDefNames['emex2'].id 
	elseif Gname == '' then
		Spring.Echo("Area Mex: Loaded for EE")
		mexIds[UnitDefNames['urcmex2'].id] = UnitDefNames['urcmex2'].id 
		mexIds[UnitDefNames['alienmex'].id] = UnitDefNames['alienmex'].id 
		mexIds[UnitDefNames['gdmex2'].id] = UnitDefNames['gdmex2'].id 
	elseif Gname == 'BA' or Gname == 'nota' then
		Spring.Echo("Area Mex: Loaded for BA or NOTA")
		mexIds[UnitDefNames['armmex'].id] = UnitDefNames['armmex'].id 
		mexIds[UnitDefNames['cormex'].id] = UnitDefNames['cormex'].id 
		mexIds[UnitDefNames['armmoho'].id] = UnitDefNames['armmoho'].id 
		mexIds[UnitDefNames['cormoho'].id] = UnitDefNames['cormoho'].id 		
		mexIds[UnitDefNames['armuwmex'].id] = UnitDefNames['armuwmex'].id 
		mexIds[UnitDefNames['coruwmex'].id] = UnitDefNames['coruwmex'].id 
		mexIds[UnitDefNames['armuwmme'].id] = UnitDefNames['armuwmme'].id 
		mexIds[UnitDefNames['coruwmme'].id] = UnitDefNames['coruwmme'].id 
	elseif Gname == 'ca' then
		Spring.Echo("Area Mex: Loaded for CA")
		mexIds[UnitDefNames['armmex'].id] = UnitDefNames['armmex'].id 
		mexIds[UnitDefNames['cormex'].id] = UnitDefNames['cormex'].id 
  	elseif Gname == 'XTA'  then
    		Spring.Echo("Area Mex: Loaded for XTA")
    		mexIds[UnitDefNames['arm_metal_extractor'].id] = UnitDefNames['arm_metal_extractor'].id 
    		mexIds[UnitDefNames['core_metal_extractor'].id] = UnitDefNames['core_metal_extractor'].id 
    		mexIds[UnitDefNames['arm_underwater_metal_extractor'].id] = UnitDefNames['arm_underwater_metal_extractor'].id 
    		mexIds[UnitDefNames['core_underwater_metal_extractor'].id] = UnitDefNames['core_underwater_metal_extractor'].id 
	else
		Spring.Echo("Removed Area Mex")
		widgetHandler:RemoveWidget(self)
	end

	Spring.CreateDir(pathToSave)
	local filename = (pathToSave.. string.lower(string.gsub(Game.mapName, ".smf", "")) .. ".springmexmap")
	file = io.open(filename,'r')
	if file ~= nil then -- file exists?
		Spring.Echo("Mexmap detected - loading...")
		LoadMetalMap(filename)
	else
		Spring.Echo("Calculating mexmap")
		AnalyzeMetalMap()
		SaveMetalMap(filename)
	end
  
	local units = spGetTeamUnits(spGetMyTeamID())
	for i, id in ipairs(units) do 
		widget:UnitCreated(id, spGetUnitDefID(id))
	end
end
