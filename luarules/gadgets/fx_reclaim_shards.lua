local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "fx_reclaim_shards",
		desc = "fx_reclaim_shards",
		author = "TheFatController",
		date = "13 Feb 2008",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local GetFeaturePosition = Spring.GetFeaturePosition
local SpawnCEG = Spring.SpawnCEG
local random = math.random

local cegs = { "reclaimshards1", "reclaimshards2", "reclaimshards3" }
local featureList = {}
local cegList = {}

for featureDefID, featureDef in pairs(FeatureDefs) do
	if featureDef.customParams.fromunit and featureDef.model and featureDef.model.maxx then
		featureList[featureDefID] = {
			minX = math.max(math.floor(featureDef.model.minx * 0.66), -500),	-- capping values to prevent and error on too large interval in math.random() param #2
			maxX = math.min(math.floor(featureDef.model.maxx * 0.66), 500),
			minZ = math.max(math.floor(featureDef.model.minz * 0.66), -500),
			maxZ = math.min(math.floor(featureDef.model.maxz * 0.66), 500),
			y = math.floor(featureDef.model.maxy * 0.66)
		}
		if featureList[featureDefID].minX == featureList[featureDefID].maxX or featureList[featureDefID].minZ == featureList[featureDefID].maxZ  then
			featureList[featureDefID] = nil
		end
	end
end

function gadget:GameFrame(n)
	if n % 2 == 0 then
		for featureID, v in pairs(cegList) do
			SpawnCEG(v.ceg, v.x, v.y, v.z, 0, 1.0, 0, 0, 0)
			cegList[featureID] = nil
		end
	end
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	if not cegList[featureID] then
		local params = featureList[featureDefID] or nil
		if params then
			local x, y, z = GetFeaturePosition(featureID)
			x = x + params.minX + ((-params.minX + params.maxX) * random())
			z = z + params.minZ + ((-params.minZ + params.maxZ) * random())
			y = y + params.y
			cegList[featureID] = { ceg = cegs[random(1, #cegs)], x = x, y = y, z = z }
		end
	end
	return true
end
