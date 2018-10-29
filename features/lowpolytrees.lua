
local treeDefs = {}

local trees = {
    {'pinetree1tiny', 'LowpolyPineTrees/pinetree1-pine-tiny.s3o', "2 30 2"},
    {'pinetree2tiny', 'LowpolyPineTrees/pinetree2-pine-tiny.s3o', "2 30 2"},
    {'pinetree3tiny', 'LowpolyPineTrees/pinetree3-pine-tiny.s3o', "2 30 2"},
    {'pinetree1small', 'LowpolyPineTrees/pinetree1-pine-small.s3o', "4 40 4"},
    {'pinetree2small', 'LowpolyPineTrees/pinetree2-pine-small.s3o', "4 40 4"},
    {'pinetree3small', 'LowpolyPineTrees/pinetree3-pine-small.s3o', "4 40 4"},
    {'pinetree1medium', 'LowpolyPineTrees/pinetree1-pine.s3o', "5 50 5"},
    {'pinetree2medium', 'LowpolyPineTrees/pinetree2-pine.s3o', "5 50 5"},
    {'pinetree3medium', 'LowpolyPineTrees/pinetree3-pine.s3o', "5 50 5"},
    {'pinetree1large', 'LowpolyPineTrees/pinetree1-pine-large.s3o', "7 65 7"},
    {'pinetree2large', 'LowpolyPineTrees/pinetree2-pine-large.s3o', "7 65 7"},
    {'pinetree3large', 'LowpolyPineTrees/pinetree3-pine-large.s3o', "7 65 7"},
    {'snowypinetree1tiny', 'LowpolyPineTrees/pinetree1snowy-pine-tiny.s3o', "2 30 2"},
    {'snowypinetree2tiny', 'LowpolyPineTrees/pinetree2snowy-pine-tiny.s3o', "2 30 2"},
    {'snowypinetree3tiny', 'LowpolyPineTrees/pinetree3snowy-pine-tiny.s3o', "2 30 2"},
    {'snowypinetree1small', 'LowpolyPineTrees/pinetree1snowy-pine-small.s3o', "4 40 4"},
    {'snowypinetree2small', 'LowpolyPineTrees/pinetree2snowy-pine-small.s3o', "4 40 4"},
    {'snowypinetree3small', 'LowpolyPineTrees/pinetree3snowy-pine-small.s3o', "4 40 4"},
    {'snowypinetree1medium', 'LowpolyPineTrees/pinetree1snowy-pine.s3o', "5 50 5"},
    {'snowypinetree2medium', 'LowpolyPineTrees/pinetree2snowy-pine.s3o', "5 50 5"},
    {'snowypinetree3medium', 'LowpolyPineTrees/pinetree3snowy-pine.s3o', "5 50 5"},
    {'snowypinetree1large', 'LowpolyPineTrees/pinetree1snowy-pine-large.s3o', "7 65 7"},
    {'snowypinetree2large', 'LowpolyPineTrees/pinetree2snowy-pine-large.s3o', "7 65 7"},
    {'snowypinetree3large', 'LowpolyPineTrees/pinetree3snowy-pine-large.s3o', "7 65 7"},
	{'pinetree1tinyburnt', 'LowpolyPineTrees/pinetree1-pine-tiny-burnt.s3o', "2 30 2"},
    {'pinetree2tinyburnt', 'LowpolyPineTrees/pinetree2-pine-tiny-burnt.s3o', "2 30 2"},
    {'pinetree3tinyburnt', 'LowpolyPineTrees/pinetree3-pine-tiny-burnt.s3o', "2 30 2"},
    {'pinetree1smallburnt', 'LowpolyPineTrees/pinetree1-pine-small-burnt.s3o', "4 40 4"},
    {'pinetree2smallburnt', 'LowpolyPineTrees/pinetree2-pine-small-burnt.s3o', "4 40 4"},
    {'pinetree3smallburnt', 'LowpolyPineTrees/pinetree3-pine-small-burnt.s3o', "4 40 4"},
    {'pinetree1mediumburnt', 'LowpolyPineTrees/pinetree1-pine-burnt.s3o', "5 50 5"},
    {'pinetree2mediumburnt', 'LowpolyPineTrees/pinetree2-pine-burnt.s3o', "5 50 5"},
    {'pinetree3mediumburnt', 'LowpolyPineTrees/pinetree3-pine-burnt.s3o', "5 50 5"},
    {'pinetree1largeburnt', 'LowpolyPineTrees/pinetree1-pine-large-burnt.s3o', "7 65 7"},
    {'pinetree2largeburnt', 'LowpolyPineTrees/pinetree2-pine-large-burnt.s3o', "7 65 7"},
    {'pinetree3largeburnt', 'LowpolyPineTrees/pinetree3-pine-large-burnt.s3o', "7 65 7"},
}

local function CreateTreeDef(i)
    treeDefs["lowpoly_tree_"..trees[i][1]] = {
        name               = trees[i][1],
        description        = [[Pine Tree]],
        blocking           = true,
        flammable          = false, --tree flames are handled by tree_feller gadget
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
        footprintX         = 1,
        footprintZ         = 1,
        collisionVolumeTest = 0,
        collisionvolumescales = trees[i][3],
        collisionvolumetype = "CylY",
        customParams = {
            nohealthbars = true,
        },
    }
end


for i=1,table.getn(trees) do
    CreateTreeDef(i)
end


return lowerkeys( treeDefs )

