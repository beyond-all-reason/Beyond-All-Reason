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
local processedFeatures = {} -- Track features we've already processed to avoid redundant work

for featureDefID, featureDef in pairs(FeatureDefs) do
	if featureDef.customParams.fromunit and featureDef.model and featureDef.model.maxx then
		local minX = math.max(math.floor(featureDef.model.minx * 0.66), -500) -- capping values to prevent and error on too large interval in math.random() param #2
		local maxX = math.min(math.floor(featureDef.model.maxx * 0.66), 500)
		local minZ = math.max(math.floor(featureDef.model.minz * 0.66), -500)
		local maxZ = math.min(math.floor(featureDef.model.maxz * 0.66), 500)

		if minX ~= maxX and minZ ~= maxZ then
			featureList[featureDefID] = {
				minX = minX,
				maxX = maxX,
				minZ = minZ,
				maxZ = maxZ,
				y = math.floor(featureDef.model.maxy * 0.66),
				rangeX = maxX - minX, -- Pre-calculate range to avoid subtraction in hot path
				rangeZ = maxZ - minZ
			}
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
	local params = featureList[featureDefID]
	if params then
		-- Cache position on first call to avoid repeated GetFeaturePosition calls
		if not processedFeatures[featureID] then
			local x, y, z = GetFeaturePosition(featureID)
			processedFeatures[featureID] = {
				x = x,
				y = y + params.y,
				z = z,
				params = params
			}
		end

		-- Spawn CEG every step, but use cached position data
		local cached = processedFeatures[featureID]
		local x = cached.x + cached.params.minX + (cached.params.rangeX * random())
		local z = cached.z + cached.params.minZ + (cached.params.rangeZ * random())
		cegList[featureID] = { ceg = cegs[random(1, #cegs)], x = x, y = cached.y, z = z }
	end
	return true
end

function gadget:FeatureDestroyed(featureID)
	processedFeatures[featureID] = nil
	cegList[featureID] = nil
end
