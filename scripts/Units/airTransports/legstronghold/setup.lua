-- setup.lua
-- All configuration for corhvytrans.

return {

    -- -------------------------------------------------------------------------
    -- Cargo hardpoint configuration.
    cargo = {
        primarySlot = "link4x4",
        nSeats      = 4,   -- total seat capacity; read by the transport gadget to check available room

        slots = {
            { name = "link4x4",   size = 4, requires = { "frlink2x2", "fllink2x2", "brlink2x2", "bllink2x2" } },
            { name = "frlink2x2", size = 1, requires = { "link4x4" } },
            { name = "fllink2x2", size = 1, requires = { "link4x4" } },
            { name = "brlink2x2", size = 1, requires = { "link4x4" } },
            { name = "bllink2x2", size = 1, requires = { "link4x4" } },
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
            link4x4   = { "brbeam", "blbeam", "frbeam", "flbeam" },
            frlink2x2 = { "frbeam" },
            fllink2x2 = { "flbeam" },
            brlink2x2 = { "brbeam" },
            bllink2x2 = { "blbeam" },
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
            "rthrust1", "rthrust2",
            "lthrust1", "lthrust2",
            "bthrust1", "bthrust2",
        },

        jets = {
		"rjet", "ljet","bjet",
        },

        moveRate = {
            angles = { [0]=-90, [1]=-70, [2]=-50, [3]=0  },
            speeds = { [0]=150, [1]=75,  [2]=55,  [3]=85 },
        },

        -- Tiers evaluated in order; first tier where severity <= maxSeverity wins.
        killed = {
            { maxSeverity = 25,  wreck = 1, pieces = {
                { name="base",  sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
            { maxSeverity = 50,  wreck = 2, pieces = {
                { name="base",  sfx = "BITMAPONLY|NO_HEATCLOUD" },
                { useJets=true,    sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
            { maxSeverity = 100, wreck = 3, pieces = {
                { name="base",  sfx = "BITMAPONLY|NO_HEATCLOUD" },
                { useJets=true,    sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
        },
    },
	wpn = {
	aimFromPiece = "aimpoint",
	aimPiece = "sleeve",
	firePiece = "flare",
	},
}
