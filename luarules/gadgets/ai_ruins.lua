
if not (Spring.GetModOptions().ruins == "enabled" or (Spring.GetModOptions().ruins == "scav_only" and Spring.Utilities.Gametype.IsScavengers())) then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "ruin spawn",
		desc      = "123",
		author    = "Damgam",
		date      = "2020",
		license   = "GNU GPL, v2 or later",
		layer     = -100,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- these are used in poschecks.lua so arent localized here
local mapsizeX = Game.mapSizeX
local mapsizeZ = Game.mapSizeZ
local GaiaTeamID = Spring.GetGaiaTeamID()
local GaiaAllyTeamID = select(6, Spring.GetTeamInfo(GaiaTeamID))

local ruinDensity = Spring.GetModOptions().ruins_density
local ruinDensityMultiplier = 1
if ruinDensity == "veryrare" then
	ruinDensityMultiplier = 0.25
elseif ruinDensity == "rare" then
	ruinDensityMultiplier = 0.5
elseif ruinDensity == "normal" then
	ruinDensityMultiplier = 1
elseif ruinDensity == "dense" then
	ruinDensityMultiplier = 2
elseif ruinDensity == "verydense" then
	ruinDensityMultiplier = 4
end

math_random = math.random	-- not a local cause the includes below use it

local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")
local blueprintController = VFS.Include('luarules/gadgets/ruins/Blueprints/BYAR/blueprint_controller.lua')
local scavConfig = VFS.Include('LuaRules/Configs/scav_spawn_defs.lua')

local spawnCutoffFrame = (math.ceil( math.ceil(mapsizeX*mapsizeZ) / 1000000 )) * 3

-- TODO: Add weights to this crap.
local landMexesList = {
	"armmex",
	"armamex",
	"armmoho",
	"armmoho",
	"armmoho",
	"armmoho",
	"armshockwave",
	"cormex",
	"corexp",
	"cormoho",
	"cormoho",
	"cormoho",
	"cormoho",
	"cormexp",
	"cormexp",
	"legmex",
	"legmext15",
	"legmoho",
	"legmoho",
	"legmoho",
	"legmoho",
	"legmohocon",
	"legmohocon",
}

local seaMexesList = {
	"armmex",
	"armuwmme",
	"armuwmme",
	"armuwmme",
	"armuwmme",
	"cormex",
	"coruwmme",
	"coruwmme",
	"coruwmme",
	"coruwmme",
}

local landGeosList = {
	"armgeo",
	"armgmm",
	"armageo",
	"armageo",
	"armageo",
	"armageo",
	"corgeo",
	"corageo",
	"corageo",
	"corageo",
	"corageo",
	"corbhmth",
	"corbhmth",
	"leggeo",
	"legageo",
	"legageo",
	"legageo",
	"legageo",
	"legrampart",
}

local seaGeosList = {
	"armuwgeo",
	"armuwageo",
	"coruwgeo",
	"coruwageo",
}

local landDefences = {}
local seaDefences = {}
for i = 1,#scavConfig.unprocessedScavTurrets do
	if i ~= 7 then -- we don't want the endgame stuff in these ruins
		for unitName, defs in pairs(scavConfig.unprocessedScavTurrets[i]) do

			if string.sub(unitName, -5, -1) == "_scav" and UnitDefNames[string.sub(unitName, 1, -6)] then unitName = string.sub(unitName, 1, -6) end -- convert scav unit into non-scav
			if not UnitDefNames[unitName] then
				Spring.Echo("We got a fucked unit name here: " .. unitName)
			end
			if defs.type ~= "nuke" and UnitDefNames[unitName] and not UnitDefNames[unitName].isFactory then -- we don't want nukes and factories in ruins
				if defs.surface == "land" then
					for _ = 1,defs.maxExisting*((7-i)^2) do
						landDefences[#landDefences+1] = unitName
					end
				elseif defs.surface == "sea" then
					for _ = 1,defs.maxExisting*((7-i)^2) do
						seaDefences[#seaDefences+1] = unitName
					end
				elseif defs.surface == "mixed" then
					for _ = 1,defs.maxExisting*((7-i)^2) do
						landDefences[#landDefences+1] = unitName
						seaDefences[#seaDefences+1] = unitName
					end
				end
			end
		end
	end
end



local function randomlyRotateBlueprint()
	local randomRotation = math.random(0,3)
	if randomRotation == 0 then -- normal
		local swapXandY = false
		local flipX = 1
		local flipZ = 1
		local rotation = randomRotation
		return swapXandY, flipX, flipZ, rotation
	end
	if randomRotation == 1 then -- 90 degrees anti-clockwise
		local swapXandY = true
		local flipX = 1
		local flipZ = -1
		local rotation = randomRotation
		return swapXandY, flipX, flipZ, rotation
	end
	if randomRotation == 2 then -- 180 degrees anti-clockwise
		local swapXandY = false
		local flipX = -1
		local flipZ = -1
		local rotation = randomRotation
		return swapXandY, flipX, flipZ, rotation
	end
	if randomRotation == 3 then -- 270 degrees anti-clockwise
		local swapXandY = true
		local flipX = -1
		local flipZ = 1
		local rotation = randomRotation
		return swapXandY, flipX, flipZ, rotation
	end
end

local function randomlyMirrorBlueprint(mirrored, direction, unitFacing)
	if mirrored == true then
		if direction == "h" then
			local mirrorX = -1
			local mirrorZ = 1
			if unitFacing == 1 or unitFacing == 3 then
				local mirrorRotation = 2
				return mirrorX, mirrorZ, mirrorRotation
			else
				local mirrorRotation = 0
				return mirrorX, mirrorZ, mirrorRotation
			end
		elseif direction == "v" then
			local mirrorX = 1
			local mirrorZ = -1
			if unitFacing == 0 or unitFacing == 2 then
				local mirrorRotation = 2
				return mirrorX, mirrorZ, mirrorRotation
			else
				local mirrorRotation = 0
				return mirrorX, mirrorZ, mirrorRotation
			end
		end
	else
		local mirrorX = 1
		local mirrorZ = 1
		local mirrorRotation = 0
		return mirrorX, mirrorZ, mirrorRotation
	end
end


function getNearestBlocker(x, z)
	local lowestDist = math.huge
	local metalSpots = GG["resource_spot_finder"] and GG["resource_spot_finder"].metalSpotsList or nil
	if metalSpots then
		for i = 1, #metalSpots do
			local spot = metalSpots[i]
            if spot then
			    local dx, dz = x - spot.x, z - spot.z
			    local dist = dx * dx + dz * dz
			    if dist < lowestDist then
			    	lowestDist = dist
			    end
            end
		end
    end
	local geoSpots = GG["resource_spot_finder"] and GG["resource_spot_finder"].geoSpotsList or nil
	if geoSpots then
		for i = 1, #geoSpots do
			local spot = geoSpots[i]
            if spot then
			    local dx, dz = x - spot.x, z - spot.z
			    local dist = dx * dx + dz * dz
			    if dist < lowestDist then
			    	lowestDist = dist
			    end
            end
		end
    end
	--Spring.Echo(lowestDist, math.sqrt(lowestDist))
    return math.sqrt(lowestDist)
end

local function spawnRuin(ruin, posx, posy, posz, blueprintTierLevel)
	local swapXandY, flipX, flipZ, rotation = randomlyRotateBlueprint()
	local mirrored, mirroredDirection, xOffset, zOffset
	if math.random(0,1) == 0 then
		if math.random(0,1) == 0 then
			mirrored = true
			mirroredDirection = "h"
		else
			mirrored = true
			mirroredDirection = "v"
		end
	else
		mirrored = false
		mirroredDirection = "null"
	end
	for _, building in ipairs(ruin.buildings) do
		if building.unitDefID then
			if swapXandY == false then
				xOffset = building.xOffset
				zOffset = building.zOffset
			else
				xOffset = building.zOffset
				zOffset = building.xOffset
			end
			local mirrorX, mirrorZ, mirrorRotation = randomlyMirrorBlueprint(mirrored, mirroredDirection, (building.direction+rotation)%4)

			local name = UnitDefs[building.unitDefID].name
			local nonscavname = string.gsub(name, "_scav", "")
			local r = math.random(1,100)
			if r < 40 and UnitDefNames[nonscavname] then
				local posy = Spring.GetGroundHeight(posx + (xOffset*flipX*mirrorX), posz + (zOffset*flipZ*mirrorZ))
				local unit = Spring.CreateUnit(UnitDefNames[nonscavname].id, posx + (xOffset*flipX*mirrorX), posy, posz + (zOffset*flipZ*mirrorZ), (building.direction+rotation+mirrorRotation)%4, GaiaTeamID)
				if unit then
					local radarRange = UnitDefs[building.unitDefID].radarDistance
					local canMove = UnitDefs[building.unitDefID].canMove
					local speed = UnitDefs[building.unitDefID].speed

					Spring.SetUnitNeutral(unit, true)
					Spring.GiveOrderToUnit(unit, CMD.FIRE_STATE, {1}, 0)
					Spring.GiveOrderToUnit(unit, CMD.MOVE_STATE, {0}, 0)
					--Spring.SetUnitAlwaysVisible(unit, true)

					if building.patrol and canMove and speed > 0 then
						for i = 1, 6 do
							Spring.GiveOrderToUnit(unit, CMD.PATROL, { posx + (math.random(-200, 200)), posy + 100, posz + (math.random(-200, 200)) }, {"shift", "alt", "ctrl"})
						end
					end

					if radarRange and radarRange > 1000 then
						Spring.GiveOrderToUnit(unit, CMD.ONOFF, {0}, 0)
					end
				end
			-- elseif r < 90 and FeatureDefNames[name .. "_dead"] then
			-- 	local wreck = Spring.CreateFeature(name .. "_dead", posx + (xOffset*flipX*mirrorX), posy, posz + (zOffset*flipZ*mirrorZ), (building.direction+rotation+mirrorRotation)%4, GaiaTeamID)
			-- 	Spring.SetFeatureAlwaysVisible(wreck, false)
			-- 	Spring.SetFeatureResurrect(wreck, name)
			end
		end
	end
	mirrored = nil
	mirroredDirection = nil
end

local SpawnedMexes = {}
local function SpawnMexes(mexSpots)
	for i = 1,#mexSpots do
		if math.random(0,2) == 0 then
			local spot = mexSpots[i]
			local posx = math.ceil(spot.x/16)*16
			local posz = math.ceil(spot.z/16)*16
			local posy = Spring.GetGroundHeight(posx, posz)
			local mexesList
			if posy > 0 then
				mexesList = landMexesList
			else
				mexesList = seaMexesList
			end

			local radius = 32
			local canBuildHere = positionCheckLibrary.VisibilityCheckEnemy(posx, posy, posz, radius, GaiaAllyTeamID, true, true, true)
						and positionCheckLibrary.MapEdgeCheck(posx, posy, posz, radius)
						and positionCheckLibrary.OccupancyCheck(posx, posy, posz, radius)
						and positionCheckLibrary.FlatAreaCheck(posx, posy, posz, radius)

			if posy > 0 then
				canBuildHere = canBuildHere and positionCheckLibrary.SurfaceCheck(posx, posy, posz, radius)
			elseif posy <= 0 then
				canBuildHere = canBuildHere and positionCheckLibrary.SurfaceCheck(posx, posy, posz, radius, true)
			end

			if canBuildHere then
				local mex = mexesList[math.random(1,#mexesList)]
				local unit = Spring.CreateUnit(UnitDefNames[mex].id, posx, posy, posz, math.random(0,3), GaiaTeamID)
				Spring.SetUnitNeutral(unit, true)
				Spring.GiveOrderToUnit(unit, CMD.FIRE_STATE, {1}, 0)
				Spring.GiveOrderToUnit(unit, CMD.MOVE_STATE, {0}, 0)
				SpawnedMexes[i] = math.random(1,2)
			end
		end
	end
end

local SpawnedGeos = {}
local function SpawnGeos(geoSpots)
	for i = 1,#geoSpots do
		if math.random(0,1) == 0 then
			local spot = geoSpots[i]
			local posx = math.ceil(spot.x/16)*16
			local posz = math.ceil(spot.z/16)*16
			local posy = Spring.GetGroundHeight(posx, posz)
			local geosList
			if posy > 0 then
				geosList = landGeosList
			else
				geosList = seaGeosList
			end

			local radius = 32
			local canBuildHere = positionCheckLibrary.VisibilityCheckEnemy(posx, posy, posz, radius, GaiaAllyTeamID, true, true, true)
						and positionCheckLibrary.MapEdgeCheck(posx, posy, posz, radius)
						and positionCheckLibrary.OccupancyCheck(posx, posy, posz, radius)
						and positionCheckLibrary.FlatAreaCheck(posx, posy, posz, radius)

			if posy > 0 then
				canBuildHere = canBuildHere and positionCheckLibrary.SurfaceCheck(posx, posy, posz, radius)
			elseif posy <= 0 then
				canBuildHere = canBuildHere and positionCheckLibrary.SurfaceCheck(posx, posy, posz, radius, true)
			end

			if canBuildHere then
				local geo = geosList[math.random(1,#geosList)]
				local unit = Spring.CreateUnit(UnitDefNames[geo].id, posx, posy, posz, math.random(0,3), GaiaTeamID)
				Spring.SetUnitNeutral(unit, true)
				Spring.GiveOrderToUnit(unit, CMD.FIRE_STATE, {1}, 0)
				Spring.GiveOrderToUnit(unit, CMD.MOVE_STATE, {0}, 0)
				SpawnedGeos[i] = math.random(2,3)
			end
		end
	end
end

local function SpawnMexGeoRandomStructures()
	local mexSpots = GG["resource_spot_finder"] and GG["resource_spot_finder"].metalSpotsList or nil
	if mexSpots and #mexSpots > 5 then
		for i = 1,#mexSpots do
			if SpawnedMexes[i] then
				local spot = mexSpots[i]
				for j = 1,SpawnedMexes[i] do
					local posx2 = math.ceil((spot.x+math.random(-512,512))/16)*16
					local posz2 = math.ceil((spot.z+math.random(-512,512))/16)*16
					local posy2 = Spring.GetGroundHeight(posx2, posz2)
					local defencesList
					if posy2 > 0 then
						defencesList = landDefences
					else
						defencesList = seaDefences
					end

					local radius = 128
					local canBuildHere = positionCheckLibrary.VisibilityCheckEnemy(posx2, posy2, posz2, radius, GaiaAllyTeamID, true, true, true)
								and positionCheckLibrary.MapEdgeCheck(posx2, posy2, posz2, radius)
								and positionCheckLibrary.OccupancyCheck(posx2, posy2, posz2, radius)
								and positionCheckLibrary.FlatAreaCheck(posx2, posy2, posz2, radius)

					if posy2 > 0 then
						canBuildHere = canBuildHere and positionCheckLibrary.SurfaceCheck(posx2, posy2, posz2, radius)
					elseif posy2 <= 0 then
						canBuildHere = canBuildHere and positionCheckLibrary.SurfaceCheck(posx2, posy2, posz2, radius, true)
					end

					if canBuildHere and getNearestBlocker(posx2, posz2) < radius then
						canBuildHere = false
					end

					if canBuildHere then
						local defence = defencesList[math.random(1,#defencesList)]
						local unit = Spring.CreateUnit(UnitDefNames[defence].id, posx2, posy2, posz2, math.random(0,3), GaiaTeamID)
						Spring.SetUnitNeutral(unit, true)
						Spring.GiveOrderToUnit(unit, CMD.FIRE_STATE, {1}, 0)
						Spring.GiveOrderToUnit(unit, CMD.MOVE_STATE, {0}, 0)
					end
				end
			end
		end
	end

	local geoSpots = GG["resource_spot_finder"] and GG["resource_spot_finder"].geoSpotsList or nil
	if geoSpots and #geoSpots >= 1 then
		for i = 1,#geoSpots do
			if SpawnedGeos[i] then
				local spot = geoSpots[i]
				for j = 1,SpawnedGeos[i] do
					local posx2 = math.ceil((spot.x+math.random(-1024,1024))/16)*16
					local posz2 = math.ceil((spot.z+math.random(-1024,1024))/16)*16
					local posy2 = Spring.GetGroundHeight(posx2, posz2)
					local defencesList
					if posy2 > 0 then
						defencesList = landDefences
					else
						defencesList = seaDefences
					end

					local radius = 128
					local canBuildHere = positionCheckLibrary.VisibilityCheckEnemy(posx2, posy2, posz2, radius, GaiaAllyTeamID, true, true, true)
								and positionCheckLibrary.MapEdgeCheck(posx2, posy2, posz2, radius)
								and positionCheckLibrary.OccupancyCheck(posx2, posy2, posz2, radius)
								and positionCheckLibrary.FlatAreaCheck(posx2, posy2, posz2, radius)

					if posy2 > 0 then
						canBuildHere = canBuildHere and positionCheckLibrary.SurfaceCheck(posx2, posy2, posz2, radius)
					elseif posy2 <= 0 then
						canBuildHere = canBuildHere and positionCheckLibrary.SurfaceCheck(posx2, posy2, posz2, radius, true)
					end

					if canBuildHere and getNearestBlocker(posx2, posz2) < radius then
						canBuildHere = false
					end

					if canBuildHere then
						local defence = defencesList[math.random(1,#defencesList)]
						local unit = Spring.CreateUnit(UnitDefNames[defence].id, posx2, posy2, posz2, math.random(0,3), GaiaTeamID)
						Spring.SetUnitNeutral(unit, true)
						Spring.GiveOrderToUnit(unit, CMD.FIRE_STATE, {1}, 0)
						Spring.GiveOrderToUnit(unit, CMD.MOVE_STATE, {0}, 0)
					end
				end
			end
		end
	end
end

local function SpawnRandomStructures()
	for i = 1,math.ceil(spawnCutoffFrame/10) do
		for j = 1,20 do
			local posx = math.ceil(math.random(196,Game.mapSizeX-196)/16)*16
			local posz = math.ceil(math.random(196,Game.mapSizeZ-196)/16)*16
			local posy = Spring.GetGroundHeight(posx, posz)
			local defencesList
			if posy > 0 then
				defencesList = landDefences
			else
				defencesList = seaDefences
			end

			local radius = 128
			local canBuildHere = positionCheckLibrary.VisibilityCheckEnemy(posx, posy, posz, radius, GaiaAllyTeamID, true, true, true)
						and positionCheckLibrary.MapEdgeCheck(posx, posy, posz, radius)
						and positionCheckLibrary.OccupancyCheck(posx, posy, posz, radius)
						and positionCheckLibrary.FlatAreaCheck(posx, posy, posz, radius)

			if posy > 0 then
				canBuildHere = canBuildHere and positionCheckLibrary.SurfaceCheck(posx, posy, posz, radius)
			elseif posy <= 0 then
				canBuildHere = canBuildHere and positionCheckLibrary.SurfaceCheck(posx, posy, posz, radius, true)
			end

			if canBuildHere and getNearestBlocker(posx, posz) < radius then
				canBuildHere = false
			end

			if canBuildHere then
				local defence = defencesList[math.random(1,#defencesList)]
				local unit = Spring.CreateUnit(UnitDefNames[defence].id, posx, posy, posz, math.random(0,3), GaiaTeamID)
				Spring.SetUnitNeutral(unit, true)
				Spring.GiveOrderToUnit(unit, CMD.FIRE_STATE, {1}, 0)
				Spring.GiveOrderToUnit(unit, CMD.MOVE_STATE, {0}, 0)
				break
			end
		end
	end
end

function gadget:GameFrame(n)

	if n == 15 then
		local mexSpots = GG["resource_spot_finder"] and GG["resource_spot_finder"].metalSpotsList or nil
		if mexSpots and #mexSpots > 5 then
			SpawnMexes(mexSpots)
		end
	end

	if n == 30 then
		local geoSpots = GG["resource_spot_finder"] and GG["resource_spot_finder"].geoSpotsList or nil
		if geoSpots and #geoSpots >= 1 then
			SpawnGeos(geoSpots)
		end
	end

	if n == spawnCutoffFrame then
		SpawnMexGeoRandomStructures()
	end

	if n == spawnCutoffFrame + 5 then
		SpawnRandomStructures()
	end

	if n < (10/ruinDensityMultiplier) or n%(10/ruinDensityMultiplier) ~= 0 or n > spawnCutoffFrame+5 then
		return
	end

	local landRuin, seaRuin, posx, posy, posz, seaRuinChance, radius, canBuildHere, r, blueprintTierLevel
	for i = 1, 100 do
		local ruin
		posx = math.random(0, Game.mapSizeX)
		posz = math.random(0, Game.mapSizeZ)
		posy = Spring.GetGroundHeight(posx, posz)
		seaRuinChance = math.random(1, 2)

		r = math.random(0,100) -- replace 100 with 200 when we get civilians
		blueprintTierLevel = 0
		-- if r > 100 and Spring.GetModOptions().ruins_civilian_disable == false then
		-- 	landRuin = blueprintController.Ruin.GetRandomLandBlueprint()
		-- 	seaRuin = blueprintController.Ruin.GetRandomSeaBlueprint()
		-- 	blueprintTierLevel = -1
		if r > 98 and Spring.GetModOptions().ruins_only_t1 == false then -- elseif
			landRuin = blueprintController.GetRandomLandBlueprint(4)
			seaRuin = blueprintController.GetRandomSeaBlueprint(4)
			blueprintTierLevel = 4
		elseif r > 95 and Spring.GetModOptions().ruins_only_t1 == false then
			landRuin = blueprintController.GetRandomLandBlueprint(3)
			seaRuin = blueprintController.GetRandomSeaBlueprint(3)
			blueprintTierLevel = 3
		elseif r > 85 and Spring.GetModOptions().ruins_only_t1 == false then
			landRuin = blueprintController.GetRandomLandBlueprint(2)
			seaRuin = blueprintController.GetRandomSeaBlueprint(2)
			blueprintTierLevel = 2
		elseif r > 65 then
			landRuin = blueprintController.GetRandomLandBlueprint(1)
			seaRuin = blueprintController.GetRandomSeaBlueprint(1)
			blueprintTierLevel = 1
		else
			landRuin = blueprintController.GetRandomLandBlueprint(0)
			seaRuin = blueprintController.GetRandomSeaBlueprint(0)
			blueprintTierLevel = 0
		end

		if posy > 0 then
			ruin = landRuin
		elseif posy <= 0 and seaRuinChance == 1 then
			ruin = seaRuin
		end

		if ruin ~= nil then -- Nil check because Lua does not have a "continue" statement
			radius = ruin.radius
			canBuildHere = positionCheckLibrary.VisibilityCheckEnemy(posx, posy, posz, radius, GaiaAllyTeamID, true, true, true)
						and positionCheckLibrary.MapEdgeCheck(posx, posy, posz, radius)
						and positionCheckLibrary.OccupancyCheck(posx, posy, posz, radius)
						and positionCheckLibrary.FlatAreaCheck(posx, posy, posz, radius)

			if posy > 0 then
				canBuildHere = canBuildHere and positionCheckLibrary.SurfaceCheck(posx, posy, posz, radius)
			elseif posy <= 0 then
				canBuildHere = canBuildHere and positionCheckLibrary.SurfaceCheck(posx, posy, posz, radius, true)
			end

			if canBuildHere and getNearestBlocker(posx, posz) < radius*1.5 then
				canBuildHere = false
			end

			if canBuildHere then
				spawnRuin(ruin, posx, posy, posz, blueprintTierLevel)
				break
			end
		end
	end
end
