-- UNITDEF -- CORFRAD --
--------------------------------------------------------------------------------

local unitName = "corfrad"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 16384,
  buildCostEnergy    = 1054,
  buildCostMetal     = 123,
  builder            = false,
  buildPic           = [[CORFRAD.DDS]],
  buildTime          = 1783,
  canAttack          = false,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  collisionSphereOffset = [[0 40 0]],
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
  maxDamage          = 103,
  maxSlope           = 10,
  maxVelocity        = 0,
  metalStorage       = 0,
  minWaterDepth      = 5,
  name               = [[Floating Radar Tower]],
  noAutoFire         = false,
  objectName         = [[CORFRAD]],
  onoffable          = true,
  radarDistance      = 2100,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 740,
  smoothAnim         = true,
  TEDClass           = [[SPECIAL]],
  turnRate           = 0,
  unitname           = [[corfrad]],
  waterline          = 4,
  workerTime         = 0,
  yardMap            = [[wwwwwwwww]],
  sounds = {
    activate           = [[radar1]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[radarde1]],
    underattack        = [[warning1]],
    working            = [[radar2]],
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    select = {
      [[radar2]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 62,
    description        = [[Floating Radar Tower Wreckage]],
    energy             = 0,
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 80,
    object             = [[CORFRAD_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
