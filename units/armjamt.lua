-- UNITDEF -- ARMJAMT --
--------------------------------------------------------------------------------

local unitName = "armjamt"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 4382,
  buildCostEnergy    = 7945,
  buildCostMetal     = 226,
  builder            = false,
  buildPic           = [[ARMJAMT.DDS]],
  buildTime          = 9955,
  canAttack          = false,
  category           = [[ALL NOTSUB NOWEAPON JAM SPECIAL NOTAIR]],
  cloakCost          = 25,
  corpse             = [[DEAD]],
  description        = [[Cloakable Jammer Tower]],
  energyMake         = 0,
  energyStorage      = 0,
  energyUse          = 40,
  explodeAs          = [[BIG_UNITEX]],
  footprintX         = 2,
  footprintZ         = 2,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  initCloaked        = false,
  maxangledif1       = 1,
  maxDamage          = 712,
  maxSlope           = 32,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  minCloakDistance   = 35,
  name               = [[Sneaky Pete]],
  noAutoFire         = false,
  objectName         = [[ARMJAMT]],
  onoffable          = true,
  radarDistanceJam   = 500,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 195,
  smoothAnim         = true,
  TEDClass           = [[SPECIAL]],
  turnRate           = 0,
  unitname           = [[armjamt]],
  workerTime         = 0,
  yardMap            = [[oooo]],
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
      [[kbarmmov]],
    },
    select = {
      [[radjam1]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 427,
    description        = [[Sneaky Pete Wreckage]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 3,
    hitdensity         = 100,
    metal              = 147,
    object             = [[ARMJAMT_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[all]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
