-- UNITDEF -- MADSAM --
--------------------------------------------------------------------------------

local unitName = "madsam"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  airSightDistance   = 700,
  badTargetCategory  = [[NOTAIR]],
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 5750,
  buildCostMetal     = 295,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 5,
  buildingGroundDecalSizeY = 5,
  buildingGroundDecalType = [[madsam_aoplane.dds]],
  buildPic           = [[MADSAM.DDS]],
  buildTime          = 5237,
  canAttack          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[GUARD_NOMOVE]],
  description        = [[Hardened Missile Battery]],
  energyStorage      = 0,
  energyUse          = 5,
  explodeAs          = [[LARGE_BUILDINGEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 2500,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[SAM]],
  noAutoFire         = false,
  objectName         = [[MADSAM]],
  seismicSignature   = 0,
  selfDestructAs     = [[LARGE_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 375,
  smoothAnim         = true,
  standingfireorder  = 2,
  TEDClass           = [[FORT]],
  turnRate           = 0,
  unitname           = [[madsam]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[ooooooooo]],
  sounds = {
    canceldestruct     = [[cancel2]],
    cloak              = [[kloak1]],
    uncloak            = [[kloak1un]],
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
      [[twrturn3]],
    },
    select = {
      [[twrturn3]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[NOTAIR]],
      def                = [[MADSAM_MISSILE]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  MADSAM_MISSILE = {
    areaOfEffect       = 16,
    burnblow           = true,
    burst              = 4,
    burstrate          = 0.2,
    canattackground    = false,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH2]],
    fireStarter        = 72,
    flightTime         = 2,
    guidance           = true,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    model              = [[missile]],
    name               = [[AA2Missile]],
    noSelfDamage       = true,
    proximityPriority  = 1,
    range              = 840,
    reloadtime         = 2.55,
    renderType         = 1,
    selfprop           = true,
    smokedelay         = 0.1,
    smokeTrail         = true,
    soundHit           = [[packohit]],
    soundStart         = [[packolau]],
    soundTrigger       = true,
    startsmoke         = 1,
    startVelocity      = 520,
    texture2           = [[coresmoketrail]],
    toAirWeapon        = true,
    tolerance          = 9950,
    tracks             = true,
    turnRate           = 68000,
    turret             = true,
    weaponAcceleration = 160,
    weaponTimer        = 2,
    weaponType         = [[MissileLauncher]],
    weaponVelocity     = 820,
    damage = {
      default            = 113,
      gunships           = 72,
      hgunships          = 72,
      l1subs             = 5,
      l2subs             = 5,
      l3subs             = 5,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 1500,
    description        = [[SAM Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 10,
    hitdensity         = 100,
    metal              = 257,
    object             = [[MADSAM_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[all]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 750,
    description        = [[SAM Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    hitdensity         = 100,
    metal              = 103,
    object             = [[2X2C]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[all]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
