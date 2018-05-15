
local treeDefs = {}

local trees = {
    {'pinetree1tiny', 'LowpolyPineTrees/pinetree1-pine-tiny.s3o', "9 25 9"},
    {'pinetree2tiny', 'LowpolyPineTrees/pinetree2-pine-tiny.s3o', "9 25 9"},
    {'pinetree3tiny', 'LowpolyPineTrees/pinetree3-pine-tiny.s3o', "9 25 9"},
    {'pinetree1small', 'LowpolyPineTrees/pinetree1-pine-small.s3o', "12 38 12"},
    {'pinetree2small', 'LowpolyPineTrees/pinetree2-pine-small.s3o', "12 38 12"},
    {'pinetree3small', 'LowpolyPineTrees/pinetree3-pine-small.s3o', "12 38 12"},
    {'pinetree1medium', 'LowpolyPineTrees/pinetree1-pine.s3o', "15 40 15"},
    {'pinetree2medium', 'LowpolyPineTrees/pinetree2-pine.s3o', "15 40 15"},
    {'pinetree3medium', 'LowpolyPineTrees/pinetree3-pine.s3o', "15 40 15"},
    {'pinetree1small', 'LowpolyPineTrees/pinetree1-pine-large.s3o', "20 55 20"},
    {'pinetree2small', 'LowpolyPineTrees/pinetree2-pine-large.s3o', "20 55 20"},
    {'pinetree3small', 'LowpolyPineTrees/pinetree3-pine-large.s3o', "20 55 20"},
    {'snowypinetree1tiny', 'LowpolyPineTrees/pinetree1snowy-pine-tiny.s3o', "9 25 9"},
    {'snowypinetree2tiny', 'LowpolyPineTrees/pinetree2snowy-pine-tiny.s3o', "9 25 9"},
    {'snowypinetree3tiny', 'LowpolyPineTrees/pinetree3snowy-pine-tiny.s3o', "9 25 9"},
    {'snowypinetree1small', 'LowpolyPineTrees/pinetree1snowy-pine-small.s3o', "13 33 13"},
    {'snowypinetree2small', 'LowpolyPineTrees/pinetree2snowy-pine-small.s3o', "13 33 13"},
    {'snowypinetree3small', 'LowpolyPineTrees/pinetree3snowy-pine-small.s3o', "13 33 13"},
    {'snowypinetree1medium', 'LowpolyPineTrees/pinetree1snowy-pine.s3o', "16 40 16"},
    {'snowypinetree2medium', 'LowpolyPineTrees/pinetree2snowy-pine.s3o', "16 40 16"},
    {'snowypinetree3medium', 'LowpolyPineTrees/pinetree3snowy-pine.s3o', "16 40 16"},
    {'snowypinetree1large', 'LowpolyPineTrees/pinetree1snowy-pine-large.s3o', "20 55 20"},
    {'snowypinetree2large', 'LowpolyPineTrees/pinetree2snowy-pine-large.s3o', "20 55 20"},
    {'snowypinetree3large', 'LowpolyPineTrees/pinetree3snowy-pine-large.s3o', "20 55 20"},
}

local function CreateTreeDef(i)
    treeDefs["lowpoly_tree_"..trees[i][1]] = {
        name               = trees[i][1],
        description        = [[Pine Tree]],
        blocking           = true,
        flammable          = false,
        reclaimable        = true,
        upright            = true,
        indestructible     = false,
        crushResistance    = 12,
        category           = "vegetation",
        energy             = 250,
        damage             = 5,
        metal              = 0,
        object             = trees[i][2], --math.random() doesnt seem to work
        reclaimTime        = 1500,
        mass               = 20,
        drawType           = 1,
        footprintX         = 2,
        footprintZ         = 2,
        collisionVolumeTest = 0,
        collisionvolumescales = trees[i][3],
        collisionvolumetype = "CylY",
        customParams = {

        },
    }
end


for i=1,table.getn(trees) do
    CreateTreeDef(i)
end


return lowerkeys( treeDefs )

