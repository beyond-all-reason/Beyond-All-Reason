local objects = {
	"fir_tree_smallest.s3o",
	"fir_tree_small.s3o",
	"fir_tree_medium.s3o",
	"fir_tree_large.s3o",
}

local treeDefs = {}
local function CreateTreeDef(i)
  treeDefs["treetype" .. i] = {
     description = [[Tree]],
     blocking    = true,
     burnable    = true,
     reclaimable = true,
     energy      = 250,
     damage      = 250,
     metal       = 0,
     reclaimTime = 1500,
     mass        = 20,
     upright     = true,
     object = objects[(i % #objects) + 1] ,
     footprintX  = 1,
     footprintZ  = 1,
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
end

--[[ In theory it's possible to have treetype16 or higher.
     However in practice Spring struggles to render tree
     types higher than 15 (or at least did historically),
     for which reason map compilers don't usually permit
     placing those, in turn making maps with them really
     rare (enough not to worry about it, at least). ]]
for i=0,15 do
  CreateTreeDef(i)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return lowerkeys( treeDefs )
