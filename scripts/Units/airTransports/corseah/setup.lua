return {
    cargo = {
        primarySlot = "flink4x4",
        transporterSeats      = 8,

        slots = {
            -- 4 - sized
            { name = "flink4x4",  size = 4, requires = { "mlink4x4", "fflink3x3", "fblink3x3", "frlink3x3", "fllink3x3", "mrlink3x3", "mllink3x3", "ffrlink2x2", "ffllink2x2", "fbrlink2x2", "fbllink2x2" } },
            { name = "blink4x4",  size = 4, requires = { "mlink4x4", "bblink3x3", "bflink3x3", "brlink3x3", "bllink3x3", "mrlink3x3", "mllink3x3", "bbrlink2x2", "bbllink2x2", "bfrlink2x2", "bfllink2x2" } },
            { name = "mlink4x4",  size = 4, requires = { "flink4x4", "blink4x4", "fblink3x3", "bflink3x3", "frlink3x3", "fllink3x3", "brlink3x3", "bllink3x3", "mrlink3x3", "mllink3x3", "fbrlink2x2", "fbllink2x2", "bfrlink2x2", "bfllink2x2" } },
            -- 2 - sized
            { name = "fflink3x3", size = 2, requires = { "flink4x4", "frlink3x3", "fllink3x3", "ffrlink2x2", "ffllink2x2" } },
            { name = "fblink3x3", size = 2, requires = { "flink4x4", "mlink4x4", "frlink3x3", "fllink3x3", "mrlink3x3", "mllink3x3", "fbrlink2x2", "fbllink2x2" } },
            { name = "bflink3x3", size = 2, requires = { "blink4x4", "mlink4x4", "mrlink3x3", "brlink3x3", "bllink3x3", "mllink3x3", "bfrlink2x2", "bfllink2x2" } },
            { name = "bblink3x3", size = 2, requires = { "blink4x4", "brlink3x3", "bllink3x3", "bbrlink2x2", "bbllink2x2" } },
            { name = "frlink3x3", size = 2, requires = { "flink4x4", "mlink4x4", "fflink3x3", "fblink3x3", "mrlink3x3", "ffrlink2x2", "fbrlink2x2" } },
            { name = "fllink3x3", size = 2, requires = { "flink4x4", "mlink4x4", "fflink3x3", "fblink3x3", "mllink3x3", "ffllink2x2", "fbllink2x2" } },
            { name = "mrlink3x3", size = 2, requires = { "flink4x4", "blink4x4", "mlink4x4", "fblink3x3", "bflink3x3", "frlink3x3", "brlink3x3", "fbrlink2x2", "bfrlink2x2" } },
            { name = "mllink3x3", size = 2, requires = { "flink4x4", "blink4x4", "mlink4x4", "fblink3x3", "bflink3x3", "fllink3x3", "bllink3x3", "fbllink2x2", "bfllink2x2" } },
            { name = "brlink3x3", size = 2, requires = { "blink4x4", "mlink4x4", "bflink3x3", "bblink3x3", "mrlink3x3", "bfrlink2x2", "bbrlink2x2" } },
            { name = "bllink3x3", size = 2, requires = { "blink4x4", "mlink4x4", "bflink3x3", "bblink3x3", "mllink3x3", "bfllink2x2", "bbllink2x2" } },
            -- 1 - sized
            { name = "ffrlink2x2", size = 1, requires = { "flink4x4", "fflink3x3", "frlink3x3" } },
            { name = "ffllink2x2", size = 1, requires = { "flink4x4", "fflink3x3", "fllink3x3" } },
            { name = "fbrlink2x2", size = 1, requires = { "flink4x4", "mlink4x4", "fblink3x3", "frlink3x3", "mrlink3x3" } },
            { name = "fbllink2x2", size = 1, requires = { "flink4x4", "mlink4x4", "fblink3x3", "fllink3x3", "mllink3x3" } },
            { name = "bfrlink2x2", size = 1, requires = { "blink4x4", "mlink4x4", "bflink3x3", "mrlink3x3", "brlink3x3" } },
            { name = "bfllink2x2", size = 1, requires = { "blink4x4", "mlink4x4", "bflink3x3", "mllink3x3", "bllink3x3" } },
            { name = "bbrlink2x2", size = 1, requires = { "blink4x4", "bblink3x3", "brlink3x3" } },
            { name = "bbllink2x2", size = 1, requires = { "blink4x4", "bblink3x3", "bllink3x3" } },
        },
    },
    loadMethod = {
        cegScaleFactor = 0.7,
        cegName        = "tractorbeam",
        beams = {
            flink4x4   = { "fbrbeam", "fblbeam", "ffrbeam", "fflbeam" },
            blink4x4   = { "bbrbeam", "bblbeam", "bfrbeam", "bflbeam" },
            mlink4x4   = { "fbrbeam", "fblbeam", "bfrbeam", "bflbeam" },
            fflink3x3  = { "ffrbeam", "fflbeam" },
            fblink3x3  = { "fbrbeam", "fblbeam" },
            bflink3x3  = { "bfrbeam", "bflbeam" },
            bblink3x3  = { "bbrbeam", "bblbeam" },
            frlink3x3  = { "ffrbeam", "fbrbeam" },
            fllink3x3  = { "fflbeam", "fblbeam" },
            mrlink3x3  = { "fbrbeam", "bfrbeam" },
            mllink3x3  = { "fblbeam", "bflbeam", },
            brlink3x3  = { "bfrbeam", "bbrbeam" },
            bllink3x3  = { "bflbeam", "bblbeam",  },
            ffrlink2x2 = { "ffrbeam" },
            ffllink2x2 = { "fflbeam" },
            fbrlink2x2 = { "fbrbeam" },
            fbllink2x2 = { "fblbeam" },
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
