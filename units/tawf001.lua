-- UNITDEF -- TAWF001 --
--------------------------------------------------------------------------------

local unitName = "tawf001"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  badTargetCategory  = [[VTOL]],
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 32768,
  buildCostEnergy    = 1434,
  buildCostMetal     = 176,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 4,
  buildingGroundDecalSizeY = 4,
  buildingGroundDecalType = [[tawf001_aoplane.dds]],
  buildPic           = [[TAWF001.DDS]],
  buildTime          = 5324,
  canAttack          = true,
  canstop            = 1,
  category           = [[ALL WEAPON NOTSUB NOTAIR]],
  collisionvolumeoffsets = [[0 1 0]], 
  collisionvolumescales = [[33 85 33]],
  collisionvolumetest = 1,
  collisionvolumetype = [[CylY]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[GUARD_NOMOVE]],
  description        = [[Beam Laser Turret]],
  energyStorage      = 60,
  energyUse          = 0,
  explodeAs          = [[MEDIUM_BUILDINGEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  healtime           = 4,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 1290,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Beamer]],
  noAutoFire         = false,
  objectName         = [[TAWF001]],
  seismicSignature   = 0,
  selfDestructAs     = [[MEDIUM_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 475,
  smoothAnim         = false,
  standingfireorder  = 2,
  TEDClass           = [[FORT]],
  turnRate           = 0,
  unitname           = [[tawf001]],
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
      badTargetCategory  = [[VTOL]],
      def                = [[TAWF001_WEAPON]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  TAWF001_WEAPON = {
    areaOfEffect       = 8,
    beamlaser          = 1,
    beamTime           = 0.15,
    coreThickness      = 0.225,
    craterBoost        = 0,
    craterMult         = 0,
    energypershot      = 6,
    explosionGenerator = [[custom:SMALL_BURN_WHITE]],
    fireStarter        = 30,
    impactonly         = 1,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    laserFlareSize     = 12,
    lineOfSight        = true,
    name               = [[BeamLaser]],
    noSelfDamage       = true,
    range              = 475,
    reloadtime         = 0.1,
    renderType         = 0,
    rgbColor           = [[0 0 1]],
    soundHit           = [[burn02]],
    soundStart         = [[build2]],
    soundTrigger       = true,
    targetMoveError    = 0.05,
    thickness          = 2.2,
    tolerance          = 10000,
    turret             = true,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 1000,
    damage = {
      commanders         = 80,
      default            = 40,
      gunships           = 2,
      hgunships          = 2,
      l1bombers          = 2,
      l1fighters         = 2,
      l1subs             = 1,
      l2bombers          = 2,
      l2fighters         = 2,
      l2subs             = 1,
      l3subs             = 1,
      vradar             = 2,
      vtol               = 2,
      vtrans             = 2,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 774,
    description        = [[Beamer Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 50,
    hitdensity         = 100,
    metal              = 114,
    object             = [[TAWF001_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 387,
    description        = [[Beamer Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 46,
    object             = [[2X2A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
