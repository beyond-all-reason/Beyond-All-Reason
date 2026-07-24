return {
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
