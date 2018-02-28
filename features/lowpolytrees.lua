
local treeDefs = {}

local trees = {
    {'pinetree1tiny', 'LowpolyPineTrees/pinetree1-pine-tiny.s3o'},
    {'pinetree2tiny', 'LowpolyPineTrees/pinetree2-pine-tiny.s3o'},
    {'pinetree3tiny', 'LowpolyPineTrees/pinetree3-pine-tiny.s3o'},
    {'pinetree1small', 'LowpolyPineTrees/pinetree1-pine-small.s3o'},
    {'pinetree2small', 'LowpolyPineTrees/pinetree2-pine-small.s3o'},
    {'pinetree3small', 'LowpolyPineTrees/pinetree3-pine-small.s3o'},
    {'pinetree1medium', 'LowpolyPineTrees/pinetree1-pine.s3o'},
    {'pinetree2medium', 'LowpolyPineTrees/pinetree2-pine.s3o'},
    {'pinetree3medium', 'LowpolyPineTrees/pinetree3-pine.s3o'},
    {'pinetree1small', 'LowpolyPineTrees/pinetree1-pine-large.s3o'},
    {'pinetree2small', 'LowpolyPineTrees/pinetree2-pine-large.s3o'},
    {'pinetree3small', 'LowpolyPineTrees/pinetree3-pine-large.s3o'},
    {'snowypinetree1tiny', 'LowpolyPineTrees/pinetree1snowy-pine-tiny.s3o'},
    {'snowypinetree2tiny', 'LowpolyPineTrees/pinetree2snowy-pine-tiny.s3o'},
    {'snowypinetree3tiny', 'LowpolyPineTrees/pinetree3snowy-pine-tiny.s3o'},
    {'snowypinetree1small', 'LowpolyPineTrees/pinetree1snowy-pine-small.s3o'},
    {'snowypinetree2small', 'LowpolyPineTrees/pinetree2snowy-pine-small.s3o'},
    {'snowypinetree3small', 'LowpolyPineTrees/pinetree3snowy-pine-small.s3o'},
    {'snowypinetree1medium', 'LowpolyPineTrees/pinetree1snowy-pine.s3o'},
    {'snowypinetree2medium', 'LowpolyPineTrees/pinetree2snowy-pine.s3o'},
    {'snowypinetree3medium', 'LowpolyPineTrees/pinetree3snowy-pine.s3o'},
    {'snowypinetree1large', 'LowpolyPineTrees/pinetree1snowy-pine-large.s3o'},
    {'snowypinetree2large', 'LowpolyPineTrees/pinetree2snowy-pine-large.s3o'},
    {'snowypinetree3large', 'LowpolyPineTrees/pinetree3snowy-pine-large.s3o'},
}

local function CreateTreeDef(i)
  treeDefs["lowpoly_tree_"..trees[i][1]] = {
     name               = trees[i][1],
     description        = [[Pine Tree]],
     blocking           = false,
     burnable           = true,
     reclaimable        = true,
     upright            = true,
     category           = "vegetation",
     energy             = 250,
     damage             = 25,
     metal              = 0,
     object             = trees[i][2], --math.random() doesnt seem to work
     reclaimTime        = 1100,
     mass               = 10,
     drawType           = 0,
     footprintX         = 2,
     footprintZ         = 2,
     collisionVolumeTest = 0,
     customParams = {

     },
  }
end


for i=1,table.getn(trees) do
    CreateTreeDef(i)
end


return lowerkeys( treeDefs )

