return {
    anim = {
        idleHover = {
            piece = "base",
            scale = 1,
            speed = 2,
        },
        thrusters = {
            "thrustbl", "thrustbr",
            "thrustfl", "thrustfr",
        },
        jets = {
            "jetbr", "jetbl",
            "jetfr", "jetfl",
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
                { useJets=true, sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
            { maxSeverity = 100, wreck = 3, pieces = {
                { name="base",  sfx = "BITMAPONLY|NO_HEATCLOUD" },
                { useJets=true, sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
        },
    },
}
