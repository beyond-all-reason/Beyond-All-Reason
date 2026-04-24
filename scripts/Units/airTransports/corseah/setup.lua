-- setup.lua
-- All configuration for corseah.

return {

    -- -------------------------------------------------------------------------
    -- Cargo hardpoint configuration.
    -- Slot sizes map to unit footprints:
    --   footprint <= 2  → 1 seat  (fits a 2x2 unit)
    --   footprint <= 4  → 4 seats (fits a 4x4 unit)
    -- "requires": slot names that must be unoccupied for this slot to accept cargo.
    --   link4x4 needs all four 2x2 sub-slots free (they share the same physical space).
    --   Each 2x2 sub-slot needs link4x4 free for the same reason.
    cargo = {
        primarySlot = "flink4x4",
        terSeats      = 8,   -- total seat capacity; read by the transport gadget to check available room

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

    -- -------------------------------------------------------------------------
    -- Tractor-beam load method configuration.
    loadMethod = {
        cegScaleFactor = 0.7,   -- scales the beam direction vector passed to SpawnCEG, which weirdly affects the length of the CEG
        cegName        = "tractorbeam", -- placeholder CEG
        cruiseHeight   = 150,   -- elmos above terrain; also used by engine as approach altitude

        -- Beam emitter pieces per slot name, used as CEG origin points for the tractor-beam VFX.
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

    -- -------------------------------------------------------------------------
    -- Animation configuration.
    -- Piece names are resolved to IDs at runtime by GenericAnimator.Init().
    -- SFX constants are available as globals in the unit script environment.
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

        -- Tiers evaluated in order; first tier where severity <= maxSeverity wins.
        -- useJets = true expands to all jet pieces at that sfx level.
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
