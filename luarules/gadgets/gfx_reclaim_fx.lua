   function gadget:GetInfo()
      return {
        name      = "Reclaim effect",
        desc      = "Nice unit reclaim effect",
        author    = "Floris",
        date      = "December 2016",
        license   = "PD",
        layer     = 0,
        enabled   = true,
      }
    end
     
if (not gadgetHandler:IsSyncedCode()) then
  return
end

local random = math.random

local ignoreUnits = {}
if UnitDefNames["chip"] ~= nil then
	ignoreUnits[UnitDefNames["chip"].id] = true
	ignoreUnits[UnitDefNames["dice"].id] = true
	ignoreUnits[UnitDefNames["xmasball"].id] = true
	ignoreUnits[UnitDefNames["armstone"].id] = true
	ignoreUnits[UnitDefNames["corstone"].id] = true
end


function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if attackerID == nil and ignoreUnits[unitDefID] == nil then -- if reclaimed
		local ux,uy,uz = Spring.GetUnitPosition(unitID)
		if ux ~= nil then
			local udef = UnitDefs[unitDefID]
			local x,y,z = ux,uy,uz
			Spring.SpawnCEG("metalshards1", x, y, z)
			
			-- add more effects depending on unit cost
			local numFx = math.floor(UnitDefs[unitDefID].metalCost/170)
			local posMultiplier = 0.5
			for i=1, numFx, 1 do
				x = ux + (random(udef.model.minx, udef.model.maxx)*posMultiplier)
				z = uz + (random(udef.model.minz, udef.model.maxz)*posMultiplier)
				y = uy + (random() * udef.model.maxy*posMultiplier)
				Spring.SpawnCEG("metalshards"..(((i+1)%3)+1), x, y, z)
			end
		end
	end
end

local damagedFeatures = {}
function gadget:FeatureDamaged(featureID, featureDefID, featureTeam, damage, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if damage > 1 and (damagedFeatures[featureID] == nil or Spring.GetGameFrame() - damagedFeatures[featureID] > 15) then
		local fx,fy,fz = Spring.GetFeaturePosition(featureID)
		if (fx ~= nil) then
			local x,y,z = fx,fy,fz
			local rm, mm, re, me, rl = Spring.GetFeatureResources(featureID)
			if me ~= nil and me > 0 then
				local fdef = FeatureDefs[featureDefID]
				local numFx = math.floor(me/200)
				local posMultiplier = 0.5
				Spring.SpawnCEG("energyshards1", x, y, z)
				for i=1, numFx, 1 do
					x = fx + (random(fdef.model.minx, fdef.model.maxx)*posMultiplier)
					z = fz + (random(fdef.model.minz, fdef.model.maxz)*posMultiplier)
					y = fy + (random() * fdef.model.maxy*posMultiplier)
					Spring.SpawnCEG("energyshards"..(((i+1)%3)+1), x, y, z)
				end
				--Spring.Echo(numFxE..'  '..FeatureDefs[featureDefID].energy)
			end
			if mm ~= nil and mm > 0 then
				local fdef = FeatureDefs[featureDefID]
				local numFx = math.floor(mm/75)
				local posMultiplier = 0.5
				Spring.SpawnCEG("metalshards1", x, y, z)
				for i=1, numFx, 1 do
					x = fx + (random(fdef.model.minx, fdef.model.maxx)*posMultiplier)
					z = fz + (random(fdef.model.minz, fdef.model.maxz)*posMultiplier)
					y = fy + (random() * fdef.model.maxy*posMultiplier)
					Spring.SpawnCEG("metalshards"..(((i+1)%3)+1), x, y, z)
				end
				--Spring.Echo(numFxE..'  '..FeatureDefs[featureDefID].energy)
			end
		end
		damagedFeatures[featureID] = Spring.GetGameFrame()
	end
end

function gadget:FeatureDestroyed(featureID, allyteam)
	if damagedFeatures[featureID] ~= nil then
		damagedFeatures[featureID] = nil
	end
	local fx,fy,fz = Spring.GetFeaturePosition(featureID)
	if (fx ~= nil) then
		local x,y,z = fx,fy,fz
		--local featureDefID = Spring.GetFeatureDefID(featureID)
		local rm, mm, re, me, rl = Spring.GetFeatureResources(featureID)
			
		if me ~= nil and me > 0 then
			local fdef = FeatureDefs[Spring.GetFeatureDefID(featureID)]
			local numFx = math.floor(me/200)
			local posMultiplier = 0.5
			Spring.SpawnCEG("energyshards1", x, y, z)
			for i=1, numFx, 1 do
				x = fx + (random(fdef.model.minx, fdef.model.maxx)*posMultiplier)
				z = fz + (random(fdef.model.minz, fdef.model.maxz)*posMultiplier)
				y = fy + (random(fdef.model.miny, fdef.model.maxy)*posMultiplier)
				Spring.SpawnCEG("energyshards"..(((i+1)%3)+1), x, y, z)
			end
			--Spring.Echo(numFxE..'  '..FeatureDefs[featureDefID].energy)
		end
		if mm ~= nil and mm > 0 then
			local fdef = FeatureDefs[Spring.GetFeatureDefID(featureID)]
			local numFx = math.floor(mm/75)
			local posMultiplier = 0.5
			Spring.SpawnCEG("metalshards1", x, y, z)
			for i=1, numFx, 1 do
				x = fx + (random(fdef.model.minx, fdef.model.maxx)*posMultiplier)
				z = fz + (random(fdef.model.minz, fdef.model.maxz)*posMultiplier)
				y = fy + (random(fdef.model.miny, fdef.model.maxy)*posMultiplier)
				Spring.SpawnCEG("metalshards"..(((i+1)%3)+1), x, y, z)
			end
			--Spring.Echo(numFxE..'  '..FeatureDefs[featureDefID].energy)
		end
		
		if (rm ~= nil) then
			if mm==0 and re == 0 then
				Spring.SpawnCEG("sparklegreen", fx, fy, fz)
				Spring.PlaySoundFile("sounds/reclaimate.wav", 1, fx, fy, fz, 'sfx')
			end
		end
	end
end