-- Default Spring Treedef



if Spring.GetModOptions and (tonumber(Spring.GetModOptions().barmodels) or 0) ~= 0 then
    local DRAWTYPE = { NONE = -1, MODEL = 0, TREE = 1 }

    local treeDefs = {}

    local randomTrees = {'LowpolyPineTrees/pinetree1-pine.s3o','LowpolyPineTrees/pinetree2-pine.s3o','LowpolyPineTrees/pinetree3-pine.s3o'}
    local numRandomTrees = table.getn(randomTrees)
    local function CreateTreeDef(type)
      treeDefs["treetype" .. type] = {
         name 		 = "tree",
         description = [[Tree]],
         blocking    = false,
         burnable    = true,
         reclaimable = true,
         upright = true,
         category = "vegetation",
         energy = 0,

         damage      = 5,
         metal = 0,
         object	= randomTrees[3], --math.random() doesnt seem to work

         reclaimTime = 25,
         mass        = 5,
         drawType    = DRAWTYPE.MODEL,
         footprintX  = 2,
         footprintZ  = 2,
         collisionVolumeTest = 0,

         customParams = {
           mod = true,
         },

         modelType   = type,
      }
    end

    for i=0,259 do
      CreateTreeDef(i)
    end

    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------

    return lowerkeys( treeDefs )

    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------

end