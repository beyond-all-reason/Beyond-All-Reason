-- UNITDEF -- CORCARRY --
--------------------------------------------------------------------------------

local unitName = "corcarry"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.025,
  activateWhenBuilt  = true,
  antiweapons        = 1,
  badTargetCategory  = [[NOTAIR]],
  bmcode             = 1,
  brakeRate          = 0.023,
  buildAngle         = 16384,
  buildCostEnergy    = 74715,
  buildCostMetal     = 1579,
  builder            = true,
  buildPic           = [[CORCARRY.DDS]],
  buildTime          = 85271,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND MOBILE NOTSUB SHIP NOWEAPON NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Aircraft Carrier with Anti-Nuke]],
  energyMake         = 250,
  energyStorage      = 1500,
  energyUse          = 25,
  explodeAs          = [[CRAWL_BLAST]],
  firestandorders    = 1,
  floater            = true,
  footprintX         = 6,
  footprintZ         = 6,
  iconType           = [[sea]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  isAirBase          = true,
  maneuverleashlength = 640,
  maxDamage          = 7950,
  maxVelocity        = 2.64,
  metalStorage       = 1500,
  minWaterDepth      = 15,
  mobilestandorders  = 1,
  movementClass      = [[DBOAT6]],
  name               = [[Hive]],
  noAutoFire         = false,
  noChaseCategory    = [[ALL]],
  objectName         = [[CORCARRY]],
  radarDistance      = 2700,
  seismicSignature   = 0,
  selfDestructAs     = [[CRAWL_BLAST]],
  side               = [[CORE]],
  sightDistance      = 1040,
  smoothAnim         = true,
  sonarDistance      = 740,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[SHIP]],
  turnRate           = 210,
  unitname           = [[corcarry]],
  waterline          = 6,
  workerTime         = 1000,
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
      badTargetCategory  = [[NOTAIR]],
      def                = [[FMD_ROCKET]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  FMD_ROCKET = {
    areaOfEffect       = 420,
    avoidFriendly      = false,
    collideFriendly    = false,
    coverage           = 2000,
    craterBoost        = 0,
    craterMult         = 0,
    energypershot      = 7500,
    explosionGenerator = [[custom:FLASH4]],
    fireStarter        = 100,
    flightTime         = 120,
    guidance           = true,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    interceptor        = 1,
    lineOfSight        = true,
    metalpershot       = 150,
    model              = [[fmdmisl]],
    name               = [[Rocket]],
    noautorange        = 1,
    noSelfDamage       = true,
    range              = 72000,
    reloadtime         = 2,
    renderType         = 1,
    selfprop           = true,
    smokedelay         = 0.1,
    smokeTrail         = true,
    soundHit           = [[xplomed4]],
    soundStart         = [[Rockhvy1]],
    startsmoke         = 1,
    stockpile          = true,
    stockpiletime      = 90,
    tolerance          = 4000,
    tracks             = true,
    turnRate           = 99000,
    twoPhase           = true,
    vlaunch            = true,
    weaponAcceleration = 75,
    weaponTimer        = 5,
    weaponType         = [[StarburstLauncher]],
    weaponVelocity     = 3000,
    damage = {
      default            = 1500,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 4770,
    description        = [[Hive Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 1026,
    object             = [[CORCARRY_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2016,
    description        = [[Hive Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 266,
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
