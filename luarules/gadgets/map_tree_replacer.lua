--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Map Tree Replacer",
		desc      = "",
		author    = "Floris",
		date      = "February 2018",
		license   = "GPL",
		layer     = -1,	--higher layer is loaded last
		enabled   = true,  
	}
end


if (gadgetHandler:IsSyncedCode()) then
	local allTreeTypes = false	-- not finished feature, replaces all features atm

	local currentMapname = Game.mapName:lower()
	local snowKeywords = {'snow','frozen','cold','winter','ice','icy','arctic','frost','melt','glacier','mosh_pit','blindside','northernmountains','amarante'}
	local snowMaps = {}
	-- disable for maps that have a keyword but are not snowmaps
	snowMaps['sacrifice_v1'] = false
	-- disable for maps already containing a snow widget
	snowMaps['xenolithic_v4'] = false
	snowMaps['thecoldplace'] = false

	-- check for keywords
	local snowMap = false
	for _,keyword in pairs(snowKeywords) do
		if string.find(currentMapname, keyword) then
			snowMap = true
			break
		end
	end
	-- check for specific map setting
	if snowMaps[currentMapname] ~= nil then
		if snowMaps[currentMapname] then
			snowMap = true
		else
			snowMap = false
		end
	end

	function gadget:Initialize()

		-- get all replacement trees
		local replacementTrees = {}
		for featureDefID, featureDef in pairs(FeatureDefs) do
			if string.find(featureDef.name, "lowpoly_tree_") then
				if snowMap then
					if string.find(featureDef.name, "lowpoly_tree_snowy") then
						table.insert(replacementTrees, featureDefID)
					end
				else
					if not string.find(featureDef.name, "lowpoly_tree_snowy") then
						table.insert(replacementTrees, featureDefID)
					end
				end
			end
		end

		-- replace tree featuredefs
		if table.getn(replacementTrees) > 0 then
			local featuretable = Spring.GetAllFeatures()
			for i = 1,#featuretable do
				local featureDefID = Spring.GetFeatureDefID(featuretable[i])
				if allTreeTypes or string.find(FeatureDefs[featureDefID].name, "treetype") then
					local x,y,z = Spring.GetFeaturePosition(featuretable[i])
					if Spring.GetGroundHeight(x,z) >= 0 then
						Spring.DestroyFeature(featuretable[i])
						local newFeatureID = Spring.CreateFeature(replacementTrees[math.random(1,table.getn(replacementTrees))], x, Spring.GetGroundHeight(x,z), z)
						Spring.SetFeatureRotation(newFeatureID, 0, math.random(1,360), 0)
					end
				end
			end
		end
	end
end


