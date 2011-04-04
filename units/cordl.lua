-- UNITDEF -- CORDL --
--------------------------------------------------------------------------------

local unitName = "cordl"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  badTargetCategory  = [[NOTSUB]],
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 16384,
  buildCostEnergy    = 2340,
  buildCostMetal     = 280,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 4,
  buildingGroundDecalSizeY = 4,
  buildingGroundDecalType = [[cordl_aoplane.dds]],
  buildPic           = [[CORDL.DDS]],
  buildTime          = 4280,
  canAttack          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[GUARD_NOMOVE]],
  description        = [[Depthcharge Launcher]],
  energyMake         = 0.1,
  energyStorage      = 0,
  energyUse          = 0.1,
  explodeAs          = [[SMALL_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 1075,
  maxSlope           = 15,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Jellyfish]],
  noAutoFire         = false,
  objectName         = [[CORDL]],
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[CORE]],
  sightDistance      = 611,
  smoothAnim         = true,
  sonarDistance      = 525,
  standingfireorder  = 2,
  TEDClass           = [[WATER]],
  turnRate           = 0,
  unitname           = [[cordl]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[oooo]],
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
      [[servmed2]],
    },
    select = {
      [[servmed2]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[NOTSUB]],
      def                = [[COAX_DEPTHCHARGE]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  COAX_DEPTHCHARGE = {
    avoidFriendly      = false,
    bouncerebound      = 0.6,
    bounceslip         = 0.6,
    burnblow           = true,
    collideFriendly    = false,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH2]],
    groundbounce       = true,
    guidance           = true,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    model              = [[depthcharge]],
    name               = [[DepthCharge]],
    noSelfDamage       = true,
    numbounce          = 1,
    propeller          = 1,
    range              = 580,
    reloadtime         = 1.8,
    renderType         = 1,
    selfprop           = true,
    soundHit           = [[xplodep2]],
    soundStart         = [[torpedo1]],
    startVelocity      = 250,
    tracks             = true,
    turnRate           = 18000,
    turret             = true,
    waterWeapon        = true,
    weaponAcceleration = 25,
    weaponTimer        = 6,
    weaponType         = [[TorpedoLauncher]],
    weaponVelocity     = 350,
    damage = {
      commanders         = 500,
      default            = 250,
      dl                 = 5,
      krogoth            = 500,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 645,
    description        = [[Jellyfish Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 30,
    hitdensity         = 100,
    metal              = 182,
    object             = [[CORDL_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 323,
    description        = [[Jellyfish Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 73,
    object             = [[3X3B]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
