local enabled = false
local teams = Spring.GetTeamList()
local SimpleAITeamIDs = {}
local SimpleAITeamIDsCount = 0
--local UDN = UnitDefNames
local wind = Game.windMax
local mapsizeX = Game.mapSizeX
local mapsizeZ = Game.mapSizeZ
local random = math.random
local debugmode = false

local gameShortName = Game.gameShortName

--Spring.Echo("tracy", tracy)

local MakeHashedPosTable = VFS.Include("luarules/utilities/damgam_lib/hashpostable.lua")
local HashPosTable = MakeHashedPosTable()

local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")

-- team locals
local SimpleFactoriesCount = {}
local SimpleFactories = {}
local SimpleT1Mexes = {}
local SimpleFactoryDelay = {}

for i = 1, #teams do
	local teamID = teams[i]
	local luaAI = Spring.GetTeamLuaAI(teamID)
	if luaAI and luaAI ~= "" and (string.sub(luaAI, 1, 8) == 'SimpleAI' or string.sub(luaAI, 1, 15) == 'SimpleCheaterAI' or string.sub(luaAI, 1, 16) == 'SimpleDefenderAI' or string.sub(luaAI, 1, 19) == 'SimpleConstructorAI') then
		enabled = true
		SimpleAITeamIDsCount = SimpleAITeamIDsCount + 1
		SimpleAITeamIDs[SimpleAITeamIDsCount] = teamID

		SimpleFactoriesCount[teamID] = 0
		SimpleFactories[teamID] = {}
		SimpleT1Mexes[teamID] = 0
		SimpleFactoryDelay[teamID] = 0
	end
end

function gadget:GetInfo()
	return {
		name = "SimpleAI",
		desc = "123",
		author = "Damgam",
		date = "2020",
		license = "GNU GPL, v2 or later",
		layer = -100,
		enabled = enabled,
	}
end

-------- lists
local BadUnitsList = {}
if gameShortName == "BYAR" then
	BadUnitsList = {
		-- transports
		"armthovr",
		"corthovr",
		"armatlas",
		"armtship",
		"corvalk",
		"cortship",
		"armdfly",
		"corseah",
		"corint",

		-- stockpilers
		"armemp",
		"armjuno",
		"armsilo",
		"corjuno",
		"corsilo",
		"cortron",

		-- minelayers
		"armmlv",
		"cormlv",

		-- depth charge launchers
		"armdl",
		"cordl",

		-- walls
		"armdrag",
		"cordrag",
	}
end

local function RandomChoiceArray(t)
	return t[random(1,#t)]
end

local function RandomChoice(self)
	-- lazy initialization
	if self.array == nil then 
		local array = {}
		for k,v in pairs(self) do 
			if k ~= "RandomChoice" then 
				array[#array+1] = k
			end
		end
		self.array = array
		self.arraycount = #array
	end
	return self.array[random(1, self.arraycount)]
end

-- Notes:
-- These tables have unitDefID keys, and values of just numbers as weights
-- We are overloading the key "RandomChoice" with a function that lazily initializes an array to randomly choose from
-- Usage: Call SimpleCommanderDefs:RandomChoice() at any time to get a random unitDefID key from the table
-- TODO: make the randomChoice a weighted random choice instead of uniform!
-- SimpleCommanderDefs:RandomChoice()
-- SimpleCommanderDefs.RandomChoice(SimpleCommanderDefs)

local BadUnitDefs = {RandomChoice = RandomChoice}
local SimpleCommanderDefs = {RandomChoice = RandomChoice} 
local SimpleFactoriesDefs = {RandomChoice = RandomChoice} 
local SimpleConstructorDefs = {RandomChoice = RandomChoice} 
local SimpleExtractorDefs = {RandomChoice = RandomChoice}
local SimpleGeneratorDefs = {RandomChoice = RandomChoice}
local SimpleConverterDefs = {RandomChoice = RandomChoice}
local SimpleTurretDefs = {RandomChoice = RandomChoice}
local SimpleUndefinedBuildingDefs = {RandomChoice = RandomChoice}
local SimpleUndefinedUnitDefs = {RandomChoice = RandomChoice}

local BuildOptions = {} -- {unitDefHasBuildOptions = {1= buildOpt0, RandomChoice = RandomChoice}}


for unitDefID, unitDef in pairs(UnitDefs) do
	local BadUnitDef = false
	for a = 1,#BadUnitsList do
		if BadUnitsList[a] == unitDef.name then
			BadUnitDef = true
			break
		else
			BadUnitDef = false
		end
	end
	if BadUnitDef == false then
		if unitDef.name == "armcom" or unitDef.name == "corcom" or unitDef.name == "armdecom" or unitDef.name == "cordecom" then
			SimpleCommanderDefs[unitDefID] = 1
		elseif unitDef.isFactory and #unitDef.buildOptions > 0 then
			SimpleFactoriesDefs[unitDefID] = 1
		elseif unitDef.canMove and unitDef.isBuilder and #unitDef.buildOptions > 0 then
			SimpleConstructorDefs[unitDefID] = 1
		elseif unitDef.extractsMetal > 0 or unitDef.customParams.metal_extractor then
			SimpleExtractorDefs[unitDefID] = 1
		elseif (unitDef.energyMake > 19 and (not unitDef.energyUpkeep or unitDef.energyUpkeep < 10)) or (unitDef.windGenerator > 0 and wind > 10) or unitDef.tidalGenerator > 0 or unitDef.customParams.solar then
			SimpleGeneratorDefs[unitDefID] = 1
		elseif unitDef.customParams.energyconv_capacity and unitDef.customParams.energyconv_efficiency then
			SimpleConverterDefs[unitDefID] = 1
		elseif unitDef.isBuilding and #unitDef.weapons > 0 then
			SimpleTurretDefs[unitDefID] = 1
		elseif not unitDef.canMove then
			SimpleUndefinedBuildingDefs[unitDefID] = 1
		else
			SimpleUndefinedUnitDefs[unitDefID] = 1
		end
		if #unitDef.buildOptions > 0 then
			BuildOptions[unitDefID] = {RandomChoice = RandomChoice}
			for i=1, #unitDef.buildOptions do 
				BuildOptions[unitDefID][unitDef.buildOptions[i]] = 1
			end
		end
	end
end

--Spring.Debug.TableEcho(BuildOptions)
-------- functions

local function SimpleGetClosestMexSpot(x, z)
	--tracy.ZoneBeginN("SimpleAI:SimpleGetClosestMexSpot")
	local bestSpot
	local bestDist = math.huge
	local metalSpots = GG.metalSpots
	if metalSpots then
		for i = 1, #metalSpots do
			local spot = metalSpots[i]
			local dx, dz = x - spot.x, z - spot.z
			local dist = dx * dx + dz * dz
			if dist < bestDist then 
				local units = Spring.GetUnitsInCylinder(spot.x, spot.z, 128)
			--local height = Spring.GetGroundHeight(spot.x, spot.z)
				if #units == 0 then
					--and height > 0 then
					bestSpot = spot
					bestDist = dist
				end
			end
		end
	else
		-- optimize for metal maps a bit
		local canBuildMex = false
		local numtries = 0
		local maxtries = HashPosTable.numPos
		
		local hashPos = HashPosTable:hashPos(x,z)
		local searchwidth = HashPosTable.resolution / 2 - 32
		for hashposindex = 1, HashPosTable.numPos do 
			local tilecenterx, tilecenterz = HashPosTable:GetNthCenter(x,z,hashposindex)
			for attempt = 1,5 do 
				local posx = tilecenterx + random(-searchwidth, searchwidth)
				local posz = tilecenterz + random(-searchwidth, searchwidth)
				local posy = Spring.GetGroundHeight(posx, posz)
				local _,_,hasmetal = Spring.GetGroundInfo(posx, posz)
				if hasmetal > 0.1 then 
					local flat = positionCheckLibrary.FlatAreaCheck(posx, posy, posz, 64, 25, true)
					if flat then 
						local unoccupied = positionCheckLibrary.OccupancyCheck(posx, posy, posz, 48)
						if unoccupied then 
							bestSpot = {x = posx, y = posy, z = posz}
							break
						end
					end
				end
			end
			if bestSpot then break end 
		end
		
		--[[
		-- old method left here as a reference
		for i = 128,10000 do
			
			canBuildMex = false
			local posx = x + random(-i,i)
			local posz = z + random(-i,i)
			local posy = Spring.GetGroundHeight(posx, posz)
			canBuildMex = positionCheckLibrary.FlatAreaCheck(posx, posy, posz, 64, 25, true)
			if canBuildMex then
				canBuildMex = positionCheckLibrary.OccupancyCheck(posx, posy, posz, 64)
			end
			if canBuildMex then
				canBuildMex = positionCheckLibrary.MapEdgeCheck(posx, posy, posz, 64)
			end
			if canBuildMex and select(3, Spring.GetGroundInfo(posx, posz)) > 0.1 then
				canBuildMex = true
			else
				canBuildMex = false
			end
			if canBuildMex then
				bestSpot = {x = posx, y = posy, z = posz}
				break
			end
		end
		]]--
	end
	--tracy.ZoneEnd()
	return bestSpot
end

local function SimpleBuildOrder(cUnitID, building)
	
	--tracy.ZoneBeginN("SimpleAI:SimpleBuildOrder")
	--Spring.Echo( UnitDefs[Spring.GetUnitDefID(cUnitID)].name, " ordered to build", UnitDefs[building].name)
	local searchRange = 0
	local numtests = 0
	--Spring.Echo("SBO", cUnitID,"Start")
	for b2 = 1,20 do
		searchRange = searchRange + 300 -- WARNING, THIS EVENTUALLY ENDS UP BEING A 6000 RADIUS CIRCLE!
		local team = Spring.GetUnitTeam(cUnitID)
		local cunitposx, _, cunitposz = Spring.GetUnitPosition(cUnitID)
		local units = Spring.GetUnitsInCylinder(cunitposx, cunitposz, searchRange, team)
		if #units > 1 then
			local gaveOrder = false
			for k=1,math.min(#units, 5 + b2 * 2) do
				numtests = numtests+1
				local buildnear = units[random(1, #units)]
				local refDefID = Spring.GetUnitDefID(buildnear)
				local isBuilding = UnitDefs[refDefID].isBuilding
				local isCommander = (UnitDefs[refDefID].name == "armcom" or UnitDefs[refDefID].name == "corcom")
				local isExtractor = UnitDefs[refDefID].extractsMetal > 0
				if (isBuilding or isCommander) then-- and not isExtractor then
					local refx, refy, refz = Spring.GetUnitPosition(buildnear)
					local reffootx = UnitDefs[refDefID].xsize * 8
					local reffootz = UnitDefs[refDefID].zsize * 8
					local spacing = random(64, 128)
					local testspacing = spacing * 0.75
					local buildingDefID = building
					local r = random(0,3)
					local rx = 0
					local rz = 0
					if r == 0 then 
						rz = reffootz + spacing
					elseif r == 1 then 
						rx = reffootx + spacing
					elseif r == 2 then 
						rz = - reffootz - spacing
					else
						rx = - reffootx - spacing
					end
					
					local bposx = refx + rx
					local bposz = refz + rz
					local bposy = Spring.GetGroundHeight(bposx, bposz)--+100
					local testpos = Spring.TestBuildOrder(buildingDefID, bposx, bposy, bposz, r)
					if testpos == 2 then
						local nearbyunits = Spring.GetUnitsInRectangle(bposx - testspacing, bposz - testspacing, bposx + testspacing, bposz + testspacing)
						if #nearbyunits == 0 then 
							Spring.GiveOrderToUnit(cUnitID, -buildingDefID, { bposx, bposy, bposz, r }, { "shift" })
							gaveOrder = true
							break
						end
					end
				end
				--local buildingDefID = UnitDefNames.building.id
				--local testpos = Spring.TestBuildOrder(buildingDefID, bposx, bposy, bposz, facing)
			end
			if gaveOrder then break end
		end
	end
	--tracy.ZoneEnd()
	--Spring.Echo("SBO",cUnitID, numtests, searchRange/300)
end

local function SimpleConstructionProjectSelection(unitID, unitDefID, unitName, unitTeam, allyTeamID, units, allunits, type)
	
	--tracy.ZoneBeginN("SimpleAI:SimpleConstructionProjectSelection")
	local success = false

	local mcurrent, mstorage, _, mincome, mexpense = Spring.GetTeamResources(unitTeam, "metal")
	local ecurrent, estorage, _, eincome, eexpense = Spring.GetTeamResources(unitTeam, "energy")
	local unitposx, unitposy, unitposz = Spring.GetUnitPosition(unitID)

	local unitCommands = Spring.GetCommandQueue(unitID, 0)
	--local buildOptions = UnitDefs[unitDefID].buildOptions
	local buildOptions = BuildOptions[unitDefID]
	-- Builders
	for b1 = 1,10 do
		if type == "Builder" or type == "Commander" then
			--Spring.Echo("unitCommands for",b1, UnitDefs[ unitDefID].name, b1)
			SimpleFactoryDelay[unitTeam] = SimpleFactoryDelay[unitTeam]-1
			local r = random(0, 20)
			local mexspotpos = SimpleGetClosestMexSpot(unitposx, unitposz)
			if (mexspotpos and SimpleT1Mexes[unitTeam] < 3) and type == "Commander" then
				local project = SimpleExtractorDefs:RandomChoice()
				if buildOptions  and buildOptions[project] then 
					Spring.GiveOrderToUnit(unitID, -project, { mexspotpos.x, mexspotpos.y, mexspotpos.z, 0 }, { "shift" })
					--Spring.Echo("Success! Project Type: Extractor.")
					success = true
				end
			elseif ecurrent < estorage * 0.75 or r == 0 then
				local project = SimpleGeneratorDefs:RandomChoice()
				if buildOptions and buildOptions[project] then 
					SimpleBuildOrder(unitID, project)
					--Spring.Echo("Success! Project Type: Generator.")
					success = true
				end

			elseif mcurrent < mstorage * 0.30 or r == 1 then
				-- if type == "Commander" then
				-- 	for t = 1,10 do
				-- 		local targetUnit = units[math.random(1,#units)]
				-- 		if UnitDefs[Spring.GetUnitDefID(targetUnit)].isBuilding == true then
				-- 			local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(targetUnit)
				-- 			Spring.GiveOrderToUnit(unitID, CMD.MOVE, { tUnitX + math.random(-100, 100), tUnitY, tUnitZ + math.random(-100, 100) }, { "shift", "alt", "ctrl" })
				-- 			success = true
				-- 			break
				-- 		end
				-- 	end
				-- elseif
				if (not mexspotpos) and (ecurrent > estorage * 0.85 or r == 1) then
					local project = SimpleConverterDefs:RandomChoice()
					if buildOptions and buildOptions[project] then 
						SimpleBuildOrder(unitID, project)
						--Spring.Echo("Success! Project Type: Converter.")
						success = true
					end
				elseif mexspotpos and type ~= "Commander" then
					local project = SimpleExtractorDefs:RandomChoice()
					local xoffsets = {0, 100, -100}
					local zoffsets = {0, 100, -100}
					if buildOptions and buildOptions[project] then 
						Spring.GiveOrderToUnit(unitID, -project, { mexspotpos.x, mexspotpos.y, mexspotpos.z, 0 }, { "shift" })
						for _, xoffset in ipairs(xoffsets) do 
							for _, zoffset in ipairs(zoffsets) do 
								if xoffset ~= 0 and zoffset ~= 0 then 
									local projectturret = SimpleTurretDefs:RandomChoice()
									if buildOptions[projectturret] then 
										Spring.GiveOrderToUnit(unitID, -projectturret, { mexspotpos.x + xoffset, mexspotpos.y, mexspotpos.z + zoffset , random(0,3) }, { "shift" })
									end
								end
							end
						end
					end
				end
			elseif r == 2 or r == 3 or r == 4 or r == 5 then
				local project = SimpleTurretDefs:RandomChoice()
				if buildOptions and buildOptions[project] then 
					SimpleBuildOrder(unitID, project)
					--Spring.Echo("Success! Project Type: Turret.")
					success = true
				end
			elseif SimpleFactoriesCount[unitTeam] < 1 or ((mcurrent > mstorage * 0.75 and ecurrent > estorage * 0.75) and SimpleFactoryDelay[unitTeam] <= 0) then
				local project = SimpleFactoriesDefs:RandomChoice()
				if buildOptions and buildOptions[project] and (not SimpleFactories[unitTeam][project]) then
					SimpleBuildOrder(unitID, project)
					SimpleFactoryDelay[unitTeam] = 30
					--Spring.Echo("Success! Project Type: Factory.")
					success = true
				end
			elseif r == 11 then
				for t = 1,10 do
					local targetUnit = units[random(1,#units)]
					if UnitDefs[Spring.GetUnitDefID(targetUnit)].isBuilding == true then
						local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(targetUnit)
						Spring.GiveOrderToUnit(unitID, CMD.MOVE, { tUnitX + random(-100, 100), tUnitY, tUnitZ + random(-100, 100) }, { "shift", "alt", "ctrl" })
						success = true
						break
					end
				end
			elseif r == 12 and type ~= "Commander" then
				local mapcenterX = mapsizeX/2
				local mapcenterZ = mapsizeZ/2
				local mapcenterY = Spring.GetGroundHeight(mapcenterX, mapcenterZ)
				local mapdiagonal = math.ceil(math.sqrt((mapsizeX*mapsizeX)+(mapsizeZ*mapsizeZ)))
				Spring.GiveOrderToUnit(unitID, CMD.RECLAIM,{mapcenterX+random(-100,100),mapcenterY,mapcenterZ+random(-100,100),mapdiagonal}, 0)
				success = true
			elseif r == 13 and type ~= "Commander" then
				local mapcenterX = mapsizeX/2
				local mapcenterZ = mapsizeZ/2
				local mapcenterY = Spring.GetGroundHeight(mapcenterX, mapcenterZ)
				local mapdiagonal = math.ceil(math.sqrt((mapsizeX*mapsizeX)+(mapsizeZ*mapsizeZ)))
				Spring.GiveOrderToUnit(unitID, CMD.REPAIR,{mapcenterX+random(-100,100),mapcenterY,mapcenterZ+random(-100,100),mapdiagonal}, 0)
				success = true
			else
				local r2 = random(0, 1)
				if r2 == 0 then
					local project = SimpleUndefinedBuildingDefs:RandomChoice()
					if buildOptions and buildOptions[project] then 
						SimpleBuildOrder(unitID, project)
						--Spring.Echo("Success! Project Type: Other.")
						success = true
					end
				else
					local project = SimpleTurretDefs:RandomChoice()
					if buildOptions and buildOptions[project] then
						SimpleBuildOrder(unitID, project)
						--Spring.Echo("Success! Project Type: Turret.")
						success = true
					end
				end
			end
		elseif type == "Factory" then
			if #Spring.GetFullBuildQueue(unitID, 0) < 5 then
				local r = random(0, 5)
				local luaAI = Spring.GetTeamLuaAI(unitTeam)
				if r == 0 or mcurrent > mstorage*0.9 or string.sub(luaAI, 1, 19) == 'SimpleConstructorAI' then
					local project = SimpleConstructorDefs:RandomChoice()
					if buildOptions and buildOptions[project] then
						local x, y, z = Spring.GetUnitPosition(unitID)
						Spring.GiveOrderToUnit(unitID, -project, { x, y, z, 0 }, 0)
						--Spring.Echo("Success! Project Type: Constructor.")
						success = true
					end
				else
					local project = SimpleUndefinedUnitDefs:RandomChoice()
					if buildOptions and buildOptions[project] then 
						local x, y, z = Spring.GetUnitPosition(unitID)
						Spring.GiveOrderToUnit(unitID, -project, { x, y, z, 0 }, 0)
						--Spring.Echo("Success! Project Type: Unit.")
						success = true
					end
				end
			else
				success = true
			end
		end
		if success == true then
			break
		end
	end
	
	--tracy.ZoneEnd()
	return success
end

function gadget:GameOver()
	gadgetHandler:RemoveGadget(self)
end

if gadgetHandler:IsSyncedCode() then

	function gadget:GameFrame(n)
		if n % 15 == 0 then
			for i = 1, SimpleAITeamIDsCount do
				if n%(15*SimpleAITeamIDsCount) == 15*(i-1) then
					--tracy.ZoneBeginN("SimpleAI:GameFrame")
					local teamID = SimpleAITeamIDs[i]
					local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID)
					local mcurrent, mstorage = Spring.GetTeamResources(teamID, "metal")
					local ecurrent, estorage = Spring.GetTeamResources(teamID, "energy")
					for j = 1, #SimpleAITeamIDs do
						if teamID == SimpleAITeamIDs[j] then
							-- --cheats
							if mcurrent < mstorage * 0.20 then
								Spring.SetTeamResource(teamID, "m", mstorage * 0.25)
							end
							if ecurrent < estorage * 0.20 then
								Spring.SetTeamResource(teamID, "e", estorage * 0.25)
							end
						end
					end

					local units = Spring.GetTeamUnits(teamID)
					local allunits = Spring.GetAllUnits()
					for k = 1, #units do
						local unitID = units[k]
						local unitDefID = Spring.GetUnitDefID(unitID)
						local unitName = UnitDefs[unitDefID].name
						local unitTeam = teamID
						local unitHealth, unitMaxHealth, _, _, _ = Spring.GetUnitHealth(unitID)
						local unitCommands = Spring.GetCommandQueue(unitID, 0)
						local unitposx, unitposy, unitposz = Spring.GetUnitPosition(unitID)
						--Spring.Echo(UnitDefs[unitDefID].name, "has commands:",unitCommands, SimpleConstructorDefs[unitDefID] , SimpleCommanderDefs[unitDefID], SimpleFactoriesDefs[unitDefID] ,SimpleUndefinedUnitDefs[unitDefID] )
						-- Commanders
						if SimpleCommanderDefs[unitDefID] then
							local nearestEnemyCloak = Spring.GetUnitNearestEnemy(unitID, 2000, false)
							if nearestEnemyCloak and ecurrent > 1000 then
								Spring.GiveOrderToUnit(unitID, 37382, {1}, 0)
							else
								Spring.GiveOrderToUnit(unitID, 37382, {0}, 0)
							end


							local nearestEnemy = Spring.GetUnitNearestEnemy(unitID, 250, true)
							local unitHealthPercentage = (unitHealth/unitMaxHealth)*100

							if nearestEnemy and unitHealthPercentage > 30 then
								if ecurrent < estorage*0.9 then
									Spring.SetTeamResource(teamID, "e", estorage*0.9)
								end
								Spring.GiveOrderToUnit(unitID, CMD.DGUN, {nearestEnemy}, 0)
								local nearestEnemies = Spring.GetUnitsInCylinder(unitposx, unitposz, 300)
								for x = 1,#nearestEnemies do
									local enemy = nearestEnemies[x]
									if Spring.GetUnitTeam(enemy) == Spring.GetUnitTeam(nearestEnemy) and enemy ~= nearestEnemy then
										Spring.GiveOrderToUnit(unitID, CMD.DGUN, {enemy}, {"shift"})
									end
								end
								Spring.GiveOrderToUnit(unitID, CMD.MOVE, {unitposx, unitposy, unitposz}, {"shift"})
							elseif nearestEnemy then
								for x = 1,10 do
									local targetUnit = units[random(1,#units)]
									if UnitDefs[Spring.GetUnitDefID(targetUnit)].isBuilding == true then
										local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(targetUnit)
										Spring.GiveOrderToUnit(unitID, CMD.MOVE, { tUnitX + random(-100, 100), tUnitY, tUnitZ + random(-100, 100) }, 0)
										break
									end
								end
							end
						end
					
						-- Constructors
						if SimpleConstructorDefs[unitDefID] then
							local unitHealthPercentage = (unitHealth/unitMaxHealth)*100
							local nearestEnemy = Spring.GetUnitNearestEnemy(unitID, 500, true)
							if nearestEnemy and unitHealthPercentage > 90 then
								Spring.GiveOrderToUnit(unitID, CMD.RECLAIM, {nearestEnemy}, 0)
							elseif nearestEnemy then
								for x = 1,100 do
									local targetUnit = units[random(1,#units)]
									if UnitDefs[Spring.GetUnitDefID(targetUnit)].isBuilding == true then
										local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(targetUnit)
										Spring.GiveOrderToUnit(unitID, CMD.MOVE, { tUnitX + random(-100, 100), tUnitY, tUnitZ + random(-100, 100) }, 0)
										break
									end
								end
							end
						end

						if unitCommands == 0 then
							
							if SimpleConstructorDefs[unitDefID] then
								SimpleConstructionProjectSelection(unitID, unitDefID, unitName, unitTeam, allyTeamID, units, allunits, "Builder")
							end


							if SimpleCommanderDefs[unitDefID] then
								SimpleConstructionProjectSelection(unitID, unitDefID, unitName, unitTeam, allyTeamID, units, allunits, "Commander")
							end

							if SimpleFactoriesDefs[unitDefID] then
								SimpleConstructionProjectSelection(unitID, unitDefID, unitName, unitTeam, allyTeamID, units, allunits, "Factory")
							end

							-- army

							if SimpleUndefinedUnitDefs[unitDefID] then
								local luaAI = Spring.GetTeamLuaAI(teamID)
								if string.sub(luaAI, 1, 16) == 'SimpleDefenderAI' then
									for t = 1,10 do
										local targetUnit = allunits[random(1,#allunits)]
										if Spring.GetUnitAllyTeam(targetUnit) == allyTeamID then
											local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(targetUnit)
											Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { tUnitX + random(-100, 100), tUnitY, tUnitZ + random(-100, 100) }, { "shift", "alt", "ctrl" })
											break
										end
									end
								else
									local targetUnitNear = Spring.GetUnitNearestEnemy(unitID, 2000, false)
									if targetUnitNear then
										local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(targetUnitNear)
										Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { tUnitX + random(-100, 100), tUnitY, tUnitZ + random(-100, 100) }, { "shift", "alt", "ctrl" })
									elseif n%3600 <= 15*SimpleAITeamIDsCount then
										local targetUnit = Spring.GetUnitNearestEnemy(unitID, 999999, false)
										if targetUnit then
											local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(targetUnit)
											Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { tUnitX + random(-100, 100), tUnitY, tUnitZ + random(-100, 100) }, { "shift", "alt", "ctrl" })
										end
									end
								end
							end
						end
					end
					
					--tracy.ZoneEnd()
				end
			end
		end
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		local unitName = UnitDefs[unitDefID].name
		for i = 1, SimpleAITeamIDsCount do
			if SimpleAITeamIDs[i] == unitTeam then
				Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},0)
				Spring.GiveOrderToUnit(unitID,CMD.MOVE_STATE,{2},0)

				if SimpleFactoriesDefs[unitDefID] then
					SimpleFactoriesCount[unitTeam] = SimpleFactoriesCount[unitTeam] + 1
					SimpleFactories[unitTeam][unitDefID] = true
					break
				end
				if SimpleExtractorDefs[unitDefID] then
					SimpleT1Mexes[unitTeam] = SimpleT1Mexes[unitTeam] + 1
					break
				end

			end
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
		local unitName = UnitDefs[unitDefID].name
		for i = 1, SimpleAITeamIDsCount do
			if SimpleAITeamIDs[i] == unitTeam then
				if SimpleFactoriesDefs[unitDefID] then
					SimpleFactoriesCount[unitTeam] = SimpleFactoriesCount[unitTeam] - 1
					SimpleFactories[unitTeam][unitDefID] = nil
					break
				end
				if SimpleExtractorDefs[unitDefID] then
					SimpleT1Mexes[unitTeam] = SimpleT1Mexes[unitTeam] - 1
					break
				end
			end
		end
	end

	function gadget:UnitFinished(unitID, unitDefID, unitTeam)
		for i = 1, SimpleAITeamIDsCount do
			if SimpleAITeamIDs[i] == unitTeam then
				Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},0)
				Spring.GiveOrderToUnit(unitID,CMD.MOVE_STATE,{2},0)
			end
		end
	end
end
