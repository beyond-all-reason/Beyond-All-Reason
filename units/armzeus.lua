-- UNITDEF -- ARMZEUS --
--------------------------------------------------------------------------------

local unitName = "armzeus"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.12,
  bmcode             = 1,
  brakeRate          = 0.25,
  buildCostEnergy    = 5668,
  buildCostMetal     = 329,
  builder            = false,
  buildPic           = [[ARMZEUS.DDS]],
  buildTime          = 7252,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT MOBILE WEAPON ALL NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Assault Kbot]],
  energyMake         = 3.5,
  energyStorage      = 0,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 2975,
  maxSlope           = 15,
  maxVelocity        = 1.58,
  maxWaterDepth      = 23,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[KBOT2]],
  name               = [[Zeus]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMZEUS]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 331.5,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 1056,
  unitname           = [[armzeus]],
  upright            = true,
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
      [[kbarmmov]],
    },
    select = {
      [[kbarmsel]],
    },
  },
  weapons = {
    [1]  = {
      def                = [[LIGHTNING]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  LIGHTNING = {
    areaOfEffect       = 8,
    beamWeapon         = true,
    color              = 128,
    color2             = 130,
    craterBoost        = 0,
    craterMult         = 0,
    duration           = 10,
    energypershot      = 35,
    explosionGenerator = [[custom:ZEUS_FLASH]],
    fireStarter        = 50,
    impactonly         = 1,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    intensity          = 12,
    lineOfSight        = true,
    name               = [[LightningGun]],
    noSelfDamage       = true,
    range              = 280,
    reloadtime         = 1.7,
    renderType         = 7,
    rgbColor           = [[0.5 0.5 1]],
    soundHit           = [[xplomed3]],
    soundStart         = [[lghthvy1]],
    soundTrigger       = true,
    startsmoke         = 1,
    targetMoveError    = 0.3,
    texture1           = [[lightning]],
    thickness          = 10,
    turret             = true,
    weaponType         = [[LightningCannon]],
    weaponVelocity     = 400,
    damage = {
      default            = 220,
      gunships           = 65,
      hgunships          = 65,
      l1bombers          = 65,
      l1fighters         = 65,
      l1subs             = 5,
      l2bombers          = 65,
      l2fighters         = 65,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 65,
      vtol               = 65,
      vtrans             = 65,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 1110,
    description        = [[Zeus Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 214,
    object             = [[ARMZEUS_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 555,
    description        = [[Zeus Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 86,
    object             = [[2X2E]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
