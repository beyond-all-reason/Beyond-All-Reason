
local treeDefs = {}

local trees = {
    {'pine1', 'LowpolyPineTrees/pinetree1-pine.s3o'},
    {'pine2', 'LowpolyPineTrees/pinetree2-pine.s3o'},
    {'pine3', 'LowpolyPineTrees/pinetree3-pine.s3o'},
    {'pine1small', 'LowpolyPineTrees/pinetree1-pine-tiny.s3o'},
    {'pine2small', 'LowpolyPineTrees/pinetree2-pine-tiny.s3o'},
    {'pine3small', 'LowpolyPineTrees/pinetree3-pine-tiny.s3o'},
    {'pine1small', 'LowpolyPineTrees/pinetree1-pine-small.s3o'},
    {'pine2small', 'LowpolyPineTrees/pinetree2-pine-small.s3o'},
    {'pine3small', 'LowpolyPineTrees/pinetree3-pine-small.s3o'},
    {'pine1small', 'LowpolyPineTrees/pinetree1-pine-large.s3o'},
    {'pine2small', 'LowpolyPineTrees/pinetree2-pine-large.s3o'},
    {'pine3small', 'LowpolyPineTrees/pinetree3-pine-large.s3o'},
    {'snowypine1', 'LowpolyPineTrees/pinetree1snowy-pine.s3o'},
    {'snowypine2', 'LowpolyPineTrees/pinetree2snowy-pine.s3o'},
    {'snowypine3', 'LowpolyPineTrees/pinetree3snowy-pine.s3o'},
    {'snowypine1small', 'LowpolyPineTrees/pinetree1snowy-pine-tiny.s3o'},
    {'snowypine2small', 'LowpolyPineTrees/pinetree2snowy-pine-tiny.s3o'},
    {'snowypine3small', 'LowpolyPineTrees/pinetree3snowy-pine-tiny.s3o'},
    {'snowypine1small', 'LowpolyPineTrees/pinetree1snowy-pine-small.s3o'},
    {'snowypine2small', 'LowpolyPineTrees/pinetree2snowy-pine-small.s3o'},
    {'snowypine3small', 'LowpolyPineTrees/pinetree3snowy-pine-small.s3o'},
    {'snowypine1small', 'LowpolyPineTrees/pinetree1snowy-pine-large.s3o'},
    {'snowypine2small', 'LowpolyPineTrees/pinetree2snowy-pine-large.s3o'},
    {'snowypine3small', 'LowpolyPineTrees/pinetree3snowy-pine-large.s3o'},
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
     energy             = 25,
     damage             = 5,
     metal              = 0,
     object             = trees[i][2], --math.random() doesnt seem to work
     reclaimTime        = 25,
     mass               = 5,
     drawType           = 1,
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

