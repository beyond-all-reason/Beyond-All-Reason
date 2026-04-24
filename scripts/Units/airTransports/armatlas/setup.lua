-- setup.lua
-- All configuration for armatlas.

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
        primarySlot = "link2x2",
        terSeats      = 1,   -- total seat capacity; read by the transport gadget to check available room

        slots = {
            { name = "link2x2",   size = 1, requires = {  } },
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
            link2x2   = { "beam"},
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

        -- Tiers evaluated in order; first tier where severity <= maxSeverity wins.
        -- useJets = true expands to all jet pieces at that sfx level.
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
