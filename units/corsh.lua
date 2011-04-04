-- UNITDEF -- CORSH --
--------------------------------------------------------------------------------

local unitName = "corsh"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.12,
  bmcode             = 1,
  brakeRate          = 0.112,
  buildCostEnergy    = 1439,
  buildCostMetal     = 71,
  builder            = false,
  buildPic           = [[CORSH.DDS]],
  buildTime          = 4079,
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
  maxDamage          = 230,
  maxSlope           = 16,
  maxVelocity        = 4.26,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[HOVER3]],
  name               = [[Scrubber]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORSH]],
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[CORE]],
  sightDistance      = 509,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  turnRate           = 615,
  unitname           = [[corsh]],
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
      [[hovsmok2]],
    },
    select = {
      [[hovsmsl2]],
    },
  },
  weapons = {
    [1]  = {
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
    damage             = 162,
    description        = [[Scrubber Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 40,
    object             = [[CORSH_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 81,
    description        = [[Scrubber Heap]],
    energy             = 0,
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 16,
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
