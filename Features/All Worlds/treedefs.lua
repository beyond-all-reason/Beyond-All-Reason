-- Default Spring Treedef

local DRAWTYPE = { NONE = -1, MODEL = 0, TREE = 1 }

local treeDefs = {}

local function CreateTreeDef(type)
  treeDefs["treetype" .. type] = {
	 name 		 = "tree",
     description = [[Tree]],
     blocking    = false,
     burnable    = true,
     reclaimable = true,
	 upright = true,
	 category = "vegetation",
     energy = 250,

     damage      = 5,
     metal = 0,
	 object				="features/0ad/ad0_pine_3_xl.s3o",

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