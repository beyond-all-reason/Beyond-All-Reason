local function torpedoCavitationTrail()
    return {
        air                = false,
        class              = [[CBitmapMuzzleFlame]],
        count              = 1,
        ground             = false,
        underwater         = true,
        water              = true,

        properties = {
            colormap           = [[0.55 0.72 1.00 0.0168   0.38 0.58 0.95 0.0126   0.18 0.32 0.65 0.007   0.04 0.08 0.18 0.0028   0 0 0 0.0042]],
            dir                = [[dir]],
            frontoffset        = 0.03,
            fronttexture       = [[blastwave]],
            length             = -2.8,
            sidetexture        = [[shot]],
            size               = 2.35,
            sizegrowth         = -0.18,
            ttl                = 8,
            useairlos          = true,
        },
    }
end

local definitions = {

    ["torpedotrail-tiny"] = {
        cavitation = torpedoCavitationTrail(),
        trail = {
            air                = false,
            class              = [[CBitmapMuzzleFlame]],
            count              = 0,
            ground             = false,
            underwater         = true,
            water              = true,
            properties = {
                colormap           = [[0.20 0.21 0.23 0.025   0 0 0 0.001]],
                dir                = [[dir]],
                frontoffset        = 0,
                fronttexture       = [[explowater]],
                length             = -2.7,
                sidetexture        = [[none]],
                size               = 1.8,
                sizegrowth         = 1.4,
                ttl                = 5,
                rotParams          = [[0, -50 r100, -20 r40]],
            },
        },
    },

    ["torpedotrail-small"] = {
        cavitation = torpedoCavitationTrail(),
        trail = {
            air                = false,
            class              = [[CBitmapMuzzleFlame]],
            count              = 1,
            ground             = false,
            underwater         = true,
            water              = true,
            properties = {
                colormap           = [[0.35 0.36 0.38 0.025   0.12 0.13 0.14 0.020   0 0 0 0.001]],
                dir                = [[dir]],
                frontoffset        = 0,
                fronttexture       = [[explowater]],
                length             = -3.2,
                sidetexture        = [[none]],
                size               = 1.6,
                sizegrowth         = 1.2,
                ttl                = 6,
                rotParams          = [[0, -50 r100, -20 r40]],
            },
        },
    },

    ["torpedotrail-large"] = {
        cavitation = torpedoCavitationTrail(),
        trail = {
            air                = false,
            class              = [[CBitmapMuzzleFlame]],
            count              = 1,
            ground             = false,
            underwater         = true,
            water              = true,
            properties = {
                colormap           = [[0.35 0.36 0.38 0.025   0.12 0.13 0.14 0.020   0 0 0 0.001]],
                dir                = [[dir]],
                frontoffset        = 0,
                fronttexture       = [[explowater]],
                length             = -3.2,
                sidetexture        = [[none]],
                size               = 1.8,
                sizegrowth         = 1.4,
                ttl                = 6,
                rotParams          = [[0, -50 r100, -20 r40]],
            },
        },

        trailtiny = {
            air                = false,
            class              = [[CBitmapMuzzleFlame]],
            count              = 2,
            ground             = false,
            underwater         = true,
            water              = true,
            properties = {
                colormap           = [[0.20 0.21 0.23 0.025   0 0 0 0.001]],
                dir                = [[dir]],
                frontoffset        = 0,
                fronttexture       = [[explowater]],
                length             = -2.7,
                sidetexture        = [[none]],
                size               = 1.8,
                sizegrowth         = 1.4,
                ttl                = 5,
                rotParams          = [[0, -50 r100, -20 r40]],
            },
        },

        -- engine = {
        --     air                = false,
        --     class              = [[CBitmapMuzzleFlame]],
        --     count              = 1,
        --     ground             = false,
        --     underwater         = 1,
        --     water              = true,
        --     properties = {
        --         colormap           = [[1 0.7 0.9 0.01   0.6 0.6 1 0.01   0.4 0.4 1 0.01   0 0 0 0.01]],
        --         dir                = [[dir]],
        --         frontoffset        = 0,
        --         fronttexture       = [[none]],
        --         length             = [[-14 r4]],
        --         sidetexture        = [[muzzleside]],
        --         size               = 1.6,
        --         sizegrowth         = [[0.2 r0.3]],
        --         ttl                = 1,
        --     },
        -- },
        -- sparks = {
        --     air                = true,
        --     class              = [[CSimpleParticleSystem]],
        --     count              = 1,
        --     ground             = true,
        --     water              = true,
        --     underwater         = 1,
        --     properties = {
        --         airdrag            = 0.95,
        --         colormap           = [[0.3 0.3 0.4 0.01   0.15 0.15 0.2 0.007   0 0 0 0.01]],
        --         directional        = true,
        --         emitrot            = 45,
        --         emitrotspread      = 7,
        --         emitvector         = [[dir]],
        --         gravity            = [[0, 0, 0]],
        --         numparticles       = 1,
        --         particlelife       = 5,
        --         particlelifespread = 2,
        --         particlesize       = 12,
        --         particlesizespread = 24,
        --         particlespeed      = 4.5,
        --         particlespeedspread = 3.5,
        --         pos                = [[0, 90 ,0]],
        --         sizegrowth         = 0.5,
        --         sizemod            = 0.99,
        --         texture            = [[gunshotglow]],
        --         useairlos          = false,
        --     },
        -- },
    },

    -- ["torpedo-launch"] = {

    -- },
}

return definitions
