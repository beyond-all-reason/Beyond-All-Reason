local enabled = false
local teams = Spring.GetTeamList()
local SimpleAITeamIDs = {}
local SimpleAITeamIDsCount = 0
local SimpleCheaterAITeamIDs = {}
local SimpleCheaterAITeamIDsCount = 0
local UDN = UnitDefNames

-- team locals
SimpleFactories = {}
SimpleT1Mexes = {}

for i = 1,#teams do
	local teamID = teams[i]
	local luaAI = Spring.GetTeamLuaAI(teamID)
	if luaAI and luaAI ~= "" and (string.sub(luaAI, 1, 8) == 'SimpleAI' or string.sub(luaAI, 1, 15) == 'SimpleCheaterAI') then
		enabled = true
		SimpleAITeamIDsCount = SimpleAITeamIDsCount + 1
		SimpleAITeamIDs[SimpleAITeamIDsCount] = teamID

		SimpleFactories[teamID] = 0
		SimpleT1Mexes[teamID] = 0

		if string.sub(luaAI, 1, 15) == 'SimpleCheaterAI' then
			SimpleCheaterAITeamIDsCount = SimpleCheaterAITeamIDsCount + 1
			SimpleCheaterAITeamIDs[SimpleCheaterAITeamIDsCount] = teamID
		end
	end
end

function gadget:GetInfo()
  return {
    name      = "SimpleAI",
    desc      = "123",
    author    = "Damgam",
    date      = "2020",
    layer     = -100,
    enabled   = enabled,
  }
end










-------- lists

	local nameCommanderArm = "armcom"
	local nameCommanderCor = "corcom"

-- Factories

-- Eco

-- Defences

-- Constructors
	local SimpleConstructors = {
		"armck",
		"armdecom",
	}

	local SimpleConstructorsBuildOrders = {
		UDN.armck.id,
		UDN.armdecom.id,
	}
	
	local SimpleFactories = {
		"armaap",
		"armalab",
		"armap",
		"armavp",
		"armhp",
		"armlab",
		"armshltx",
		"armvp",
		"armamsub",
		"armasy",
		"armfhp",
		"armplat",
		"armshltxuw",
		"armsy",
	}
	
	local SimpleFactoriesBuildOrders = {
		UDN.armaap.id,
		UDN.armalab.id,
		UDN.armap.id,
		UDN.armavp.id,
		UDN.armhp.id,
		UDN.armlab.id,
		UDN.armshltx.id,
		UDN.armvp.id,
		UDN.armamsub.id,
		UDN.armasy.id,
		UDN.armfhp.id,
		UDN.armplat.id,
		UDN.armshltxuw.id,
		UDN.armsy.id,

	}
	
	local SimpleEnergy = {
		"aaa",
	}
	
	local SimpleEnergyBuildOrders = {
		"aaa",
	}
	
	local SimpleMetal = {
		"aaa",
	}
	
	local SimpleMetalBuildOrders = {
		"aaa",
	}
	
	local SimpleConverter = {
		"aaa",
	}
	
	local SimpleConverterBuildOrders = {
		"aaa",
	}
	
	local SimpleDefence = {
		"aaa",
	}
	
	local SimpleDefenceBuildOrders = {
		"aaa",
	}

-- Army
	local SimpleLandArmy = {
		----ARM
		-- t1 kbots
		"armflea",
		"armham",
		"armjeth",
		"armpw",
		"armrectr",
		"armrock",
		"armwar",
		-- t2 kbots
		"armaak",
		"armamph",
		"armaser",
		"armfark",
		"armfast",
		"armfboy",
		"armfido",
		"armmark",
		"armmav",
		"armscab",
		"armsnipe",
		"armspid",
		"armsptk",
		"armspy",
		"armvader",
		"armzeus",
		---- CORE
	}

	local SimpleLandArmyBuildOrders = {
		UDN.armflea.id,
		UDN.armham.id,
		UDN.armjeth.id,
		UDN.armpw.id,
		UDN.armrectr.id,
		UDN.armrock.id,
		UDN.armwar.id,

	}
	
	local SimpleAirArmy = {
		"aaa",
	}

	local SimpleAirArmyBuildOrders = {
		"aaa",
	}













	-------- functions

local function SimpleGetClosestMexSpot(x,z)
	local bestSpot
	local bestDist = math.huge
	local metalSpots = GG.metalSpots
	for i = 1, #metalSpots do
		local spot = metalSpots[i]
		local dx, dz = x - spot.x, z - spot.z
		local dist = dx*dx + dz*dz
		local units = Spring.GetUnitsInCylinder(spot.x, spot.z, 64)
		local height = Spring.GetGroundHeight(spot.x, spot.z)
		if dist < bestDist and #units == 0 and height > 0 then
			bestSpot = spot
			bestDist = dist
		end
	end
	return bestSpot
end

local function SimpleBuildOrder(cUnitID, building)
	local team = Spring.GetUnitTeam(cUnitID)
	local units = Spring.GetTeamUnits(team)
	local buildnear = units[math.random(1,#units)]
	local refDefID = Spring.GetUnitDefID(buildnear)
	local isBuilding = UnitDefs[refDefID].isBuilding
	local isCommander = (UnitDefs[refDefID].name == "armcom" or UnitDefs[refDefID].name == "corcom")
	if isBuilding or isCommander then
		local refx, refy, refz = Spring.GetUnitPosition(buildnear)
		local reffootx = UnitDefs[refDefID].xsize*8
		local reffootz = UnitDefs[refDefID].zsize*8
		local spacing = math.random(96,128)
		local buildingDefID = building
		local r = math.random (0,3)
		if r == 0 then
			local bposx = refx
			local bposz = refz + reffootz + spacing
			local bposy = Spring.GetGroundHeight(bposx, bposz)--+100
			local testpos = Spring.TestBuildOrder(buildingDefID, bposx, bposy, bposz, r)
			if testpos == 2 then
				Spring.GiveOrderToUnit(cUnitID, -buildingDefID,{bposx,bposy,bposz,r}, {"shift"})
			end
		elseif r == 1 then
			local bposx = refx + reffootx + spacing
			local bposz = refz
			local bposy = Spring.GetGroundHeight(bposx, bposz)--+100
			local testpos = Spring.TestBuildOrder(buildingDefID, bposx, bposy, bposz, r)
			if testpos == 2 then
				Spring.GiveOrderToUnit(cUnitID, -buildingDefID,{bposx,bposy,bposz,r}, {"shift"})
			end
		elseif r == 2 then
			local bposx = refx
			local bposz = refz - reffootz - spacing
			local bposy = Spring.GetGroundHeight(bposx, bposz)--+100
			local testpos = Spring.TestBuildOrder(buildingDefID, bposx, bposy, bposz, r)
			if testpos == 2 then
				Spring.GiveOrderToUnit(cUnitID, -buildingDefID,{bposx,bposy,bposz,r}, {"shift"})
			end
		elseif r == 3 then
			local bposx = refx - reffootx - spacing
			local bposz = refz
			local bposy = Spring.GetGroundHeight(bposx, bposz)--+100
			local testpos = Spring.TestBuildOrder(buildingDefID, bposx, bposy, bposz, r)
			if testpos == 2 then
				Spring.GiveOrderToUnit(cUnitID, -buildingDefID,{bposx,bposy,bposz,r}, {"shift"})
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
	if n%30 == 0 then
		for i = 1,#SimpleAITeamIDs do
			local teamID = SimpleAITeamIDs[i]
			local _,_,isDead,_,faction,allyTeamID = Spring.GetTeamInfo(teamID)
			local mcurrent, mstorage, _, mincome, mexpense = Spring.GetTeamResources(teamID, "metal")
			local ecurrent, estorage, _, eincome, eexpense = Spring.GetTeamResources(teamID, "energy")
			for j = 1,#SimpleCheaterAITeamIDs do
				if teamID == SimpleCheaterAITeamIDs[j] then
					-- --cheats
					if mcurrent < mstorage*0.75 then
						Spring.SetTeamResource(teamID, "m", mstorage*0.75)
					end
					if ecurrent < estorage*0.75 then
						Spring.SetTeamResource(teamID, "e", estorage*0.75)
					end
				end
			end
















			local units = Spring.GetTeamUnits(teamID)
			for k = 1,#units do
				local unitID = units[k]
				local unitDefID = Spring.GetUnitDefID(unitID)
				local unitName = UnitDefs[unitDefID].name
				local unitTeam = teamID
				local unitHealth,unitMaxHealth,_,_,unitBuildProgress = Spring.GetUnitHealth(unitID)
				-- unitHealthPercentage = (unitHealth/unitMaxHealth)*100
				local unitMaxRange = Spring.GetUnitMaxRange(unitID)
				local unitCommands = Spring.GetCommandQueue(unitID, 0)
				local unitposx, unitposy, unitposz = Spring.GetUnitPosition(unitID)
				--Spring.Echo(faction)







				--if faction == "arm" then


					-- builders
					if unitCommands == 0 then
						for u = 1,#SimpleConstructors do
							if unitName == SimpleConstructors[u] then
								if SimpleFactories[unitTeam] < Spring.GetGameSeconds()*0.00333 then
									SimpleBuildOrder(unitID, UDN.armlab.id)
								end
								local r = math.random(0,8)
								local mexspotpos = SimpleGetClosestMexSpot(unitposx,unitposz)


								if r == 0 then
									SimpleBuildOrder(unitID, UDN.armllt.id)
								elseif r >= 1 and r <= 4 then
									if mexspotpos then
										Spring.GiveOrderToUnit(unitID, -UDN.armmex.id, {mexspotpos.x, mexspotpos.y, mexspotpos.z, 0}, {"shift"})
									end
								else
									SimpleBuildOrder(unitID, UDN.armsolar.id)
								end
								break
							end
						end
						if unitName == "armcom" then
							--Spring.GiveOrderToUnit(unitID, CMD.MOVE,{unitposx+math.random(-500,500),5000,unitposz+math.random(-500,500)}, {"shift", "alt", "ctrl"})
							if SimpleFactories[unitTeam] < Spring.GetGameSeconds()*0.00333 then
								SimpleBuildOrder(unitID, UDN.armlab.id)
							end
							local r = math.random(0,10)
							local mexspotpos = SimpleGetClosestMexSpot(unitposx,unitposz)
							if mexspotpos and SimpleT1Mexes[unitTeam] < 3 then
								Spring.GiveOrderToUnit(unitID, -UDN.armmex.id, {mexspotpos.x, mexspotpos.y, mexspotpos.z, 0}, {"shift"})
							end
							if r == 0 then
								SimpleBuildOrder(unitID, UDN.armllt.id)
							else
								SimpleBuildOrder(unitID, UDN.armsolar.id)
							end
							--break
						end

						if unitName == "armlab" then
							if #Spring.GetFullBuildQueue(unitID, 0) == 0 then
								local r = math.random(0,5)
								local x,y,z = Spring.GetUnitPosition(unitID)
								Spring.GiveOrderToUnit(unitID, -SimpleLandArmyBuildOrders[(math.random(1, #SimpleLandArmyBuildOrders))], {x, y, z, 0}, 0)
								if r == 0 then
									Spring.GiveOrderToUnit(unitID, -SimpleConstructorsBuildOrders[(math.random(1, #SimpleConstructorsBuildOrders))], {x, y, z, 0}, 0)
								end
							end
							--break
						end


					-- army

						for u = 1,#SimpleLandArmy do

							if unitName == SimpleLandArmy[u] then
								local targetUnitNear = Spring.GetUnitNearestEnemy(unitID, 2000, false)
								if targetUnitNear then
									local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(targetUnitNear)
									Spring.GiveOrderToUnit(unitID, CMD.FIGHT,{tUnitX+math.random(-100,100),5000,tUnitZ+math.random(-100,100)}, {"shift", "alt", "ctrl"})
								elseif n%3600 == 0 then
									local targetUnit = Spring.GetUnitNearestEnemy(unitID, 999999, false)
									local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(targetUnit)
									Spring.GiveOrderToUnit(unitID, CMD.FIGHT,{tUnitX+math.random(-100,100),5000,tUnitZ+math.random(-100,100)}, {"shift", "alt", "ctrl"})
								end
								break
							end
						end
					end





				--elseif faction == "core" then


					-- builders
					if unitCommands == 0 then
						if unitName == "corcom" then
							--Spring.GiveOrderToUnit(unitID, CMD.MOVE,{unitposx+math.random(-500,500),5000,unitposz+math.random(-500,500)}, {"shift", "alt", "ctrl"})
							SimpleBuildOrder(unitID, UDN.corwin.id)
							--break
						end
					end


					-- army


				--end
			end
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local unitName = UnitDefs[unitDefID].name
	for i = 1,SimpleAITeamIDsCount do
		if SimpleAITeamIDs == unitTeam then
			if unitName == "armlab" then
				SimpleFactories[unitTeam] = SimpleFactories[unitTeam] + 1
			end
			if unitName == "armmex" then
				SimpleT1Mexes[unitTeam] = SimpleT1Mexes[unitTeam] + 1
			end
		end
	break
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	local unitName = UnitDefs[unitDefID].name
	for i = 1,SimpleAITeamIDsCount do
		if SimpleAITeamIDs == unitTeam then
			if unitName == "armlab" then
				SimpleFactories[unitTeam] = SimpleFactories[unitTeam] - 1
			end
			if unitName == "armmex" then
				SimpleT1Mexes[unitTeam] = SimpleT1Mexes[unitTeam] - 1
			end
		end
	break
	end
end


end
