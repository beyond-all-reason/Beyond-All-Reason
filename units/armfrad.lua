-- UNITDEF -- ARMFRAD --
--------------------------------------------------------------------------------

local unitName = "armfrad"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 16384,
  buildCostEnergy    = 985,
  buildCostMetal     = 127,
  builder            = false,
  buildPic           = [[ARMFRAD.DDS]],
  buildTime          = 1637,
  canAttack          = false,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  collisionSphereScale = 1.1,
  corpse             = [[DEAD]],
  description        = [[Early Warning System]],
  energyMake         = 4,
  energyStorage      = 0,
  energyUse          = 4,
  explodeAs          = [[SMALL_BUILDINGEX]],
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxangledif1       = 1,
  maxDamage          = 99,
  maxSlope           = 10,
  maxVelocity        = 0,
  metalStorage       = 0,
  minWaterDepth      = 5,
  name               = [[Floating Radar Tower]],
  noAutoFire         = false,
  objectName         = [[ARMFRAD]],
  onoffable          = true,
  radarDistance      = 2100,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 760,
  smoothAnim         = false,
  TEDClass           = [[SPECIAL]],
  turnRate           = 0,
  unitname           = [[armfrad]],
  waterline          = 1,
  workerTime         = 0,
  yardMap            = [[wwwwwwwww]],
  sounds = {
    activate           = [[radar1]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[radarde1]],
    underattack        = [[warning1]],
    working            = [[radar1]],
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    select = {
      [[radar1]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 59,
    description        = [[Floating Radar Tower Wreckage]],
    energy             = 0,
    footprintX         = 3,
    footprintZ         = 3,
    height             = 40,
    hitdensity         = 100,
    metal              = 83,
    object             = [[ARMFRAD_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
