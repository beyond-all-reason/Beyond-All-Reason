local enabled = false
local teams = Spring.GetTeamList()
local SimpleAITeamIDs = {}
local SimpleAITeamIDsCount = 0
local SimpleCheaterAITeamIDs = {}
local SimpleCheaterAITeamIDsCount = 0
local UDN = UnitDefNames
local wind = Game.windMax

-- team locals
SimpleFactories = {}
SimpleT1Mexes = {}

for i = 1, #teams do
	local teamID = teams[i]
	local luaAI = Spring.GetTeamLuaAI(teamID)
	if luaAI and luaAI ~= "" and (string.sub(luaAI, 1, 8) == 'SimpleAI' or string.sub(luaAI, 1, 15) == 'SimpleCheaterAI' or string.sub(luaAI, 1, 16) == 'SimpleDefenderAI') then
		enabled = true
		SimpleAITeamIDsCount = SimpleAITeamIDsCount + 1
		SimpleAITeamIDs[SimpleAITeamIDsCount] = teamID

		SimpleFactories[teamID] = 0
		SimpleT1Mexes[teamID] = 0

		if string.sub(luaAI, 1, 15) == 'SimpleCheaterAI' or string.sub(luaAI, 1, 16) == 'SimpleDefenderAI' then
			SimpleCheaterAITeamIDsCount = SimpleCheaterAITeamIDsCount + 1
			SimpleCheaterAITeamIDs[SimpleCheaterAITeamIDsCount] = teamID
		end
	end
end

function gadget:GetInfo()
	return {
		name = "SimpleAI",
		desc = "123",
		author = "Damgam",
		date = "2020",
		layer = -100,
		enabled = enabled,
	}
end

-------- lists

local SimpleCommanderDefs = {}
local SimpleFactoriesDefs = {}
local SimpleConstructorDefs = {}
local SimpleExtractorDefs = {}
local SimpleGeneratorDefs = {}
local SimpleConverterDefs = {}
local SimpleTurretDefs = {}
local SimpleUndefinedBuildingDefs = {}
local SimpleUndefinedUnitDefs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.name == "armcom" or unitDef.name == "corcom" then
		SimpleCommanderDefs[#SimpleCommanderDefs + 1] = unitDefID
	elseif unitDef.isFactory and #unitDef.buildOptions > 0 then
		SimpleFactoriesDefs[#SimpleFactoriesDefs + 1] = unitDefID
	elseif unitDef.canMove and unitDef.isBuilder and #unitDef.buildOptions > 0 then
		SimpleConstructorDefs[#SimpleConstructorDefs + 1] = unitDefID
	elseif unitDef.extractsMetal > 0 then
		SimpleExtractorDefs[#SimpleExtractorDefs + 1] = unitDefID
	elseif (unitDef.energyMake > 19 and (not unitDef.energyUpkeep or unitDef.energyUpkeep < 10)) or (unitDef.windGenerator > 0 and wind > 10) or unitDef.tidalGenerator > 0 or (unitDef.customParams and unitDef.customParams.solar) then
		SimpleGeneratorDefs[#SimpleGeneratorDefs + 1] = unitDefID
	elseif unitDef.customParams and unitDef.customParams.energyconv_capacity and unitDef.customParams.energyconv_efficiency then
		SimpleConverterDefs[#SimpleConverterDefs + 1] = unitDefID
	elseif unitDef.isBuilding and #unitDef.weapons > 0 then
		SimpleTurretDefs[#SimpleTurretDefs + 1] = unitDefID


	elseif not unitDef.canMove then
		SimpleUndefinedBuildingDefs[#SimpleUndefinedBuildingDefs + 1] = unitDefID
	else
		SimpleUndefinedUnitDefs[#SimpleUndefinedUnitDefs + 1] = unitDefID
	end

end

-------- functions

local function SimpleGetClosestMexSpot(x, z)
	local bestSpot
	local bestDist = math.huge
	local metalSpots = GG.metalSpots
	if metalSpots then
		for i = 1, #metalSpots do
			local spot = metalSpots[i]
			local dx, dz = x - spot.x, z - spot.z
			local dist = dx * dx + dz * dz
			local units = Spring.GetUnitsInCylinder(spot.x, spot.z, 128)
			--local height = Spring.GetGroundHeight(spot.x, spot.z)
			if dist < bestDist and #units == 0 then
				--and height > 0 then
				bestSpot = spot
				bestDist = dist
			end
		end

	end
	return bestSpot
end

local function SimpleBuildOrder(cUnitID, building)
	local team = Spring.GetUnitTeam(cUnitID)
	local units = Spring.GetTeamUnits(team)
	local buildnear = units[math.random(1, #units)]
	local refDefID = Spring.GetUnitDefID(buildnear)
	local isBuilding = UnitDefs[refDefID].isBuilding
	local isCommander = (UnitDefs[refDefID].name == "armcom" or UnitDefs[refDefID].name == "corcom")
	local isExtractor = UnitDefs[refDefID].extractsMetal > 0
	if (isBuilding or isCommander) and not isExtractor then
		local refx, refy, refz = Spring.GetUnitPosition(buildnear)
		local reffootx = UnitDefs[refDefID].xsize * 8
		local reffootz = UnitDefs[refDefID].zsize * 8
		local spacing = math.random(64, 256)
		local testspacing = spacing * 0.75
		local buildingDefID = building
		local r = math.random(0, 3)
		if r == 0 then
			local bposx = refx
			local bposz = refz + reffootz + spacing
			local bposy = Spring.GetGroundHeight(bposx, bposz)--+100
			local testpos = Spring.TestBuildOrder(buildingDefID, bposx, bposy, bposz, r)
			local nearbyunits = Spring.GetUnitsInRectangle(bposx - testspacing, bposz - testspacing, bposx + testspacing, bposz + testspacing)
			if testpos == 2 and #nearbyunits <= 0 then
				Spring.GiveOrderToUnit(cUnitID, -buildingDefID, { bposx, bposy, bposz, r }, { "shift" })
			end
		elseif r == 1 then
			local bposx = refx + reffootx + spacing
			local bposz = refz
			local bposy = Spring.GetGroundHeight(bposx, bposz)--+100
			local testpos = Spring.TestBuildOrder(buildingDefID, bposx, bposy, bposz, r)
			local nearbyunits = Spring.GetUnitsInRectangle(bposx - testspacing, bposz - testspacing, bposx + testspacing, bposz + testspacing)
			if testpos == 2 and #nearbyunits <= 0 then
				Spring.GiveOrderToUnit(cUnitID, -buildingDefID, { bposx, bposy, bposz, r }, { "shift" })
			end
		elseif r == 2 then
			local bposx = refx
			local bposz = refz - reffootz - spacing
			local bposy = Spring.GetGroundHeight(bposx, bposz)--+100
			local testpos = Spring.TestBuildOrder(buildingDefID, bposx, bposy, bposz, r)
			local nearbyunits = Spring.GetUnitsInRectangle(bposx - testspacing, bposz - testspacing, bposx + testspacing, bposz + testspacing)
			if testpos == 2 and #nearbyunits <= 0 then
				Spring.GiveOrderToUnit(cUnitID, -buildingDefID, { bposx, bposy, bposz, r }, { "shift" })
			end
		elseif r == 3 then
			local bposx = refx - reffootx - spacing
			local bposz = refz
			local bposy = Spring.GetGroundHeight(bposx, bposz)--+100
			local testpos = Spring.TestBuildOrder(buildingDefID, bposx, bposy, bposz, r)
			local nearbyunits = Spring.GetUnitsInRectangle(bposx - testspacing, bposz - testspacing, bposx + testspacing, bposz + testspacing)
			if testpos == 2 and #nearbyunits <= 0 then
				Spring.GiveOrderToUnit(cUnitID, -buildingDefID, { bposx, bposy, bposz, r }, { "shift" })
			end
		end
	end
	--local buildingDefID = UnitDefNames.building.id
	--local testpos = Spring.TestBuildOrder(buildingDefID, bposx, bposy, bposz, facing)
end

function gadget:GameOver()
	gadgetHandler:RemoveGadget(self)
end

if gadgetHandler:IsSyncedCode() then

	function gadget:GameFrame(n)
		if n % 5 == 0 then
			for i = 1, #SimpleAITeamIDs do
				local teamID = SimpleAITeamIDs[i]
				local _, _, isDead, _, faction, allyTeamID = Spring.GetTeamInfo(teamID)
				local mcurrent, mstorage, _, mincome, mexpense = Spring.GetTeamResources(teamID, "metal")
				local ecurrent, estorage, _, eincome, eexpense = Spring.GetTeamResources(teamID, "energy")
				for j = 1, #SimpleCheaterAITeamIDs do
					if teamID == SimpleCheaterAITeamIDs[j] then
						-- --cheats
						if mcurrent < mstorage * 0.25 then
							Spring.SetTeamResource(teamID, "m", mstorage * 0.25)
						end
						if ecurrent < estorage * 0.25 then
							Spring.SetTeamResource(teamID, "e", estorage * 0.25)
						end
					end
				end

				local units = Spring.GetTeamUnits(teamID)
				for k = 1, #units do
					local unitID = units[k]
					local unitDefID = Spring.GetUnitDefID(unitID)
					local unitName = UnitDefs[unitDefID].name
					local unitTeam = teamID
					local unitHealth, unitMaxHealth, _, _, unitBuildProgress = Spring.GetUnitHealth(unitID)
					-- unitHealthPercentage = (unitHealth/unitMaxHealth)*100
					local unitMaxRange = Spring.GetUnitMaxRange(unitID)
					local unitCommands = Spring.GetCommandQueue(unitID, 0)
					local unitposx, unitposy, unitposz = Spring.GetUnitPosition(unitID)
					--Spring.Echo(faction)

					--if faction == "arm" then

					-- builders
					if unitCommands == 0 then
						for u = 1, #SimpleConstructorDefs do
							if unitDefID == SimpleConstructorDefs[u] then
								local r = math.random(0, 10)
								if ecurrent < estorage * 0.75 or r == 0 then
									for i = 1, 10 do
										SimpleBuildOrder(unitID, SimpleGeneratorDefs[math.random(1, #SimpleGeneratorDefs)])
									end
								elseif mcurrent < mstorage * 0.75 or r == 1 then
									local mexspotpos = SimpleGetClosestMexSpot(unitposx, unitposz)
									if ecurrent > estorage * 0.85 or (not mexspotpos) then
										SimpleBuildOrder(unitID, SimpleConverterDefs[math.random(1, #SimpleConverterDefs)])
									elseif mexspotpos then
										Spring.GiveOrderToUnit(unitID, -SimpleExtractorDefs[math.random(1, #SimpleExtractorDefs)], { mexspotpos.x, mexspotpos.y, mexspotpos.z, 0 }, { "shift" })
									end
								elseif r == 2 or r == 3 or r == 4 or r == 5 then
									SimpleBuildOrder(unitID, SimpleTurretDefs[math.random(1, #SimpleTurretDefs)])
								elseif (mcurrent > mstorage * 0.75 and ecurrent > estorage * 0.75) then
									--Spring.Echo(SimpleFactories[unitTeam])
									SimpleBuildOrder(unitID, SimpleFactoriesDefs[math.random(1, #SimpleFactoriesDefs)])
								else
									local r = math.random(0, 1)
									if r == 0 then
										SimpleBuildOrder(unitID, SimpleUndefinedBuildingDefs[math.random(1, #SimpleUndefinedBuildingDefs)])
									else
										for i = 1, 5 do
											SimpleBuildOrder(unitID, SimpleTurretDefs[math.random(1, #SimpleTurretDefs)])
										end
									end
								end
								break
							end
						end
						for u = 1, #SimpleCommanderDefs do
							if unitDefID == SimpleCommanderDefs[u] then
								--Spring.GiveOrderToUnit(unitID, CMD.MOVE,{unitposx+math.random(-500,500),5000,unitposz+math.random(-500,500)}, {"shift", "alt", "ctrl"})
								local r = math.random(0, 10)
								local mexspotpos = SimpleGetClosestMexSpot(unitposx, unitposz)
								if mexspotpos and SimpleT1Mexes[unitTeam] < 3 then
									Spring.GiveOrderToUnit(unitID, -SimpleExtractorDefs[math.random(1, #SimpleExtractorDefs)], { mexspotpos.x, mexspotpos.y, mexspotpos.z, 0 }, { "shift" })
								elseif ecurrent < estorage * 0.75 or r == 0 then
									for i = 1, 10 do
										SimpleBuildOrder(unitID, SimpleGeneratorDefs[math.random(1, #SimpleGeneratorDefs)])
									end
								elseif (ecurrent > estorage * 0.85 or (not mexspotpos)) and mcurrent < mstorage * 0.75 or r == 1 then
									SimpleBuildOrder(unitID, SimpleConverterDefs[math.random(1, #SimpleConverterDefs)])
								elseif r == 2 or r == 3 or r == 4 or r == 5 then
									SimpleBuildOrder(unitID, SimpleTurretDefs[math.random(1, #SimpleTurretDefs)])
								elseif (mcurrent > mstorage * 0.75 and ecurrent > estorage * 0.75) then
									--Spring.Echo(SimpleFactories[unitTeam])
									SimpleBuildOrder(unitID, SimpleFactoriesDefs[math.random(1, #SimpleFactoriesDefs)])
								else
									local r = math.random(0, 1)
									if r == 0 then
										SimpleBuildOrder(unitID, SimpleUndefinedBuildingDefs[math.random(1, #SimpleUndefinedBuildingDefs)])
									else
										for i = 1, 5 do
											SimpleBuildOrder(unitID, SimpleTurretDefs[math.random(1, #SimpleTurretDefs)])
										end
									end
								end
								break
							end
						end

						for u = 1, #SimpleFactoriesDefs do
							if unitDefID == SimpleFactoriesDefs[u] then
								if #Spring.GetFullBuildQueue(unitID, 0) < 5 then
									local r = math.random(0, 5)
									local x, y, z = Spring.GetUnitPosition(unitID)
									for i = 1, 10 do
										Spring.GiveOrderToUnit(unitID, -SimpleUndefinedUnitDefs[(math.random(1, #SimpleUndefinedUnitDefs))], { x, y, z, 0 }, 0)
										if r == 0 then
											Spring.GiveOrderToUnit(unitID, -SimpleConstructorDefs[(math.random(1, #SimpleConstructorDefs))], { x, y, z, 0 }, 0)
										end
									end
								end
								break
							end
						end

						-- army

						for u = 1, #SimpleUndefinedUnitDefs do

							if unitDefID == SimpleUndefinedUnitDefs[u] then
								local luaAI = Spring.GetTeamLuaAI(teamID)
								if string.sub(luaAI, 1, 16) == 'SimpleDefenderAI' then
									local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(units[math.random(1, #units)])
									Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { tUnitX + math.random(-100, 100), tUnitY, tUnitZ + math.random(-100, 100) }, { "shift", "alt", "ctrl" })
								else
									local targetUnitNear = Spring.GetUnitNearestEnemy(unitID, 2000, false)
									if targetUnitNear then
										local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(targetUnitNear)
										Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { tUnitX + math.random(-100, 100), tUnitY, tUnitZ + math.random(-100, 100) }, { "shift", "alt", "ctrl" })
									elseif n % 3600 == 0 then
										local targetUnit = Spring.GetUnitNearestEnemy(unitID, 999999, false)
										local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(targetUnit)
										Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { tUnitX + math.random(-100, 100), tUnitY, tUnitZ + math.random(-100, 100) }, { "shift", "alt", "ctrl" })
									end
									break
								end
							end
						end
					end
				end
			end
		end
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		local unitName = UnitDefs[unitDefID].name
		for i = 1, SimpleAITeamIDsCount do
			if SimpleAITeamIDs[i] == unitTeam then
				for u = 1, #SimpleFactoriesDefs do
					if unitDefID == SimpleFactoriesDefs[u] then
						SimpleFactories[unitTeam] = SimpleFactories[unitTeam] + 1
						break
					end
				end
				for u = 1, #SimpleExtractorDefs do
					if unitDefID == SimpleExtractorDefs[u] then
						SimpleT1Mexes[unitTeam] = SimpleT1Mexes[unitTeam] + 1
						break
					end
				end
			end
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
		local unitName = UnitDefs[unitDefID].name
		for i = 1, SimpleAITeamIDsCount do
			if SimpleAITeamIDs[i] == unitTeam then
				for u = 1, #SimpleFactoriesDefs do
					if unitDefID == SimpleFactoriesDefs[u] then
						SimpleFactories[unitTeam] = SimpleFactories[unitTeam] - 1
						break
					end
				end
				for u = 1, #SimpleExtractorDefs do
					if unitDefID == SimpleExtractorDefs[u] then
						SimpleT1Mexes[unitTeam] = SimpleT1Mexes[unitTeam] - 1
						break
					end
				end
			end
		end
	end


end
