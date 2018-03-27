-- Default Spring Treedef

--(map_tree_replacer gadget will replace these again, but with different sizes and rotation)

local treeDefs = {}


local DRAWTYPE = { NONE = -1, MODEL = 0, TREE = 1 }

local function CreateTreeDef(type)
  treeDefs["treetype" .. type] = {
     name 		 = "tree",
     description = [[Tree]],
     blocking    = true,
     flammable    = false,
     reclaimable = true,
     upright = true,
     category = "vegetation",
     energy = 250,

     damage      = 5,
     metal = 0,
     object	= 'LowpolyPineTrees/pinetree3-pine.s3o', --math.random() doesnt seem to work

     reclaimTime = 1500,
     mass        = 20,
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

return lowerkeys( treeDefs )