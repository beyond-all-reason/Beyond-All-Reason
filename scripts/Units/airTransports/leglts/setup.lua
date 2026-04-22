-- setup.lua
-- All configuration for corvalk.

return {

    -- -------------------------------------------------------------------------
    -- Cargo hardpoint configuration.
    cargo = {
        primarySlot = "link2x2",
        nSeats      = 1,   -- total seat capacity; read by the transport gadget to check available room

        slots = {
            { name = "link2x2", size = 1, requires = {} },
        },
    },

    -- -------------------------------------------------------------------------
    -- Tractor-beam load method configuration.
    loadMethod = {
        cegScaleFactor = 0.7,   -- scales the beam direction vector passed to SpawnCEG
        cegName        = "tractorbeam",
        cruiseHeight   = 150,   -- elmos above terrain; also used by engine as approach altitude

        -- Beam emitter pieces per slot name, used as CEG origin points for the tractor-beam VFX.
        beams = {
            link2x2 = { "beam" },
        },
    },

    -- -------------------------------------------------------------------------
    -- Animation configuration.
    anim = {
        idleHover = {
            piece = "base",
            scale = 1,
            speed = 2,
        },

        thrusters = {
		"lthrust", "rthrust",
        },

        jets = {
		"lwing", "rwing", "bwing",
	},

        moveRate = {},

        -- Tiers evaluated in order; first tier where severity <= maxSeverity wins.
        killed = {
            { maxSeverity = 25,  wreck = 1, pieces = {
                { name="base", sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
            { maxSeverity = 50,  wreck = 2, pieces = {
                { name="base", sfx = "BITMAPONLY|NO_HEATCLOUD" },
                { useJets=true, sfx = "BITMAPONLY|NO_HEATCLOUD" },

            }},
            { maxSeverity = 100, wreck = 3, pieces = {
                { name="base", sfx = "BITMAPONLY|NO_HEATCLOUD" },
                { useJets=true, sfx = "BITMAPONLY|NO_HEATCLOUD" },

            }},
        },
    },
}
