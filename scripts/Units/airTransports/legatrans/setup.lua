return {
    anim = {
        idleHover = {
            piece = "base",
            scale = 1,
            speed = 2,
        },
        thrusters = {
            "leftGroundThrust", "rightGroundThrust",
            "leftMainThrust", "leftMiniThrust",
            "rightMainThrust", "rightMiniThrust",	
        },
        jets = {
            "rightWing", "leftWing",
        },
        moveRate = {
            angles = { [0]=0, [1]=0, [2]=0, [3]=0  },
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
