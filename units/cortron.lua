-- UNITDEF -- CORTRON --
--------------------------------------------------------------------------------

local unitName = "cortron"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  antiweapons        = 1,
  badTargetCategory  = [[NOTLAND]],
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 13067,
  buildCostMetal     = 754,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 6,
  buildingGroundDecalSizeY = 6,
  buildingGroundDecalType = [[cortron_aoplane.dds]],
  buildPic           = [[CORTRON.DDS]],
  buildTime          = 58927,
  canAttack          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  description        = [[Tactical Nuke Launcher]],
  energyStorage      = 0,
  energyUse          = 0,
  explodeAs          = [[ATOMIC_BLAST]],
  firestandorders    = 1,
  footprintX         = 4,
  footprintZ         = 4,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 3200,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Catalyst]],
  noAutoFire         = false,
  objectName         = [[CORTRON]],
  seismicSignature   = 0,
  selfDestructAs     = [[NUCLEAR_MISSILE]],
  side               = [[CORE]],
  sightDistance      = 455,
  smoothAnim         = true,
  standingfireorder  = 0,
  TEDClass           = [[SPECIAL]],
  turnRate           = 0,
  unitname           = [[cortron]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[oooooooooooooooo]],
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
      [[servroc1]],
    },
    select = {
      [[servroc1]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[NOTLAND]],
      def                = [[CORTRON_WEAPON]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORTRON_WEAPON = {
    areaOfEffect       = 512,
    commandfire        = true,
    craterBoost        = 4,
    craterMult         = 1.75,
    edgeEffectiveness  = 0.4,
    energypershot      = 17437,
    explosionGenerator = [[custom:FLASHNUKE480]],
    fireStarter        = 0,
    flightTime         = 400,
    guidance           = true,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    metalpershot       = 550,
    model              = [[empmisl]],
    name               = [[TacticalNuke]],
    noautorange        = 1,
    noSelfDamage       = true,
    propeller          = 1,
    range              = 3000,
    reloadtime         = 2,
    renderType         = 1,
    selfprop           = true,
    shakeduration      = 1.5,
    shakemagnitude     = 32,
    smokedelay         = 0.1,
    smokeTrail         = true,
    soundHit           = [[xplomed4]],
    soundStart         = [[misicbm1]],
    startsmoke         = 1,
    stockpile          = true,
    stockpiletime      = 75,
    tolerance          = 4000,
    turnRate           = 32768,
    twoPhase           = true,
    vlaunch            = true,
    weaponAcceleration = 180,
    weaponTimer        = 4,
    weaponType         = [[StarburstLauncher]],
    weaponVelocity     = 1200,
    damage = {
      commanders         = 499,
      default            = 2500,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 1920,
    description        = [[Catalyst Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 445,
    object             = [[CORTRON_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 960,
    description        = [[Catalyst Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 178,
    object             = [[3X3A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
