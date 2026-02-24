--------------------------------------------------------------------------------
-- CEG Test Projectile Unit written by Steel December 2025
--
-- Overview:
--   This unit definition exists solely to support projectile-based CEG preview
--   functionality for developer and artist tooling (e.g. the CEG Browser).
--
--   It provides a minimal, non-interactive unit that can legally
--   fire a ballistic weapon, allowing Core Effect Generator (CEG) effects to
--   be attached to projectile trails and impacts without affecting gameplay.
--
-- Design goals:
--   - Satisfy Spring engine requirements for projectile weapons
--   - Remain completely non-selectable
--   - Never interact with units, terrain, or game logic
--   - Avoid XP, power, or warning spam in logs
--
-- Behavior:
--   - Spawned temporarily by a synced gadget
--   - Fires a lightweight cannon projectile
--   - Projectile CEGs and impact CEGs are injected at runtime
--   - Unit is cleaned up immediately after preview execution
--
-- Notes:
--   - This unit is NOT intended for gameplay use
--   - It should never be buildable, selectable, or persistent
--   - Visual assets referenced here are placeholders only
--
--------------------------------------------------------------------------------


return {
  ceg_test_projectile_unit = {

    --------------------------------------------------------------------------
    -- REQUIRED BY BAR
    --------------------------------------------------------------------------
    customparams = {
      faction = "NONE",
      is_ceg_test_unit = 1,
    },

    --------------------------------------------------------------------------
    -- Prevent XP / power warnings
    --------------------------------------------------------------------------
    metalcost  = 100,
    energycost = 100,
    buildtime  = 1,
    maxdamage  = 1000000,

    --------------------------------------------------------------------------
    -- Engine-valid but inert
    --------------------------------------------------------------------------
    canmove        = true,
    movementclass = "ABOT3",
    speed          = 0.0001,

    canattack        = true,
    canattackground = true,
    category         = "SURFACE",

    --------------------------------------------------------------------------
    -- Invisible & non-interactive
    --------------------------------------------------------------------------
    drawtype    = 0,
    selectable  = false,
    blocking    = false,
    yardmap     = "o",

    canstop    = false,
    canpatrol  = false,
    canrepeat  = false,

    initcloaked       = true,
    cloakcost         = 0,
    cloakcostmoving   = 0,
    mincloakdistance  = 0,
    stealth           = true,
    sonarstealth      = true,

    --------------------------------------------------------------------------
    -- Keep Spring pipeline intact
    --------------------------------------------------------------------------
    objectname = "Units/CORTHUD.s3o",
    script     = "Units/CORTHUD.cob",

    footprintx = 2,
    footprintz = 2,

    sightdistance    = 0,
    radardistance    = 0,
    seismicsignature = 0,

    --------------------------------------------------------------------------
    -- WEAPON: projectile CEG carrier
    --------------------------------------------------------------------------
    weapondefs = {
      ceg_test_projectile = {
        name        = "CEG Test Projectile",
        weapontype  = "Cannon",

        model = "Objects3D/empty.s3o",
	noshadow	   = true,
        cegtag             = "",
        explosiongenerator = "",

        gravityaffected = true,
        mygravity       = 0.16,

        range          = 50000,
        reloadtime     = 0.1,
        weaponvelocity = 600,

        turret    = true,
        tolerance = 5000,

        collideground = true,
        avoidfriendly = false,
        avoidfeature  = false,

        areaofeffect = 1,
        damage = {
          default = 1,
        },

        craterMult    = 0,
        impulseFactor = 0,
        impulseBoost  = 0,

        soundhit = "",
      },
    },

    weapons = {
      [1] = {
        def = "CEG_TEST_PROJECTILE",
        onlyTargetCategory = "SURFACE",
      },
    },
  },
}
