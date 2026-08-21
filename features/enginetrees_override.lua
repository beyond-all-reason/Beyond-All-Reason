local objects = {
	"fir_tree_smallest.s3o",
	"fir_tree_small.s3o",
	"fir_tree_medium.s3o",
	"fir_tree_large.s3o",
}

-- Pre-baked scale variants of the objects above (tools/s3o_scale.py). The
-- engine has no runtime feature-scale API -- SetFeaturePieceMatrix rejects
-- matrices carrying scale -- so the Feature Placer's scale variation works by
-- snapping each rolled scale to the nearest of these factors and placing the
-- matching variant def. Suffix is factor*100.
local SCALE_FACTORS = { 0.40, 0.55, 0.70, 0.85, 1.15 }

local treeDefs = {}
local function CreateTreeDef(i)
	local baseName = "treetype" .. i
	local object = objects[(i % #objects) + 1]

	local function makeDef(factor)
		local def = {
			description = [[Tree]],
			blocking = true,
			burnable = true,
			reclaimable = true,
			energy = 250,
			damage = 250,
			metal = 0,
			reclaimTime = 1500,
			mass = 20,
			upright = true,
			object = object,
			footprintX = 1,
			footprintZ = 1,
			collisionVolumeScales = [[20 60 20]],
			collisionVolumeType = [[cylY]],

			customParams = {
				model_author = "Beherith, 0 A.D.",
				normalmaps = "yes",
				normaltex = "unittextures/tree_fir_tall_5_normal.dds",
				treeshader = "yes",
				randomrotate = "true",
				category = "Plants",
				set = "0AD features",
			},
		}
		if factor then
			-- Wood-value, mass, and the collision cylinder all track the model
			-- size, so a sapling is worth (and blocks) less than an old-growth.
			def.object = object:gsub("%.s3o$", string.format("_s%03d.s3o", math.floor(factor * 100 + 0.5)))
			def.energy = math.max(1, math.floor(def.energy * factor + 0.5))
			def.reclaimTime = math.max(1, math.floor(def.reclaimTime * factor + 0.5))
			def.mass = math.max(1, def.mass * factor)
			def.collisionVolumeScales = string.format("%.0f %.0f %.0f", 20 * factor, 60 * factor, 20 * factor)
			-- The placer builds its variant lookup from these; scale_base also
			-- keeps variants out of the asset library.
			def.customParams.scale_base = baseName
			def.customParams.scale_factor = tostring(factor)
		end
		return def
	end

	treeDefs[baseName] = makeDef(nil)
	for _, factor in ipairs(SCALE_FACTORS) do
		treeDefs[string.format("%s_s%03d", baseName, math.floor(factor * 100 + 0.5))] = makeDef(factor)
	end
end

--[[ In theory it's possible to have treetype16 or higher.
     However in practice Spring struggles to render tree
     types higher than 15 (or at least did historically),
     for which reason map compilers don't usually permit
     placing those, in turn making maps with them really
     rare (enough not to worry about it, at least). ]]
for i = 0, 15 do
	CreateTreeDef(i)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return lowerkeys(treeDefs)
