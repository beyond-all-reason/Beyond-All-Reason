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
                size               = 30,
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
                colormap           = [[0 0 0 0.01   1 1 1 0.9   1 1 1 0.6   0 0 0 0.01]],
                size               = 28,
                ttl                = 32,
                sizegrowth         = 0.5,
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
                colormap           = [[0 0 0 0.01   1 1 1 0.9   1 1 1 0.6   0 0 0 0.01]],
                size               = 32,
                ttl                = 46,
                sizegrowth         = 0.5,
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
                colormap           = [[0 0 0 0.01   1 1 1 0.9   1 1 1 0.6   0 0 0 0.01]],
                size               = 36,
                ttl                = 56,
                sizegrowth         = 0.5,
                texture            = [[seismic]],
                alwaysvisible      = true,
            },
        },
    },
}