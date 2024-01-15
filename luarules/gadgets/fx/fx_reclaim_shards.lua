function gadget:GetInfo()
	return {
		name = "fx_reclaim_shards",
		desc = "fx_reclaim_shards",
		author = "TheFatController",
		date = "13 Feb 2008",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true  --  loaded by default?
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local GetFeaturePosition = Spring.GetFeaturePosition
local SpawnCEG = Spring.SpawnCEG
local random = math.random

local cegs = {"reclaimshards1", "reclaimshards2", "reclaimshards3"}
local featureList = {}
local cegList = {}

for featureDefID, featureDef in pairs(FeatureDefs) do
	if featureDef.customParams.fromunit then
		featureList[featureDefID] = -1
	end
end

function gadget:GameFrame(n)
	if n % 2 == 0 then
		for featureID, v in pairs(cegList) do
			SpawnCEG(v.ceg, v.xs, v.ys, v.zs, 0, 1.0, 0, 0, 0)
			cegList[featureID] = nil
		end
	end
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	if not cegList[featureID] then
		local featureDefs = featureList[featureDefID] or nil
		if featureDefs then
			if featureDefs == -1 then
				local defs = FeatureDefs[featureDefID]
				featureList[featureDefID] = { minX = (defs.model.minx * 0.6), maxX = (defs.model.maxx + 1 * 0.6), minZ = (defs.model.minz * 0.6), maxZ = (defs.model.maxz + 1 * 0.6), y = (defs.model.maxy + 1 * 0.5) }
				featureDefs = featureList[featureDefID]
			end
			if featureDefs.minX and featureDefs.maxX then
				local x, y, z = GetFeaturePosition(featureID)
				x = x + random(featureDefs.minX, featureDefs.maxX)
				z = z + random(featureDefs.minZ, featureDefs.maxZ)
				y = y + featureDefs.y
				cegList[featureID] = { ceg = cegs[random(1, 3)], xs = x, ys = y, zs = z }
			end
		end
	end
	return true
end
