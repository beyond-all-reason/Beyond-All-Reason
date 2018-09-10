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
		local count = 0
		for featureDefID, featureDef in pairs(FeatureDefs) do
			if string.find(featureDef.name, "lowpoly_tree_") and not string.find(featureDef.name, "burnt") then
				if snowMap then
					if string.find(featureDef.name, "lowpoly_tree_snowy") then
						count = count + 1
						replacementTrees[count] = featureDefID
					end
				else
					if not string.find(featureDef.name, "lowpoly_tree_snowy") then
						count = count + 1
						replacementTrees[count] = featureDefID
					end
				end
			end
		end

		-- replace tree featuredefs
		if count > 0 then
			local featuretable = Spring.GetAllFeatures()
			for i = 1,#featuretable do
				local featureDefID = Spring.GetFeatureDefID(featuretable[i])
				if allTreeTypes or FeatureDefs[featureDefID].name:sub(1,8) == 'treetype' then
					local x,y,z = Spring.GetFeaturePosition(featuretable[i])
					if Spring.GetGroundHeight(x,z) >= 0 then
						Spring.DestroyFeature(featuretable[i])
						local newFeatureID = Spring.CreateFeature(replacementTrees[math.random(1,count)], x, Spring.GetGroundHeight(x,z), z)
						Spring.SetFeatureRotation(newFeatureID, 0, math.random(1,360), 0)
						Spring.SetFeatureBlocking(newFeatureID, true, true, true, true, true, false, false)
					end
				end
			end
		end
	end
--else
--
--	function gadget:GameFrame(gf)
--		 if gf%30 == 1 then
--				Spring.Echo('-------------------------')
--				for i, def in pairs(FeatureDefs) do
--					if def.name:sub(1,8) == 'treetype' then
--						Spring.Echo(def.name..':')
--						for name,param in def:pairs() do
--							Spring.Echo(name,param)
--							if name == 'collisionVolume' then
--								for k,v in pairs(param) do
--									if type(v) == 'number' or type(v) == 'string' or type(v) == 'boolean' then
--									Spring.Echo('  '..k..',  '..tostring(v))
--									else
--									Spring.Echo('  '..k..'  '..type(v))
--									end
--								end
--							end
--						end
--						break
--					end
--				end
--				Spring.Echo('---------------------------')
--
--		 end
--	end
end

