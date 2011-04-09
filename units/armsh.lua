-- UNITDEF -- ARMSH --
--------------------------------------------------------------------------------

local unitName = "armsh"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.132,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.112,
  buildCostEnergy    = 1344,
  buildCostMetal     = 87,
  builder            = false,
  buildPic           = [[ARMSH.DDS]],
  buildTime          = 3896,
  canAttack          = true,
  canGuard           = true,
  canHover           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL HOVER MOBILE WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Fast Attack Hovercraft]],
  energyMake         = 2.6,
  energyStorage      = 0,
  energyUse          = 2.6,
  explodeAs          = [[SMALL_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 260,
  maxSlope           = 16,
  maxVelocity        = 4.49,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[HOVER3]],
  name               = [[Skimmer]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMSH]],
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[ARM]],
  sightDistance      = 582,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  turnRate           = 640,
  unitname           = [[armsh]],
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
      [[hovsmok1]],
    },
    select = {
      [[hovsmsl1]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[ARMSH_WEAPON]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMSH_WEAPON = {
    areaOfEffect       = 8,
    beamlaser          = 1,
    beamTime           = 0.1,
    burstrate          = 0.2,
    color              = 232,
    color2             = 234,
    craterBoost        = 0,
    craterMult         = 0,
    duration           = 0.02,
    energypershot      = 3,
    explosionGenerator = [[custom:FLASH1nd]],
    fireStarter        = 50,
    impactonly         = 1,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    name               = [[Laser]],
    noSelfDamage       = true,
    range              = 230,
    reloadtime         = 0.6,
    renderType         = 0,
    soundHit           = [[lashit]],
    soundStart         = [[lasrfast]],
    soundTrigger       = true,
    targetMoveError    = 0.3,
    thickness          = 1.25,
    turret             = true,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 450,
    damage = {
      default            = 48,
      gunships           = 6,
      hgunships          = 6,
      l1subs             = 2,
      l2subs             = 2,
      l3subs             = 2,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 185,
    description        = [[Skimmer Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 49,
    object             = [[ARMSH_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 93,
    description        = [[Skimmer Heap]],
    energy             = 0,
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 20,
    object             = [[3X3D]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
