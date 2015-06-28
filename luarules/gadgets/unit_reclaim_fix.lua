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
local GetFeatureDefID = Spring.GetFeatureDefID
local GetUnitDefID = Spring.GetUnitDefID
local GetFeatureResources = Spring.GetFeatureResources
local GetFeatureResources = Spring.GetFeatureResources
local CMD_RESURRECT = CMD.RESURRECT

-- implement reclaim 

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, step)
  if step > 0 then return true end
  local reclaimspeed = (UnitDefs[GetUnitDefID(builderID)].reclaimSpeed / 30)
  local reclaimtime = FeatureDefs[featureDefID].reclaimTime
  local oldformula = (((100 + reclaimspeed) * 0.02) / math.max(10, reclaimtime))
  local newformula = (reclaimspeed / reclaimtime)
  local resource = math.max(FeatureDefs[featureDefID].metal,FeatureDefs[featureDefID].energy)
  if (resource <= 0) then
    return true
  end
  local newpercent = select(5,GetFeatureResources(featureID)) - ((((resource * oldformula) * 6) - (resource * newformula)) / resource)
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