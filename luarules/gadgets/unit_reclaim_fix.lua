--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Reclaim Fix",
    desc      = "Implements Old Style Reclaim.",
    author    = "TheFatController", -- lots of help from Lurker
    date      = "May 24th, 2009",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return
end

local SetFeatureReclaim = Spring.SetFeatureReclaim
local GetFeaturePosition = Spring.GetFeaturePosition
local GetUnitDefID = Spring.GetUnitDefID
local GetFeatureResources = Spring.GetFeatureResources


local unitList = {}
for unitDefID, defs in pairs(UnitDefs) do
    if defs.reclaimSpeed > 0 then
        unitList[unitDefID] = defs.reclaimSpeed / 30
    end
end

local featureList = {}
for featureDefID, fdefs in pairs(FeatureDefs) do
    local maxResource = math.max(fdefs.metal, fdefs.energy)
    if (maxResource > 0) then
        featureList[featureDefID] = {}
        for unitDefID, reclaimSpeed in pairs(unitList) do
            local oldformula = ((reclaimSpeed*0.70 + 10*0.30)*1.5  / fdefs.reclaimTime)
            local newformula = (reclaimSpeed  / fdefs.reclaimTime)
            featureList[featureDefID][unitDefID] = ((((maxResource * oldformula) * 1) - (maxResource * newformula)) / maxResource)
        end
    end
end
unitList = nil


function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, step)
    if step > 0 or featureList[featureDefID] == nil then
        return true
    end
    local unitDefID = GetUnitDefID(builderID)
    if featureList[featureDefID][unitDefID] == nil then
        return true
    end
    local newpercent = select(5,GetFeatureResources(featureID)) - featureList[featureDefID][unitDefID]
    SetFeatureReclaim(featureID, newpercent)
    return true
end


-- when a wreck dies and becomes a heap, we need to set the reclaim % of the heap to be equal to its 'parent' wreck
-- order of callins below: featurecreated (for heap), feature destroyed (for wreck), gameframe
-- two features should not be able to occupy the same pos on the same frame 
-- so; keep track of features created on that frame, then when a feature dies in coord matching the feature created, transfer reclaim % onto it
-- no need to transfer rez % since heaps are not rezzable
local featuresCreatedThisFrame = {}

function gadget:FeatureCreated(featureID, allyTeamID)
	--record feature creation
	--Spring.Echo("created:",featureID)
	featuresCreatedThisFrame[#featuresCreatedThisFrame+1] = featureID
end

function gadget:FeatureDestroyed(featureID, allyTeamID)
	local bpx,bpy,bpz = GetFeaturePosition(featureID)
	local _,_,_,_, reclaimLeft = GetFeatureResources(featureID)
	--Spring.Echo("died:", featureID, bpx,bpy,bpz,reclaimLeft, heap)

	--seek out heap, if one exists
	local replaceFID
	for i=1,#featuresCreatedThisFrame do 
		local nbpx, nbpy, nbpz = GetFeaturePosition(featuresCreatedThisFrame[i])
		--Spring.Echo("possible", featuresCreatedThisFrame[i], bpx,bpy,bpz,nbpx,nbpy,nbpz)
		if bpx==nbpx and bpy==nbpy and bpz==nbpz then --floating point errors
			replaceFID = featuresCreatedThisFrame[i]
		end
	end
	
	--set heap reclaim %
	if replaceFID and reclaimLeft then
		--Spring.Echo("set:", replaceFID, reclaimLeft)
		SetFeatureReclaim(replaceFID, reclaimLeft)
	end
	
end

function gadget:GameFrame()
	--flush featuresCreatedThisFrame
	if featuresCreatedThisFrame then
		for i=1,#featuresCreatedThisFrame do
			--Spring.Echo("removed",i,featuresCreatedThisFrame[i])
			featuresCreatedThisFrame[i] = nil
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------