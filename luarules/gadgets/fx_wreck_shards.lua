function gadget:GetInfo()
  return {
    name      = "fx_wreck_shards",
    desc      = "fx_wreck_shards",
    author    = "TheFatController",
    date      = "10 Oct 2013",
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

local GetFeaturePosition = Spring.GetFeaturePosition
local SpawnCEG = Spring.SpawnCEG
local random = math.random

local cegs = {}
cegs[1] = "wreckshards1"
cegs[2] = "wreckshards2"
cegs[3] = "wreckshards3"
local featureList = {}
local cegList = {}

for featureDefID, defs in pairs(FeatureDefs) do
  if string.find(defs.tooltip, 'Wreckage') or string.find(defs.tooltip, 'Shards') or string.find(defs.tooltip, 'Rubble') or string.find(defs.tooltip, 'Heap') then
    featureList[featureDefID] = -1
  end
end

function gadget:FeatureDamaged(featureID, featureDefID, featureTeam, damage, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if not cegList[featureID] and (damage > 5) then
		local featureDefs = featureList[featureDefID] or nil
		if featureDefs then
			if (featureDefs == -1) then
				local defs = FeatureDefs[featureDefID]
				featureList[featureDefID] = {
					minX = (defs.minx * 0.6), 
					maxX = (defs.maxx * 0.6), 
					minZ = (defs.minz * 0.6), 
					maxZ = (defs.maxz * 0.6), 
					y = (defs.maxy * 0.5)
				}
				featureDefs = featureList[featureDefID]
			end
			local x,y,z = GetFeaturePosition(featureID)
			x = x + random(featureDefs.minX,featureDefs.maxX)
			z = z + random(featureDefs.minZ,featureDefs.maxZ)
			y = y + (random() * featureDefs.y)
			cegList[featureID] = {ceg = cegs[random(1,3)],x=x,y=y,z=z, enabled = true}
		end
	end
end

function gadget:GameFrame(n)
	for i,v in pairs(cegList) do
		if v.enabled then
			SpawnCEG(v.ceg,v.x,v.y,v.z,0,1.0,0,0,0)
			cegList[i].enabled = false
		end
	end
	if (n % 15 == 0) then
		cegList = {}
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------