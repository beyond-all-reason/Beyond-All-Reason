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
local featureList = {} ---@type table<number, {minX:number, maxX:number, minZ:number, maxZ:number, y:number, rangeX:number, rangeZ:number}>
local processedX = {}
local processedY = {}
local processedZ = {}

-- Pending CEG queue indexed by featureID. A separate featureID list avoids per-step table allocations.
local pendingFeatureIDs = {} ---@type integer[]
local pendingCount = 0
local pendingMarked = {} ---@type table<integer, boolean>
local pendingCEG = {} ---@type table<number, string>
local pendingX = {} ---@type table<integer, number>
local pendingY = {} ---@type table<integer, number>
local pendingZ = {} ---@type table<integer, number>

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
	if n % 2 == 0 and pendingCount > 0 then
		for i = 1, pendingCount do
			local featureID = pendingFeatureIDs[i]
			if featureID then
				SpawnCEG(pendingCEG[featureID], pendingX[featureID], pendingY[featureID], pendingZ[featureID], 0, 1.0, 0, 0, 0)
				pendingMarked[featureID] = nil
				pendingCEG[featureID] = nil
				pendingX[featureID] = nil
				pendingY[featureID] = nil
				pendingZ[featureID] = nil
			end
			pendingFeatureIDs[i] = nil
		end
		pendingCount = 0
	end
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	local params = featureList[featureDefID]
	if params == nil then
		return true
	end

	-- Cache position on first call to avoid repeated GetFeaturePosition calls
	if not processedX[featureID] then
		local x, y, z = GetFeaturePosition(featureID)
		if not x or not y or not z then
			return true
		end
		processedX[featureID] = x
		processedY[featureID] = y + params.y
		processedZ[featureID] = z
	end

	-- Queue one CEG per feature per processing window using cached position data.
	if not pendingMarked[featureID] then
		pendingCount = pendingCount + 1
		pendingFeatureIDs[pendingCount] = featureID
		pendingMarked[featureID] = true
	end

	pendingCEG[featureID] = cegs[random(1, #cegs)]
	pendingX[featureID] = processedX[featureID] + params.minX + (params.rangeX * random())
	pendingY[featureID] = processedY[featureID]
	pendingZ[featureID] = processedZ[featureID] + params.minZ + (params.rangeZ * random())
	return true
end

function gadget:FeatureDestroyed(featureID)
	processedX[featureID] = nil
	processedY[featureID] = nil
	processedZ[featureID] = nil
	-- Keep queued CEG payload until GameFrame drain to avoid nil SpawnCEG args.
	-- The queue is short-lived (drained every other frame), so this is safe.
end
