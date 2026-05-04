return {
    cargo = {
        primarySlot = "flink4x4",
        transporterSeats      = 8,

        slots = {
            { name = "flink4x4",   size = 4, requires = { "ffrlink2x2", "ffllink2x2", "fbrlink2x2", "fbllink2x2" } },
            { name = "ffrlink2x2", size = 1, requires = { "flink4x4" } },
            { name = "ffllink2x2", size = 1, requires = { "flink4x4" } },
            { name = "fbrlink2x2", size = 1, requires = { "flink4x4" } },
            { name = "fbllink2x2", size = 1, requires = { "flink4x4" } },
            { name = "blink4x4",   size = 4, requires = { "bfrlink2x2", "bfllink2x2", "bbrlink2x2", "bbllink2x2" } },
            { name = "bfrlink2x2", size = 1, requires = { "blink4x4" } },
            { name = "bfllink2x2", size = 1, requires = { "blink4x4" } },
            { name = "bbrlink2x2", size = 1, requires = { "blink4x4" } },
            { name = "bbllink2x2", size = 1, requires = { "blink4x4" } },
        },
    },
    loadMethod = {
        cegScaleFactor = 0.7,
        cegName        = "tractorbeam",
        beams = {
            flink4x4   = { "fbrbeam", "fblbeam", "ffrbeam", "fflbeam" },
            ffrlink2x2 = { "ffrbeam" },
            ffllink2x2 = { "fflbeam" },
            fbrlink2x2 = { "fbrbeam" },
            fbllink2x2 = { "fblbeam" },
            blink4x4   = { "bbrbeam", "bblbeam", "bfrbeam", "bflbeam" },
            bfrlink2x2 = { "bfrbeam" },
            bfllink2x2 = { "bflbeam" },
            bbrlink2x2 = { "bbrbeam" },
            bbllink2x2 = { "bblbeam" },
        },
    },
    anim = {
        idleHover = {
            piece = "base",
            scale = 1,
            speed = 2,
        },
        thrusters = {
            "thrustrla", "thrustrra",
            "thrustfla", "thrustfra",
        },
        jets = {
            "thrustrl", "thrustrr",
            "thrustfl", "thrustfr",
        },
        moveRate = {
            angles = { [0]=-90, [1]=-70, [2]=-50, [3]=0  },
            speeds = { [0]=150, [1]=75,  [2]=55,  [3]=85 },
        },
        killed = {
            { maxSeverity = 25,  wreck = 1, pieces = {
                { name="base",     sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
            { maxSeverity = 50,  wreck = 2, pieces = {
                { name="base",     sfx = "BITMAPONLY|NO_HEATCLOUD" },
                { useJets=true,    sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
            { maxSeverity = 100, wreck = 3, pieces = {
                { name="base",     sfx = "BITMAPONLY|NO_HEATCLOUD" },
                { useJets=true,    sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
        },
    },
}
