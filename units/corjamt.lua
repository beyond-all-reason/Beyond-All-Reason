-- UNITDEF -- CORJAMT --
--------------------------------------------------------------------------------

local unitName = "corjamt"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 9821,
  buildCostEnergy    = 4791,
  buildCostMetal     = 109,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 4,
  buildingGroundDecalSizeY = 4,
  buildingGroundDecalType = [[corjamt_aoplane.dds]],
  buildPic           = [[CORJAMT.DDS]],
  buildTime          = 4577,
  canAttack          = false,
  category           = [[ALL NOTSUB JAM NOWEAPON SPECIAL NOTAIR]],
  corpse             = [[DEAD]],
  description        = [[Short-Range Jamming Device]],
  energyMake         = 0,
  energyStorage      = 0,
  energyUse          = 25,
  explodeAs          = [[BIG_UNITEX]],
  footprintX         = 2,
  footprintZ         = 2,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxangledif1       = 1,
  maxDamage          = 960,
  maxSlope           = 32,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Castro]],
  noAutoFire         = false,
  objectName         = [[CORJAMT]],
  onoffable          = true,
  radarDistanceJam   = 360,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 104,
  smoothAnim         = false,
  TEDClass           = [[SPECIAL]],
  turnRate           = 0,
  unitname           = [[corjamt]],
  useBuildingGroundDecal = true,
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
      [[kbcormov]],
    },
    select = {
      [[radjam2]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 576,
    description        = [[Castro Wreckage]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 3,
    hitdensity         = 100,
    metal              = 71,
    object             = [[CORJAMT_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[all]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
