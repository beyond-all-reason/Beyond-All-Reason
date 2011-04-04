-- UNITDEF -- KROGTAAR --
--------------------------------------------------------------------------------

local unitName = "krogtaar"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.144,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.238,
  buildCostEnergy    = 50499,
  buildCostMetal     = 6784,
  builder            = false,
  buildPic           = [[krogtaar.DDS]],
  buildTime          = 101125,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT WEAPON ALL NOTSUB NOTAIR]],
  corpse             = [[dead]],
  defaultmissiontype = [[Standby]],
  description        = [[Heavy Weapons Mech]],
  energyMake         = 3,
  energyStorage      = 0,
  energyUse          = 3,
  explodeAs          = [[CRAWL_BLAST]],
  firestandorders    = 1,
  footprintX         = 4,
  footprintZ         = 4,
  immunetoparalyzer  = 1,
  maneuverleashlength = 640,
  mass               = 1000000000000,
  maxDamage          = 70000,
  maxSlope           = 17,
  maxVelocity        = 1.33,
  maxWaterDepth      = 13,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[HKBOT4]],
  name               = [[KrogTaar]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[krogtaar]],
  radarDistance      = 0,
  selfDestructAs     = [[CRAWL_BLAST]],
  selfDestructCountdown = 10,
  shootme            = 1,
  side               = [[CORE]],
  sightDistance      = 390,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 1058,
  unitname           = [[krogtaar]],
  unitnumber         = 12323,
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
      [[kbcormov]],
    },
    select = {
      [[kbcorsel]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[NOWEAPON]],
      def                = [[COR_TAAR_RC]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  COR_TAAR_RC = {
    accuracy           = 200,
    areaOfEffect       = 64,
    burnblow           = true,
    cegTag             = [[krogtaarblaster]],
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASHKROGTAAR]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    intensity          = 4,
    lineOfSight        = true,
    model              = [[bomb2]],
    name               = [[KrogTaarBlaster]],
    noSelfDamage       = true,
    range              = 465,
    reloadtime         = 0.4,
    renderType         = 4,
    rgbColor           = [[0 0 0]],
    size               = 1,
    soundHit           = [[xplomed3]],
    soundStart         = [[Mavgun2]],
    sprayAngle         = 200,
    startsmoke         = 1,
    tolerance          = 10000,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 400,
    damage = {
      anniddm            = 200,
      default            = 344,
      l1subs             = 5,
      l2subs             = 5,
      l3subs             = 5,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  dead = {
    blocking           = true,
    category           = [[cor_corpses]],
    damage             = 15700,
    description        = [[Wreckage]],
    featureDead        = [[heap]],
    featurereclamate   = [[smudge01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 5990,
    object             = [[krogtaar_dead]],
    reclaimable        = true,
    seqnamereclamate   = [[tree1reclamate]],
    world              = [[All Worlds]],
  },
  heap = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 6960,
    description        = [[Wreckage]],
    featurereclamate   = [[smudge01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 4472,
    object             = [[3x3a]],
    reclaimable        = true,
    seqnamereclamate   = [[tree1reclamate]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
