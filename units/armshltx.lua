-- UNITDEF -- ARMSHLTX --
--------------------------------------------------------------------------------

local unitName = "armshltx"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  bmcode             = 0,
  brakeRate          = 0,
  buildCostEnergy    = 54540,
  buildCostMetal     = 7396,
  builder            = true,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 10,
  buildingGroundDecalSizeY = 10,
  buildingGroundDecalType = [[armshltx_aoplane.dds]],
  buildPic           = [[ARMSHLTX.DDS]],
  buildTime          = 61380,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL PLANT NOTSUB NOWEAPON NOTAIR]],
  corpse             = [[ARMSHLT_DEAD]],
  description        = [[Produces Level 3 Units]],
  energyStorage      = 1400,
  energyUse          = 0,
  explodeAs          = [[LARGE_BUILDINGEX]],
  firestandorders    = 1,
  footprintX         = 9,
  footprintZ         = 9,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 14400,
  maxSlope           = 18,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 800,
  mobilestandorders  = 1,
  name               = [[Experimental Gantry]],
  noAutoFire         = false,
  objectName         = [[ARMSHLTX]],
  seismicSignature   = 0,
  selfDestructAs     = [[LARGE_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 273,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  TEDClass           = [[PLANT]],
  turnRate           = 0,
  unitname           = [[armshltx]],
  useBuildingGroundDecal = true,
  workerTime         = 600,
  yardMap            = [[oooooooooooooooooooocccccoooocccccoooocccccoooocccccoooocccccoooocccccoooocccccoo]],
  buildoptions = {
    [[armbanth]],
    [[armraz]],
    [[marauder]],
    [[armshock]],
  },
  sfxtypes = {
    explosiongenerators = {
      [[custom:YellowLight]],
    },
  },
  sounds = {
    activate           = [[gantok2]],
    build              = [[gantok2]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[gantok2]],
    repair             = [[lathelrg]],
    underattack        = [[warning1]],
    unitcomplete       = [[gantok1]],
    working            = [[build]],
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    select = {
      [[gantsel1]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  ARMSHLT_DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 8640,
    description        = [[Experimental Gantry Wreckage]],
    energy             = 0,
    featureDead        = [[ARMSHLT_HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 9,
    footprintZ         = 9,
    height             = 20,
    hitdensity         = 100,
    metal              = 4807,
    object             = [[ARMSHLT_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  ARMSHLT_HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 4320,
    description        = [[Experimental Gantry Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 9,
    footprintZ         = 9,
    height             = 4,
    hitdensity         = 100,
    metal              = 1923,
    object             = [[7X7B]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
