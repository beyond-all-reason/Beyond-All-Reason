-- UNITDEF -- COREYES --
--------------------------------------------------------------------------------

local unitName = "coreyes"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 800,
  buildCostMetal     = 30,
  builder            = false,
  buildPic           = [[COREYES.DDS]],
  buildTime          = 750,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  cloakCost          = 10,
  corpse             = [[CDRAGONSEYES_DEAD]],
  description        = [[Perimeter Camera]],
  energyMake         = 0,
  energyStorage      = 0,
  energyUse          = 5,
  footprintX         = 1,
  footprintZ         = 1,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  initCloaked        = true,
  levelGround        = false,
  maxDamage          = 250,
  maxSlope           = 24,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  minCloakDistance   = 36,
  name               = [[Dragon's Eye]],
  noAutoFire         = false,
  objectName         = [[COREYES]],
  onoffable          = false,
  seismicSignature   = 0,
  side               = [[CORE]],
  sightDistance      = 540,
  smoothAnim         = true,
  stealth            = true,
  TEDClass           = [[FORT]],
  turnRate           = 0,
  unitname           = [[coreyes]],
  workerTime         = 0,
  yardMap            = [[o]],
  sounds = {
    canceldestruct     = [[cancel2]],
    underattack        = [[warning1]],
    cant = {
      [[cantdo4]],
    },
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    ok = {
      [[servsml6]],
    },
    select = {
      [[minesel2]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  CDRAGONSEYES_DEAD = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 120,
    description        = [[Dragon's Eye Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 1,
    footprintZ         = 1,
    height             = 4,
    hitdensity         = 100,
    metal              = 12,
    object             = [[1X1B]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
