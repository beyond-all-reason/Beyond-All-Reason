-- lootbox beacons

return {
    ["LootboxBeaconBronze"] = {
    groundflash_large = {
            class              = [[CSimpleGroundFlash]],
            count              = 1,
            air                = true,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                colormap           = [[0 0 0 0.01   1 1 1 0.9   1 1 1 0.6   1 1 1 0.3   0 0 0 0.01]],
                size               = 36,
                ttl                = 46,
                sizegrowth         = 0.4,
                texture            = [[circlefx0]],
                alwaysvisible      = true,
            },
        },
    },
    ["LootboxBeaconSilver"] = {
    groundflash_large = {
            class              = [[CSimpleGroundFlash]],
            count              = 1,
            air                = true,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                colormap           = [[0 0 0 0.01   1 1 1 0.9   1 1 1 0.6   1 1 1 0.3   0 0 0 0.01]],
                size               = 54,
                ttl                = 64,
                sizegrowth         = 0.4,
                texture            = [[circlefx1]],
                alwaysvisible      = true,
            },
        },
    },
    ["LootboxBeaconGold"] = {
    groundflash_large = {
            class              = [[CSimpleGroundFlash]],
            count              = 1,
            air                = true,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                colormap           = [[0 0 0 0.01   1 1 1 0.9   1 1 1 0.6   1 1 1 0.3   0 0 0 0.01]],
                size               = 72,
                ttl                = 82,
                sizegrowth         = 0.4,
                texture            = [[circlefx2]],
                alwaysvisible      = true,
            },
        },
    },
    ["LootboxBeaconPlatinum"] = {
    groundflash_large = {
            class              = [[CSimpleGroundFlash]],
            count              = 1,
            air                = true,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                colormap           = [[0 0 0 0.01   1 1 1 0.9   1 1 1 0.8   1 1 1 0.7   1 1 1 0.3   0 0 0 0.01]],
                size               = 90,
                ttl                = 100,
                sizegrowth         = 0.4,
                texture            = [[circlefx3]],
                alwaysvisible      = true,
            },
        },
    },
}