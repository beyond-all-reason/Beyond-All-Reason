-- these are used in poschecks.lua so arent localized here
mapsizeX = Game.mapSizeX
mapsizeZ = Game.mapSizeZ
GaiaTeamID = Spring.GetGaiaTeamID()
GaiaAllyTeamID = select(6, Spring.GetTeamInfo(GaiaTeamID))

local scavengersAIEnabled = Spring.Utilities.Gametype.IsScavengers()

local ruinSpawnEnabled = false
if (Spring.GetModOptions and (Spring.GetModOptions().ruins or "disabled") == "enabled") or (Spring.GetModOptions and (Spring.GetModOptions().scavonlyruins or "enabled") == "enabled" and scavengersAIEnabled) then
	ruinSpawnEnabled = true
end

function gadget:GetInfo()
    return {
      name      = "ruin spawn",
      desc      = "123",
      author    = "Damgam",
      date      = "2020",
      layer     = -100,
      enabled   = ruinSpawnEnabled,
    }
end

VFS.Include('luarules/gadgets/scavengers/API/init.lua')
VFS.Include('luarules/gadgets/scavengers/API/api.lua')
VFS.Include('luarules/gadgets/scavengers/API/poschecks.lua')
local blueprintController = VFS.Include('luarules/gadgets/scavengers/Blueprints/BYAR/blueprint_controller.lua')

local spawnCutoffFrame = (math.ceil( math.ceil(mapsizeX + mapsizeZ) / 750 ) + 30) * 3

local function spawnRuin(ruin, posx, posy, posz)
	for _, building in ipairs(ruin.buildings) do
		local name = UnitDefs[building.unitDefID].name
		local r = math.random(1,100)
		if r < 20 then
			local unit = Spring.CreateUnit(building.unitDefID, posx + building.xOffset, posy, posz + building.zOffset, building.direction, GaiaTeamID)
			local radarRange = UnitDefs[building.unitDefID].radarRadius
			local canMove = UnitDefs[building.unitDefID].canMove
			local speed = UnitDefs[building.unitDefID].speed

			Spring.SetUnitNeutral(unit, true)
			Spring.GiveOrderToUnit(unit, CMD.FIRE_STATE, {1}, 0)
			Spring.GiveOrderToUnit(unit, CMD.MOVE_STATE, {0}, 0)
			Spring.SetUnitAlwaysVisible(unit, true)

			if building.patrol and canMove and speed > 0 then
				for i = 1, 6 do
					Spring.GiveOrderToUnit(unit, CMD.PATROL, { posx + (math.random(-200, 200)), posy + 100, posz + (math.random(-200, 200)) }, {"shift", "alt", "ctrl"})
				end
			end

			if radarRange and radarRange > 1000 then
				Spring.GiveOrderToUnit(unit, CMD.ONOFF, {0}, 0)
			end
		elseif r < 90 and FeatureDefNames[name .. "_dead"] then
			local wreck = Spring.CreateFeature(name .. "_dead", posx + building.xOffset, posy, posz + building.zOffset, building.direction, GaiaTeamID)
			Spring.SetFeatureAlwaysVisible(wreck, true)
			Spring.SetFeatureResurrect(wreck, name)
		end
	end
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:GameFrame(n)
	if n < 30 or n%5 ~= 0 or n > spawnCutoffFrame then
		return
	end

	for i = 1, 100 do
		local landRuin, seaRuin, ruin
		local posx = math.random(0, Game.mapSizeX)
		local posz = math.random(0, Game.mapSizeZ)
		local posy = Spring.GetGroundHeight(posx, posz)
		local seaRuinChance = math.random(1, 2)
		local radius, canBuildHere

		landRuin = blueprintController.Ruin.GetRandomLandBlueprint()
		seaRuin = blueprintController.Ruin.GetRandomSeaBlueprint()

		if posy > 0 then
			ruin = landRuin
		elseif posy <= 0 and seaRuinChance == 1 then
			ruin = seaRuin
		end

		if ruin ~= nil then -- Nil check because Lua does not have a "continue" statement
			radius = ruin.radius
			canBuildHere = posLosCheck(posx, posy, posz, radius)
						and posMapsizeCheck(posx, posy, posz, radius)
						and posOccupied(posx, posy, posz, radius)
						and posCheck(posx, posy, posz, radius)

			if posy > 0 then
				canBuildHere = canBuildHere and posLandCheck(posx, posy, posz, radius)
			elseif posy <= 0 then
				canBuildHere = canBuildHere and posSeaCheck(posx, posy, posz, radius)
			end

			if canBuildHere then
				spawnRuin(ruin, posx, posy, posz)
				break
			end
		end
	end
end
