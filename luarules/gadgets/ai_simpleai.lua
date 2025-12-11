local enabled = false
local SimpleAITeamIDs = {}
local SimpleAITeamIDsCount = 0
local SimpleFactoriesCount = {}
local SimpleFactories = {}
local SimpleT1Mexes = {}
local SimpleFactoryDelay = {}
local teams = Spring.GetTeamList()
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
teams = nil

local gadget = gadget ---@type Gadget

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

--Spring.Echo("tracy", tracy)

local wind = Game.windMax
local mapsizeX = Game.mapSizeX
local mapsizeZ = Game.mapSizeZ
local random = math.random
local min = math.min
local CMD_MOVE = CMD.MOVE
local CMD_RECLAIM = CMD.RECLAIM
local CMD_REPAIR = CMD.REPAIR
local CMD_FIGHT = CMD.FIGHT

local MakeHashedPosTable = VFS.Include("luarules/utilities/damgam_lib/hashpostable.lua")
local HashPosTable = MakeHashedPosTable()

local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")

-- manually appoint units to avoid making
-- (note that transports, stockpilers and objects/walls are auto skipped)
local BadUnitsList = {}
if Game.gameShortName == "BYAR" then
	BadUnitsList = {
		-- some depth charge launchers
		"armdl",
		"cordl",
	}
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

local isBuilding = {}
local isCommander = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isBuilding then
		isBuilding[unitDefID] = {unitDef.xsize, unitDef.zsize}
	end
	if unitDef.customParams.iscommander then
		isCommander[unitDefID] = {unitDef.xsize, unitDef.zsize}
	end

	local skip = false
	for a = 1, #BadUnitsList do
		if BadUnitsList[a] == unitDef.name then
			skip = true
			break
		end
	end
	-- stockpilers
	if unitDef.weapons then
		for i = 1, #unitDef.weapons do
			local wDef = WeaponDefs[unitDef.weapons[i].weaponDef]
			if wDef.stockpile and wDef.interceptor == 0 then
				skip = true
				break
			end
		end
	end
	-- minelayers
	if unitDef.customParams.minesweeper then
		skip = true
	end
	-- transports
	if unitDef.transportCapacity > 0 then
		skip = true
	end
	-- objects/walls
	if unitDef.modCategories['object'] or unitDef.customParams.objectify then
		skip = true
	end

	if not skip then
		if unitDef.customParams.iscommander then
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


local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spGetGroundHeight = Spring.GetGroundHeight
local spGetGroundInfo = Spring.GetGroundInfo
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetTeamResources = Spring.GetTeamResources
local spTestBuildOrder = Spring.TestBuildOrder
local spGetFullBuildQueue = Spring.GetFullBuildQueue
local spGetTeamUnits = Spring.GetTeamUnits
local spGetAllUnits = Spring.GetAllUnits
local spSetTeamResource = Spring.SetTeamResource
local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamLuaAI = Spring.GetTeamLuaAI
local spDgunCommand = CMD.DGUN


local function SimpleGetClosestMexSpot(x, z)
	--tracy.ZoneBeginN("SimpleAI:SimpleGetClosestMexSpot")
	local bestSpot
	local bestDist = math.huge
	local metalSpots = GG["resource_spot_finder"] and GG["resource_spot_finder"].metalSpotsList or nil
	if metalSpots then
		for i = 1, #metalSpots do
			local spot = metalSpots[i]
			local dx, dz = x - spot.x, z - spot.z
			local dist = dx * dx + dz * dz
			if dist < bestDist then
				local units = spGetUnitsInCylinder(spot.x, spot.z, 128)
				if units and #units == 0 then
					bestSpot = spot
					bestDist = dist
				end
			end
		end
	else
		-- optimize for metal maps a bit
		local searchwidth = HashPosTable.resolution / 2 - 32
		for hashposindex = 1, HashPosTable.numPos do
			local tilecenterx, tilecenterz = HashPosTable:GetNthCenter(x,z,hashposindex)
			for attempt = 1,5 do
				local posx = tilecenterx + random(-searchwidth, searchwidth)
				local posz = tilecenterz + random(-searchwidth, searchwidth)
				local posy = spGetGroundHeight(posx, posz)
				if posy then
					local _,_,hasmetal = spGetGroundInfo(posx, posz)
					if hasmetal and hasmetal > 0.1 then
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
			end
			if bestSpot then break end
		end
	end
	--tracy.ZoneEnd()
	return bestSpot
end

local function SimpleBuildOrder(cUnitID, building)

	--tracy.ZoneBeginN("SimpleAI:SimpleBuildOrder")
	--Spring.Echo( UnitDefs[spGetUnitDefID(cUnitID)].name, " ordered to build", UnitDefs[building].name)
	local searchRange = 0
	local numtests = 0
	local cunitposx, _, cunitposz = spGetUnitPosition(cUnitID)
	if not cunitposx then
		return
	end
	
	local team = spGetUnitTeam(cUnitID)
	--Spring.Echo("SBO", cUnitID,"Start")
	for b2 = 1,20 do
		searchRange = searchRange + 300 -- WARNING, THIS EVENTUALLY ENDS UP BEING A 6000 RADIUS CIRCLE!
		local units = spGetUnitsInCylinder(cunitposx, cunitposz, searchRange)
		if units and #units > 1 then
			local gaveOrder = false
			local maxTests = min(#units, 5 + b2 * 2)
			for k=1, maxTests do
				numtests = numtests+1
				local buildnear = units[random(1, #units)]
				local refDefID = spGetUnitDefID(buildnear)
				if refDefID and (isBuilding[refDefID] or isCommander[refDefID]) and spGetUnitTeam(buildnear) == team then
					local refx, _, refz = spGetUnitPosition(buildnear)
					if refx then
						local reffootx = (isBuilding[refDefID] and isBuilding[refDefID][1] or isCommander[refDefID][1]) * 8
						local reffootz = (isBuilding[refDefID] and isBuilding[refDefID][2] or isCommander[refDefID][2]) * 8
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
						local bposy = spGetGroundHeight(bposx, bposz)
						if bposy then
							local testpos = spTestBuildOrder(buildingDefID, bposx, bposy, bposz, r)
							if testpos == 2 then
								local nearbyunits = spGetUnitsInRectangle(bposx - testspacing, bposz - testspacing, bposx + testspacing, bposz + testspacing)
								if nearbyunits and #nearbyunits == 0 then
									spGiveOrderToUnit(cUnitID, -buildingDefID, { bposx, bposy, bposz, r }, { "shift" })
									gaveOrder = true
									break
								end
							end
						end
					end
				end
			end
			if gaveOrder then break end
		end
	end
	--tracy.ZoneEnd()
	--Spring.Echo("SBO",cUnitID, numtests, searchRange/300)
end

local function SimpleConstructionProjectSelection(unitID, unitDefID, unitTeam, units, type)
	--tracy.ZoneBeginN("SimpleAI:SimpleConstructionProjectSelection")
	local success = false

	local mcurrent, mstorage, _, _, _ = spGetTeamResources(unitTeam, "metal")
	local ecurrent, estorage, _, _, _ = spGetTeamResources(unitTeam, "energy")
	local unitposx, _, unitposz = spGetUnitPosition(unitID)

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
						spGiveOrderToUnit(unitID, -project, { mexspotpos.x, mexspotpos.y, mexspotpos.z, 0 }, { "shift" })
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
							spGiveOrderToUnit(unitID, -project, { mexspotpos.x, mexspotpos.y, mexspotpos.z, 0 }, { "shift" })
							for _, xoffset in ipairs(xoffsets) do
								for _, zoffset in ipairs(zoffsets) do
									if xoffset ~= 0 and zoffset ~= 0 then
										local projectturret = SimpleTurretDefs:RandomChoice()
										if buildOptions[projectturret] then
											spGiveOrderToUnit(unitID, -projectturret, { mexspotpos.x + xoffset, mexspotpos.y, mexspotpos.z + zoffset , random(0,3) }, { "shift" })
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
						if targetUnit then
							local targetDefID = spGetUnitDefID(targetUnit)
							if targetDefID and isBuilding[targetDefID] then
								local tUnitX, tUnitY, tUnitZ = spGetUnitPosition(targetUnit)
								if tUnitX then
									spGiveOrderToUnit(unitID, CMD_MOVE, { tUnitX + random(-100, 100), tUnitY, tUnitZ + random(-100, 100) }, { "shift", "alt", "ctrl" })
									success = true
									break
								end
							end
						end
					end
				elseif r == 12 and type ~= "Commander" then
					local mapcenterX = mapsizeX/2
					local mapcenterZ = mapsizeZ/2
					local mapcenterY = spGetGroundHeight(mapcenterX, mapcenterZ)
					if mapcenterY then
						local mapdiagonal = math.ceil(math.sqrt((mapsizeX*mapsizeX)+(mapsizeZ*mapsizeZ)))
						spGiveOrderToUnit(unitID, CMD_RECLAIM,{mapcenterX+random(-100,100),mapcenterY,mapcenterZ+random(-100,100),mapdiagonal}, 0)
						success = true
					end
				elseif r == 13 and type ~= "Commander" then
					local mapcenterX = mapsizeX/2
					local mapcenterZ = mapsizeZ/2
					local mapcenterY = spGetGroundHeight(mapcenterX, mapcenterZ)
					if mapcenterY then
						local mapdiagonal = math.ceil(math.sqrt((mapsizeX*mapsizeX)+(mapsizeZ*mapsizeZ)))
						spGiveOrderToUnit(unitID, CMD_REPAIR,{mapcenterX+random(-100,100),mapcenterY,mapcenterZ+random(-100,100),mapdiagonal}, 0)
						success = true
					end
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
				if #spGetFullBuildQueue(unitID) < 5 then
					local r = random(0, 5)
					local luaAI = spGetTeamLuaAI(unitTeam)
					if r == 0 or mcurrent > mstorage*0.9 or (luaAI and string.sub(luaAI, 1, 19) == 'SimpleConstructorAI') then
						local project = SimpleConstructorDefs:RandomChoice()
						if buildOptions and buildOptions[project] then
							local x, y, z = spGetUnitPosition(unitID)
							if x then
								spGiveOrderToUnit(unitID, -project, { x, y, z, 0 }, 0)
								--Spring.Echo("Success! Project Type: Constructor.")
								success = true
							end
						end
					else
						local project = SimpleUndefinedUnitDefs:RandomChoice()
						if buildOptions and buildOptions[project] then
							local x, y, z = spGetUnitPosition(unitID)
							if x then
								spGiveOrderToUnit(unitID, -project, { x, y, z, 0 }, 0)
								--Spring.Echo("Success! Project Type: Unit.")
								success = true
							end
						end
					end
				else
					success = true
				end
			end
			if success == true then
				break
			end
		end	--tracy.ZoneEnd()
	return success
end

function gadget:GameOver()
	gadgetHandler:RemoveGadget(self)
end

if gadgetHandler:IsSyncedCode() then

	function gadget:GameFrame(n)
		if n % 15 == 0 then
			local allunits -- will lazy load later if needed
			for i = 1, SimpleAITeamIDsCount do
				if n%(15*SimpleAITeamIDsCount) == 15*(i-1) then
					--tracy.ZoneBeginN("SimpleAI:GameFrame")
					local teamID = SimpleAITeamIDs[i]
					local _, _, _, _, _, allyTeamID = spGetTeamInfo(teamID)
					local mcurrent, mstorage = spGetTeamResources(teamID, "metal")
					local ecurrent, estorage = spGetTeamResources(teamID, "energy")
					
					-- cheats - cache this check
					local isCheaterTeam = false
					for j = 1, SimpleAITeamIDsCount do
						if teamID == SimpleAITeamIDs[j] then
							isCheaterTeam = true
							break
						end
					end
					
					if isCheaterTeam then
						if mcurrent < mstorage * 0.20 then
							spSetTeamResource(teamID, "m", mstorage * 0.25)
						end
						if ecurrent < estorage * 0.20 then
							spSetTeamResource(teamID, "e", estorage * 0.25)
						end
					end

					local units = spGetTeamUnits(teamID)
					if units then
						for k = 1, #units do
							local unitID = units[k]
							if unitID then
								local unitDefID = spGetUnitDefID(unitID)
								if unitDefID then
									local unitTeam = teamID
									local unitHealth, unitMaxHealth = spGetUnitHealth(unitID)
									local unitCommandCount = spGetUnitCommandCount(unitID)
									local unitposx, unitposy, unitposz = spGetUnitPosition(unitID)
									
									if unitposx then
										--Spring.Echo(UnitDefs[unitDefID].name, "has commands:",unitCommandCount, SimpleConstructorDefs[unitDefID] , SimpleCommanderDefs[unitDefID], SimpleFactoriesDefs[unitDefID] ,SimpleUndefinedUnitDefs[unitDefID] )
										-- Commanders
										if SimpleCommanderDefs[unitDefID] then
											local nearestEnemyCloak = spGetUnitNearestEnemy(unitID, 2000, false)
											if nearestEnemyCloak and ecurrent > 1000 then
												spGiveOrderToUnit(unitID, 37382, {1}, 0)
											else
												spGiveOrderToUnit(unitID, 37382, {0}, 0)
											end


											local nearestEnemy = spGetUnitNearestEnemy(unitID, 250, true)
											local unitHealthPercentage = unitHealth and unitMaxHealth and (unitHealth/unitMaxHealth)*100 or 0

											if nearestEnemy and unitHealthPercentage > 30 then
												if ecurrent < estorage*0.9 then
													spSetTeamResource(teamID, "e", estorage*0.9)
												end
												spGiveOrderToUnit(unitID, spDgunCommand, {nearestEnemy}, 0)
												local nearestEnemies = spGetUnitsInCylinder(unitposx, unitposz, 300)
												if nearestEnemies then
													local nearestEnemyTeam = spGetUnitTeam(nearestEnemy)
													for x = 1,#nearestEnemies do
														local enemy = nearestEnemies[x]
														if spGetUnitTeam(enemy) == nearestEnemyTeam and enemy ~= nearestEnemy then
															spGiveOrderToUnit(unitID, spDgunCommand, {enemy}, {"shift"})
														end
													end
												end
												spGiveOrderToUnit(unitID, CMD_MOVE, {unitposx, unitposy, unitposz}, {"shift"})
											elseif nearestEnemy then
												for x = 1,10 do
													local targetUnit = units[random(1,#units)]
													if targetUnit then
														local targetDefID = spGetUnitDefID(targetUnit)
														if targetDefID and isBuilding[targetDefID] then
															local tUnitX, tUnitY, tUnitZ = spGetUnitPosition(targetUnit)
															if tUnitX then
																spGiveOrderToUnit(unitID, CMD_MOVE, { tUnitX + random(-100, 100), tUnitY, tUnitZ + random(-100, 100) }, 0)
																break
															end
														end
													end
												end
											end
										end

										-- Constructors
										if SimpleConstructorDefs[unitDefID] then
											local unitHealthPercentage = unitHealth and unitMaxHealth and (unitHealth/unitMaxHealth)*100 or 0
											local nearestEnemy = spGetUnitNearestEnemy(unitID, 500, true)
											if nearestEnemy and unitHealthPercentage > 90 then
												spGiveOrderToUnit(unitID, CMD_RECLAIM, {nearestEnemy}, 0)
											elseif nearestEnemy then
												for x = 1,100 do
													local targetUnit = units[random(1,#units)]
													if targetUnit then
														local targetDefID = spGetUnitDefID(targetUnit)
														if targetDefID and isBuilding[targetDefID] then
															local tUnitX, tUnitY, tUnitZ = spGetUnitPosition(targetUnit)
															if tUnitX then
																spGiveOrderToUnit(unitID, CMD_MOVE, { tUnitX + random(-100, 100), tUnitY, tUnitZ + random(-100, 100) }, 0)
																break
															end
														end
													end
												end
											end
										end

										if unitCommandCount == 0 then
											if SimpleConstructorDefs[unitDefID] then
												SimpleConstructionProjectSelection(unitID, unitDefID, unitTeam, units, "Builder")
											end


											if SimpleCommanderDefs[unitDefID] then
												SimpleConstructionProjectSelection(unitID, unitDefID, unitTeam, units, "Commander")
											end

											if SimpleFactoriesDefs[unitDefID] then
												SimpleConstructionProjectSelection(unitID, unitDefID, unitTeam, units, "Factory")
											end

											-- army
											if SimpleUndefinedUnitDefs[unitDefID] then
												local luaAI = spGetTeamLuaAI(teamID)
												if luaAI and string.sub(luaAI, 1, 16) == 'SimpleDefenderAI' then
													allunits = allunits or spGetAllUnits()
													if allunits then
														for t = 1,10 do
															local targetUnit = allunits[random(1,#allunits)]
															if targetUnit and spGetUnitAllyTeam(targetUnit) == allyTeamID then
																local tUnitX, tUnitY, tUnitZ = spGetUnitPosition(targetUnit)
																if tUnitX then
																	spGiveOrderToUnit(unitID, CMD_FIGHT, { tUnitX + random(-100, 100), tUnitY, tUnitZ + random(-100, 100) }, { "shift", "alt", "ctrl" })
																	break
																end
															end
														end
													end
												else
													local targetUnitNear = spGetUnitNearestEnemy(unitID, 2000, false)
													if targetUnitNear then
														local tUnitX, tUnitY, tUnitZ = spGetUnitPosition(targetUnitNear)
														if tUnitX then
															spGiveOrderToUnit(unitID, CMD_FIGHT, { tUnitX + random(-100, 100), tUnitY, tUnitZ + random(-100, 100) }, { "shift", "alt", "ctrl" })
														end
													elseif n%3600 <= 15*SimpleAITeamIDsCount then
														local targetUnit = spGetUnitNearestEnemy(unitID, 999999, false)
														if targetUnit then
															local tUnitX, tUnitY, tUnitZ = spGetUnitPosition(targetUnit)
															if tUnitX then
																spGiveOrderToUnit(unitID, CMD_FIGHT, { tUnitX + random(-100, 100), tUnitY, tUnitZ + random(-100, 100) }, { "shift", "alt", "ctrl" })
															end
														end
													end
												end
											end
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
		for i = 1, SimpleAITeamIDsCount do
			if SimpleAITeamIDs[i] == unitTeam then
				spGiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},0)
				spGiveOrderToUnit(unitID,CMD.MOVE_STATE,{2},0)

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

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
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
				spGiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},0)
				spGiveOrderToUnit(unitID,CMD.MOVE_STATE,{2},0)
			end
		end
	end
end
