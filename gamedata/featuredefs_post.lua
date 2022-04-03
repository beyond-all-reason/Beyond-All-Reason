--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    featuredefs_post.lua
--  brief:   featureDef post processing
--  author:  Dave Rodgers
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Per-unitDef featureDefs
--
local mapFeatureProxies = VFS.Include('gamedata/map_feature_i18n_proxies.lua')

local function processUnitDef(unitDefName, unitDef)
	local features = unitDef.featuredefs
	if not features then
		return
	end

	-- add this unitDef's featureDefs
	for featureDefName, featureDef in pairs(features) do
		local fullName = unitDefName .. '_' .. featureDefName
		FeatureDefs[fullName] = featureDef
		featureDef.customparams = featureDef.customparams or {}
		featureDef.customparams.fromunit = unitDefName
		featureDef.customparams.category = featureDef.category
	end

	-- FeatureDead name changes
	for featureDefName, featureDef in pairs(features) do
		if featureDef.featuredead then
			local fullName = unitDefName .. '_' .. featureDef.featuredead:lower()
			if (FeatureDefs[fullName]) then
				featureDef.featuredead = fullName
			end
		end
	end

	-- convert the unit corpse name
	if unitDef.corpse then
		local fullName = unitDefName .. '_' .. unitDef.corpse:lower()
		local corpseFeatureDef = FeatureDefs[fullName]
		if (corpseFeatureDef) then
			unitDef.corpse = fullName
		end
	end
end

--------------------------------------------------------------------------------
-- Process the unitDefs

local UnitDefs = DEFS.unitDefs

for unitDefName, unitDef in pairs(UnitDefs) do
	processUnitDef(unitDefName, unitDef)
end

for featureDefName, featureDef in pairs(FeatureDefs) do
	featureDef.customparams = featureDef.customparams or {}
	local proxy = mapFeatureProxies[featureDefName]
	if proxy then
		featureDef.customparams.i18nfrom = proxy
	end
end
