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
    local wreckDefID, heapDefID

    if FeatureDefNames[unitDef.name .. "_dead"] then
        wreckDefID = FeatureDefNames[unitDef.name .. "_dead"].id
    end

    if FeatureDefNames[unitDef.name .. "_heap"] then
        heapDefID = FeatureDefNames[unitDef.name .. "_heap"].id
    end

    if wreckDefID and heapDefID then
        local wreckDef = FeatureDefs[wreckDefID]
        local heapDef = FeatureDefs[heapDefID]

        if wreckDef.metal >= metalMinimum and heapDef.metal >= metalMinimum then
            wreckToHeapDefID[wreckDefID] = {
                heapDefID    = heapDefID,
                healthBefore = wreckDef.damage,
                health       = heapDef.damage,
                metal        = heapDef.metal,
                energy       = heapDef.energy,
                time         = heapDef.reclaimTime,
            }
        end
    end
end

local function reduceWreckageToDebris(featureID, healthBefore, damageTaken)
    local featureDefID = Spring.GetFeatureDefID(featureID)

    if healthBefore - damageTaken <= 0 and wreckToHeapDefID[featureDefID] then
        local metal, metalMax, _, _, reclaimLeft = Spring.GetFeatureResources(featureID)

        if metal >= metalMinimum and metalMax >= metalMinimum then
            local heapInfo = wreckToHeapDefID[featureDefID]
            local healthLeft = heapInfo.health + healthBefore - damageTaken

            if healthLeft >= 0.5 * heapInfo.health then
                local heapID = Spring.CreateFeature(heapInfo.heapDefID, Spring.GetFeaturePosition(featureID))

                -- The main reason we are here is because this "Destroy" is a Delete:
                Spring.DestroyFeature(featureID)

                if heapID then
                    local healthPercentage = healthLeft / heapInfo.health

                    Spring.SetFeatureHealth(heapID, healthPercentage * heapInfo.health)
                    Spring.SetFeatureResources(heapID,
                        heapInfo.metal * reclaimLeft,
                        heapInfo.energy * reclaimLeft,
                        heapInfo.time * reclaimLeft,
                        reclaimLeft)
                end
            end
        end
    end
end

function gadget:Initialize()
    GG.reduceWreckToHeap = reduceWreckageToDebris
end

function gadget:Shutdown()
    GG.reduceWreckToHeap = nil
end
