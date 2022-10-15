
Spring.Echo("[Scavengers] Building spawner initialized")

local blueprintConfig = VFS.Include('luarules/gadgets/scavengers/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local blueprintsController = VFS.Include('luarules/gadgets/scavengers/Blueprints/' .. Game.gameShortName .. '/blueprint_controller.lua')

function SpawnBlueprint(n)
	if scavengerGamePhase ~= "initial" then
		return
	end

	local spawnchance = math.random(0, scavconfig.buildingSpawnerModuleConfig.spawnchance)

	if spawnchance == 0 then
		local landBlueprint, seaBlueprint, blueprint
		local spawnTierChance = math.random(1, 100)
		local spawnTier

		if spawnTierChance <= TierSpawnChances.T0 then
			spawnTier = blueprintConfig.Tiers.T0
		elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 then
			spawnTier = blueprintConfig.Tiers.T1
		elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
			spawnTier = blueprintConfig.Tiers.T2
		elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
			spawnTier = blueprintConfig.Tiers.T3
		elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
			spawnTier = blueprintConfig.Tiers.T4
		else
			spawnTier = blueprintConfig.Tiers.T0
		end

		landBlueprint = blueprintsController.Spawner.GetRandomLandBlueprint(spawnTier)
		seaBlueprint = blueprintsController.Spawner.GetRandomSeaBlueprint(spawnTier)

		for i = 1, 50 do
			local posx = math.random(200, Game.mapSizeX - 200)
			local posz = math.random(200, Game.mapSizeZ - 200)
			local posy = Spring.GetGroundHeight(posx, posz)

			if posy > 0 then
				blueprint = landBlueprint
			else
				blueprint = seaBlueprint
			end

			local radius = blueprint.radius
			local canBuildHere = positionCheckLibrary.VisibilityCheckEnemy(posx, posy, posz, radius, ScavengerAllyTeamID, true, true, true)
						and positionCheckLibrary.OccupancyCheck(posx, posy, posz, radius)
						and	positionCheckLibrary.FlatAreaCheck(posx, posy, posz, radius)


			if canBuildHere then
				for _, building in ipairs(blueprint.buildings) do
					Spring.CreateUnit( building.unitDefID, posx + building.xOffset, posy, posz + building.zOffset, building.direction, ScavengerTeamID, false, false)
				end

				-- Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, posx + radius, posy, posz, math.random(0, 3), ScavengerTeamID)
				-- Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, posx - radius, posy, posz, math.random(0, 3), ScavengerTeamID)
				-- Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, posx, posy, posz + radius, math.random(0, 3), ScavengerTeamID)
				-- Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, posx, posy, posz - radius, math.random(0, 3), ScavengerTeamID)
				-- Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, posx + radius, posy, posz + radius, math.random(0, 3), ScavengerTeamID)
				-- Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, posx - radius, posy, posz + radius, math.random(0, 3), ScavengerTeamID)
				-- Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, posx - radius, posy, posz - radius, math.random(0, 3), ScavengerTeamID)
				-- Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, posx + radius, posy, posz - radius, math.random(0, 3), ScavengerTeamID)
				break
			end
		end
	end
end