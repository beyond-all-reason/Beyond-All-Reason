return {
    cargo = {
        primarySlot = "link4x4",
        transporterSeats      = 4,

        slots = {
		-- 4 sized
            { name = "link4x4",   size = 4, requires = { "flink3x3", "blink3x3", "rlink3x3", "llink3x3", "frlink2x2", "fllink2x2", "brlink2x2", "bllink2x2" } },
		-- 2 sized
	    { name = "flink3x3", size = 2, requires = { "link4x4", "rlink3x3", "llink3x3", "frlink2x2", "fllink2x2" } },
	    { name = "blink3x3", size = 2, requires = { "link4x4", "rlink3x3", "llink3x3", "brlink2x2", "bllink2x2" } },
	    { name = "rlink3x3", size = 2, requires = { "link4x4", "flink3x3", "blink3x3", "frlink2x2", "brlink2x2" } },
	    { name = "llink3x3", size = 2, requires = { "link4x4", "flink3x3", "blink3x3", "fllink2x2", "bllink2x2" } },
		-- 1 sized
            { name = "frlink2x2", size = 1, requires = { "link4x4", "flink3x3", "rlink3x3" } },
            { name = "fllink2x2", size = 1, requires = { "link4x4", "flink3x3", "llink3x3" } },
            { name = "brlink2x2", size = 1, requires = { "link4x4", "blink3x3", "rlink3x3" } },
            { name = "bllink2x2", size = 1, requires = { "link4x4", "blink3x3", "llink3x3" } },
        },
    },
    loadMethod = {
        cegScaleFactor = 0.7,
        cegName        = "tractorbeam",
        beams = {
		-- 4 sized
            link4x4   = { "brbeam", "blbeam", "frbeam", "flbeam" },
		-- 2 sized
	    flink3x3 = { "flbeam", "frbeam" },
	    blink3x3 = { "blbeam", "brbeam" },
	    rlink3x3 = { "frbeam", "brbeam" },
	    llink3x3 = { "flbeam", "blbeam" },
		-- 1 sized
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
            "thrustb", "thrusta",
        },
        jets = {
        },
        moveRate = {
        },
        killed = {
            { maxSeverity = 25,  wreck = 1, pieces = {
                { name="base",  sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
            { maxSeverity = 50,  wreck = 2, pieces = {
                { name="base",  sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
            { maxSeverity = 100, wreck = 3, pieces = {
                { name="base",  sfx = "BITMAPONLY|NO_HEATCLOUD" },
            }},
        },
    },
	wpn = {
	aimFromPiece = "flare",
	aimPiece = "barrel",
	firePiece = "flare",
	},
}
