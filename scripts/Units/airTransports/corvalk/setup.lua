return {
    cargo = {
        primarySlot = "link",
        terSeats      = 1,

        slots = {
            { name = "link", size = 1, requires = {} },
        },
    },
    loadMethod = {
        cegScaleFactor = 0.7,
        cegName        = "tractorbeam",
        beams = {
            link = { "beam" },
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
