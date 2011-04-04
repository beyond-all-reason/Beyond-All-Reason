-- UNITDEF -- CORESUPP --
--------------------------------------------------------------------------------

local unitName = "coresupp"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.072,
  activateWhenBuilt  = true,
  bmcode             = 1,
  brakeRate          = 0.019,
  buildAngle         = 16384,
  buildCostEnergy    = 1912,
  buildCostMetal     = 367,
  builder            = false,
  buildPic           = [[CORESUPP.DDS]],
  buildTime          = 6660,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL WEAPON SHIP NOTSUB NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Corvette]],
  energyMake         = 1,
  energyStorage      = 0,
  energyUse          = 1,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  floater            = true,
  footprintX         = 4,
  footprintZ         = 4,
  iconType           = [[sea]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 1700,
  maxVelocity        = 3.2,
  metalStorage       = 0,
  minWaterDepth      = 12,
  mobilestandorders  = 1,
  movementClass      = [[BOAT4]],
  name               = [[Supporter]],
  noAutoFire         = false,
  objectName         = [[CORESUPP]],
  scale              = 0.5,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 429,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[SHIP]],
  turnRate           = 528,
  unitname           = [[coresupp]],
  waterline          = 3,
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
      [[shcormov]],
    },
    select = {
      [[shcorsel]],
    },
  },
  weapons = {
    [1]  = {
      def                = [[CORVETTE_LIGHTLASER]],
    },
    [2]  = {
      def                = [[CORVETTE_LIGHTLASER]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORVETTE_LIGHTLASER = {
    areaOfEffect       = 12,
    beamlaser          = 1,
    beamTime           = 0.12,
    coreThickness      = 0.175,
    craterBoost        = 0,
    craterMult         = 0,
    energypershot      = 20,
    explosionGenerator = [[custom:SMALL_RED_BURN]],
    fireStarter        = 30,
    impactonly         = 1,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    laserFlareSize     = 10,
    lineOfSight        = true,
    name               = [[LightLaser]],
    noSelfDamage       = true,
    range              = 320,
    reloadtime         = 0.71,
    renderType         = 0,
    rgbColor           = [[1 0 0]],
    soundHit           = [[lasrhit2]],
    soundStart         = [[lasrfir3]],
    soundTrigger       = true,
    targetMoveError    = 0.1,
    thickness          = 2.5,
    tolerance          = 10000,
    turret             = true,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 2250,
    damage = {
      commanders         = 70,
      default            = 52,
      gunships           = 3,
      hgunships          = 3,
      l1bombers          = 5,
      l1fighters         = 5,
      l1subs             = 3,
      l2bombers          = 5,
      l2fighters         = 5,
      l2subs             = 3,
      l3subs             = 3,
      vradar             = 5,
      vtol               = 5,
      vtrans             = 5,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 1020,
    description        = [[Supporter Wreckage]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 239,
    object             = [[CORESUPP_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
