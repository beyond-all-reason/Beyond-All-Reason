local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Wrecks to Rubble API",
		desc    = "When destroying a wreck via script, allow transforming it to debris.",
		author  = "efrec",
		date    = "2025",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

local metalMinimum = 6 -- 10 x 60%

local wreckToHeapDefID = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	local wreckDef = FeatureDefNames[unitDef.name .. "_dead"]
	local heapDef = FeatureDefNames[unitDef.name .. "_heap"]

	if wreckDef and heapDef then
		if wreckDef.metal >= metalMinimum and
			heapDef.metal >= metalMinimum
		then
			wreckToHeapDefID[wreckDef.id] = {
				heapDefID    = heapDef.id,
				healthBefore = wreckDef.maxHealth,
				health       = heapDef.maxHealth,
				metal        = heapDef.metal,
				energy       = heapDef.energy,
				time         = heapDef.reclaimTime,
			}
		end
	end
end

local function reduceWreckToHeap(featureID, healthBefore, damageTaken)
	local featureDefID = Spring.GetFeatureDefID(featureID)

	if healthBefore - damageTaken <= 0 and wreckToHeapDefID[featureDefID] then
		local metal, metalMax, _, _, reclaimLeft = Spring.GetFeatureResources(featureID)

		-- More important to clean up tiny debris than to conserve every last granule of metal:
		if metal >= metalMinimum and metalMax >= metalMinimum then
			local heapInfo = wreckToHeapDefID[featureDefID]
			local healthLeft = heapInfo.health + (healthBefore - damageTaken)

			if healthLeft >= 0.5 * heapInfo.health then
				local fx, fy, fz = Spring.GetFeaturePosition(featureID)
				local heading = Spring.GetFeatureHeading(featureID)

				-- The main reason we are here is because this "Destroy" is a Delete:
				Spring.DestroyFeature(featureID)

				local heapID = Spring.CreateFeature(heapInfo.heapDefID, fx, fy, fz, heading)

				if heapID ~= nil then
					local healthPercentage = healthLeft / heapInfo.health

					Spring.SetFeatureHealth(heapID, healthPercentage * heapInfo.health)
					Spring.SetFeatureResources(
						heapID,
						heapInfo.metal * reclaimLeft,
						heapInfo.energy * reclaimLeft,
						heapInfo.time * reclaimLeft,
						reclaimLeft
					)
				end
			end
		end
	end
end

function gadget:Initialize()
	GG.reduceWreckToHeap = reduceWreckToHeap
end

function gadget:Shutdown()
	GG.reduceWreckToHeap = nil
end
