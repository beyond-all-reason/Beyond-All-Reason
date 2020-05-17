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
                colormap           = [[0.8 0.63 0.4 0.9   0.8 0.63 0.4 0.7   0 0 0 0.01]],
                size               = 28,
                ttl                = 20,
                sizegrowth         = 0.4,
                texture            = [[seismic]],
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
                colormap           = [[0.8 0.8 0.8 0.9   0.8 0.8 0.8 0.7   0 0 0 0.01]],
                size               = 26,
                ttl                = 24,
                sizegrowth         = 0.4,
                texture            = [[seismic]],
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
                colormap           = [[1 0.79 0.3 0.9   1 0.79 0.3 0.7   0 0 0 0.01]],
                size               = 24,
                ttl                = 28,
                sizegrowth         = 0.4,
                texture            = [[seismic]],
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
                colormap           = [[1 1 1 0.9   1 1 1 0.7   0 0 0 0.01]],
                size               = 24,
                ttl                = 32,
                sizegrowth         = 0.4,
                texture            = [[seismic]],
                alwaysvisible      = true,
            },
        },
    },
}