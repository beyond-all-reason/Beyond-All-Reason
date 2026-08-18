local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "fx_reclaim_shards",
		desc = "fx_reclaim_shards",
		author = "TheFatController",
		date = "13 Feb 2008",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local GetFeatureDefID = Spring.GetFeatureDefID
local GetFeaturePosition = Spring.GetFeaturePosition
local SpawnCEG = Spring.SpawnCEG
local random = math.random

local cegs = { "reclaimshards1", "reclaimshards2", "reclaimshards3" }
local featureList = {} ---@type table<number, {minX:number, maxX:number, minZ:number, maxZ:number, y:number, rangeX:number, rangeZ:number}>
local featureParams = {}
local positions = {}
local positionPool = {}
local poolSize = 0
local gameFrame = 0

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
				rangeZ = maxZ - minZ,
			}
		end
	end
end

function gadget:GameFrame(frame)
	gameFrame = frame
end

function gadget:FeatureBuildStepTotal(featureID, part)
	if gameFrame % 2 == 0 then
		return
	end

	local params = part < 0 and featureParams[featureID]
	if not params then
		return
	end

	local position = positions[featureID]
	if not position then
		local x, y, z = GetFeaturePosition(featureID)
		if x then
			if poolSize > 0 then
				position = positionPool[poolSize]
				poolSize = poolSize - 1
			else
				position = {}
			end
			position[1], position[2], position[3] = x, y + params.y, z
			positions[featureID] = position
		end
	end
	if position then
		SpawnCEG(
			cegs[random(1, #cegs)],
			position[1] + params.minX + (params.rangeX * random()),
			position[2],
			position[3] + params.minZ + (params.rangeZ * random()),
			0,
			1.0,
			0,
			0,
			0
		)
	end
end

function gadget:FeatureCreated(featureID, allyTeamID)
	featureParams[featureID] = featureList[GetFeatureDefID(featureID)] or nil
end

function gadget:FeatureDestroyed(featureID)
	local position = positions[featureID]
	if position then
		poolSize = poolSize + 1
		positionPool[poolSize] = position
		positions[featureID] = nil
	end
	featureParams[featureID] = nil
end

function gadget:Initialize()
	for _, featureID in ipairs(Spring.GetAllFeatures()) do
		gadget:FeatureCreated(featureID)
	end
end
