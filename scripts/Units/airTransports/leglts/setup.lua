return {
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
