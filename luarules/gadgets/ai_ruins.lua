
if not (Spring.GetModOptions().ruins == "enabled" or (Spring.GetModOptions().ruins == "scav_only" and Spring.Utilities.Gametype.IsScavengers())) then
	return
end

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
	ruinDensityMultiplier = 0.1
elseif ruinDensity == "rare" then
	ruinDensityMultiplier = 0.5
elseif ruinDensity == "normal" then
	ruinDensityMultiplier = 1
elseif ruinDensity == "dense" then
	ruinDensityMultiplier = 2
elseif ruinDensity == "verydense" then
	ruinDensityMultiplier = 10
end

math_random = math.random	-- not a local cause the includes below use it

local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")
local blueprintController = VFS.Include('luarules/gadgets/scavengers/Blueprints/BYAR/blueprint_controller.lua')

local spawnCutoffFrame = (math.ceil( math.ceil(mapsizeX*mapsizeZ) / 1000000 )) * 3

local landMexesList = {
	--"armmex",
	--"cormex",
	--"armamex_scav",
	--"corexp",
	"armmoho",
	"armshockwave",
	"cormoho",
	"cormexp",
}
local seaMexesList = {
	--"armmex",
	--"cormex",
	--"armuwmex",
	--"coruwmex",
	"armuwmme",
	"coruwmme",
}

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
					Spring.SpawnCEG("scav-spawnexplo", posx + (xOffset*flipX*mirrorX), posy, posz + (zOffset*flipZ*mirrorZ), 0,0,0)
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

local function SpawnMexes(mexSpots)
	for i = 1,#mexSpots do
		if math.random(0,3) == 0 then
			local spot = mexSpots[i]
			local posx = spot.x
			local posz = spot.z
			local posy = Spring.GetGroundHeight(posx, posz)
			local mexesList
			if posy > 0 then
				mexesList = landMexesList
			else
				mexesList = seaMexesList
			end

			local radius = 64
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
				Spring.SpawnCEG("scav-spawnexplo", posx, posy, posz, 0,0,0)
				Spring.SetUnitNeutral(unit, true)
				Spring.GiveOrderToUnit(unit, CMD.FIRE_STATE, {1}, 0)
				Spring.GiveOrderToUnit(unit, CMD.MOVE_STATE, {0}, 0)
			end
		end
	end
end

function gadget:GameFrame(n)
	if n == 301 then
		local mexSpots = GG["resource_spot_finder"] and GG["resource_spot_finder"].metalSpotsList or nil
		if mexSpots and #mexSpots > 5 then
			SpawnMexes(mexSpots)
		end
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
			landRuin = blueprintController.Constructor.GetRandomLandBlueprint(4)
			seaRuin = blueprintController.Constructor.GetRandomSeaBlueprint(4)
			blueprintTierLevel = 4
		elseif r > 95 and Spring.GetModOptions().ruins_only_t1 == false then
			landRuin = blueprintController.Constructor.GetRandomLandBlueprint(3)
			seaRuin = blueprintController.Constructor.GetRandomSeaBlueprint(3)
			blueprintTierLevel = 3
		elseif r > 85 and Spring.GetModOptions().ruins_only_t1 == false then
			landRuin = blueprintController.Constructor.GetRandomLandBlueprint(2)
			seaRuin = blueprintController.Constructor.GetRandomSeaBlueprint(2)
			blueprintTierLevel = 2
		elseif r > 65 then
			landRuin = blueprintController.Constructor.GetRandomLandBlueprint(1)
			seaRuin = blueprintController.Constructor.GetRandomSeaBlueprint(1)
			blueprintTierLevel = 1
		else
			landRuin = blueprintController.Constructor.GetRandomLandBlueprint(0)
			seaRuin = blueprintController.Constructor.GetRandomSeaBlueprint(0)
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

			if canBuildHere then
				spawnRuin(ruin, posx, posy, posz, blueprintTierLevel)
				break
			end
		end
	end
end
