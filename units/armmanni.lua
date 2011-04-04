-- UNITDEF -- ARMMANNI --
--------------------------------------------------------------------------------

local unitName = "armmanni"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.0132,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.1375,
  buildCostEnergy    = 12477,
  buildCostMetal     = 1129,
  builder            = false,
  buildPic           = [[ARMMANNI.DDS]],
  buildTime          = 25706,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL TANK MOBILE WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Mobile Tachyon Weapon]],
  energyMake         = 5.2,
  energyStorage      = 0,
  energyUse          = 5.2,
  explodeAs          = [[ESTOR_BUILDINGEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  leaveTracks        = true,
  maneuverleashlength = 640,
  maxDamage          = 2500,
  maxSlope           = 12,
  maxVelocity        = 1.518,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[TANK3]],
  name               = [[Penetrator]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMMANNI]],
  seismicSignature   = 0,
  selfDestructAs     = [[ESTOR_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 650,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  trackOffset        = 16,
  trackStrength      = 10,
  trackStretch       = 1,
  trackType          = [[StdTank]],
  trackWidth         = 37,
  turnRate           = 151,
  unitname           = [[armmanni]],
  workerTime         = 0,
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
      [[tarmmove]],
    },
    select = {
      [[tarmsel]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[ATAM]],
      mainDir            = [[0 0 1]],
      maxAngleDif        = 180,
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ATAM = {
    areaOfEffect       = 12,
    beamlaser          = 1,
    beamTime           = 0.3,
    coreThickness      = 0.3,
    craterBoost        = 0,
    craterMult         = 0,
    energypershot      = 1000,
    explosionGenerator = [[custom:FLASH3blue]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    laserFlareSize     = 20,
    lineOfSight        = true,
    name               = [[ATAM]],
    noSelfDamage       = true,
    range              = 950,
    reloadtime         = 5.5,
    renderType         = 0,
    rgbColor           = [[0 0 1]],
    soundHit           = [[xplolrg1]],
    soundStart         = [[annigun1]],
    targetMoveError    = 0.3,
    thickness          = 5.5,
    tolerance          = 10000,
    turret             = true,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 1500,
    damage = {
      blackhydra         = 4000,
      commanders         = 1000,
      default            = 2500,
      l1subs             = 5,
      l2subs             = 5,
      l3subs             = 5,
      seadragon          = 4000,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 1800,
    description        = [[Penetrator Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 734,
    object             = [[ARMMANNI_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 900,
    description        = [[Penetrator Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 294,
    object             = [[3X3C]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
