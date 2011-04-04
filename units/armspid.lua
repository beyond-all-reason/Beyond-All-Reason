-- UNITDEF -- ARMSPID --
--------------------------------------------------------------------------------

local unitName = "armspid"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.18,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.188,
  buildCostEnergy    = 3170,
  buildCostMetal     = 166,
  builder            = false,
  buildPic           = [[ARMSPID.DDS]],
  buildTime          = 5090,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL TANK MOBILE WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[All-terrain EMP Bot]],
  energyMake         = 0.7,
  energyStorage      = 0,
  energyUse          = 0.7,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 750,
  maxVelocity        = 2.65,
  maxWaterDepth      = 16,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[TKBOT3]],
  name               = [[Spider]],
  noAutoFire         = false,
  noChaseCategory    = [[ALL]],
  objectName         = [[ARMSPID]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 360,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  turnRate           = 1122,
  unitname           = [[armspid]],
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
      [[spider2]],
    },
    select = {
      [[spider]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[SPIDER]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  SPIDER = {
    areaOfEffect       = 8,
    beamlaser          = 1,
    beamTime           = 0.1,
    coreThickness      = 0.2,
    craterBoost        = 0,
    craterMult         = 0,
    duration           = 0.01,
    explosionGenerator = [[custom:EMPFLASH20]],
    impactonly         = 1,
    impulseBoost       = 0,
    impulseFactor      = 0,
    laserFlareSize     = 6,
    lineOfSight        = true,
    minbarrelangle     = 0,
    name               = [[Paralyzer]],
    noSelfDamage       = true,
    paralyzer          = true,
    paralyzeTime       = 9,
    range              = 220,
    reloadtime         = 1.75,
    renderType         = 0,
    rgbColor           = [[1 1 0]],
    soundHit           = [[lashit]],
    soundStart         = [[hackshot]],
    soundTrigger       = true,
    targetMoveError    = 0.3,
    thickness          = 1,
    turret             = true,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 800,
    damage = {
      blackhydra         = 30,
      commanders         = 30,
      default            = 1750,
      krogoth            = 30,
      seadragon          = 30,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 450,
    description        = [[Spider Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 40,
    hitdensity         = 100,
    metal              = 108,
    object             = [[ARMSPID_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 225,
    description        = [[Spider Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 43,
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
