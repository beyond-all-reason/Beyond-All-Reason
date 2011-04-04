-- UNITDEF -- ARMPINCER --
--------------------------------------------------------------------------------

local unitName = "armpincer"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.011,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.011,
  buildCostEnergy    = 1921,
  buildCostMetal     = 187,
  builder            = false,
  buildPic           = [[ARMPINCER.DDS]],
  buildTime          = 2613,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL TANK PHIB WEAPON NOTSUB NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Light Amphibious Tank]],
  energyMake         = 0.5,
  energyStorage      = 0,
  energyUse          = 0.5,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  leaveTracks        = true,
  maneuverleashlength = 650,
  maxDamage          = 1148,
  maxSlope           = 15,
  maxVelocity        = 2.25,
  maxWaterDepth      = 125,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[ATANK3]],
  name               = [[Pincer]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMPINCER]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 240,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  trackOffset        = 3,
  trackStrength      = 6,
  trackStretch       = 1,
  trackType          = [[StdTank]],
  trackWidth         = 30,
  turnRate           = 398,
  unitname           = [[armpincer]],
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
      def                = [[ARM_PINCER_GAUSS]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARM_PINCER_GAUSS = {
    areaOfEffect       = 8,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:LIGHT_PLASMA]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    name               = [[PincerCannon]],
    noSelfDamage       = true,
    range              = 305,
    reloadtime         = 1.5,
    renderType         = 4,
    soundHit           = [[xplomed2]],
    soundStart         = [[cannhvy1]],
    startsmoke         = 1,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 450,
    damage = {
      default            = 116,
      gunships           = 25,
      hgunships          = 25,
      l1bombers          = 25,
      l1fighters         = 25,
      l1subs             = 5,
      l2bombers          = 25,
      l2fighters         = 25,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 25,
      vtol               = 25,
      vtrans             = 25,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 689,
    description        = [[Pincer Wreckage]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 9,
    hitdensity         = 100,
    metal              = 122,
    object             = [[ARMPINCER_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[all]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
