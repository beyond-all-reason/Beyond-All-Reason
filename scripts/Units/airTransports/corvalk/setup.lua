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
            "thrust1", "thrust2",
            "thrust3", "thrust4",
        },
        jets = {},
        moveRate = {},
        killed = {
            { maxSeverity = 25,  wreck = 1, pieces = {
                { name="base", sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
            { maxSeverity = 50,  wreck = 2, pieces = {
                { name="base", sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
            { maxSeverity = 100, wreck = 3, pieces = {
                { name="base", sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
        },
    },
}
