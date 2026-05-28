return {
    cargo = {
        primarySlot = "link3x3",
        transporterSeats      = 2,
        slots = {
            { name = "link3x3",   size = 2, requires = {"rlink2x2", "llink2x2"} },
            { name = "rlink2x2",   size = 1, requires = { "link3x3" } },
            { name = "llink2x2",   size = 1, requires = { "link3x3" } },
        },
    },
    loadMethod = {
        cegScaleFactor = 0.7,
        cegName        = "tractorbeam",
        beams = {
            link3x3   = { "rbeam" , "lbeam"},
            rlink2x2   = { "rbeam"},
            llink2x2   = { "lbeam"},

        },
    },
    anim = {
        idleHover = {
            piece = "base",
            scale = 1,
            speed = 2,
        },
        thrusters = {
            "thrustl", "thrustr",
            "thrustm",
        },
        jets = {
            "jetl", "jetr",
        },
        moveRate = {
            angles = { [0]=-90, [1]=-70, [2]=-50, [3]=0  },
            speeds = { [0]=150, [1]=75,  [2]=55,  [3]=85 },
        },
        killed = {
            { maxSeverity = 25,  wreck = 1, pieces = {
                { name="base",     sfx = "BITMAPONLY|NO_HEATCLOUD" },
                { name="backwing", sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
            { maxSeverity = 50,  wreck = 2, pieces = {
                { name="body",    sfx = "BITMAPONLY|NO_HEATCLOUD" },
                { name="base",     sfx = "BITMAPONLY|NO_HEATCLOUD" },
                { useJets=true,    sfx = "BITMAPONLY|NO_HEATCLOUD" },
                { name="backwing", sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
            { maxSeverity = 100, wreck = 3, pieces = {
                { name="body",    sfx = "BITMAPONLY|NO_HEATCLOUD" },
                { name="base",     sfx = "BITMAPONLY|NO_HEATCLOUD" },
                { useJets=true,    sfx = "BITMAPONLY|NO_HEATCLOUD" },
                { name="backwing", sfx = "FALL|SMOKE|FIRE|EXPLODE_ON_HIT|BITMAP2|NO_HEATCLOUD" },
            }},
        },
    },
}
