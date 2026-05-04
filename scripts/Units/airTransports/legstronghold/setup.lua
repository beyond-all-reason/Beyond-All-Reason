return {
    cargo = {
        primarySlot = "link4x4",
        transporterSeats      = 4,

        slots = {
            { name = "link4x4",   size = 4, requires = { "frlink2x2", "fllink2x2", "brlink2x2", "bllink2x2" } },
            { name = "frlink2x2", size = 1, requires = { "link4x4" } },
            { name = "fllink2x2", size = 1, requires = { "link4x4" } },
            { name = "brlink2x2", size = 1, requires = { "link4x4" } },
            { name = "bllink2x2", size = 1, requires = { "link4x4" } },
        },
    },
    loadMethod = {
        cegScaleFactor = 0.7,
        cegName        = "tractorbeam",
        beams = {
            link4x4   = { "brbeam", "blbeam", "frbeam", "flbeam" },
            frlink2x2 = { "frbeam" },
            fllink2x2 = { "flbeam" },
            brlink2x2 = { "brbeam" },
            bllink2x2 = { "blbeam" },
        },
    },
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
