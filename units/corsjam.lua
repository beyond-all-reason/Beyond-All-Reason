-- UNITDEF -- CORSJAM --
--------------------------------------------------------------------------------

local unitName = "corsjam"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.096,
  activateWhenBuilt  = true,
  badTargetCategory  = [[MOBILE]],
  bmcode             = 1,
  brakeRate          = 0.022,
  buildCostEnergy    = 2254,
  buildCostMetal     = 135,
  builder            = false,
  buildPic           = [[CORSJAM.DDS]],
  buildTime          = 7025,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND MOBILE NOTSUB SHIP NOWEAPON NOTAIR]],
  collisionVolumeScales = [[31 14 71]],
  collisionVolumeOffsets= [[0 -1 0]],
  collisionVolumeTest = 1,
  collisionVolumeType = [[CylY]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Radar Jammer Ship]],
  energyMake         = 20,
  energyStorage      = 0,
  energyUse          = 20,
  explodeAs          = [[SMALL_UNITEX]],
  floater            = true,
  footprintX         = 4,
  footprintZ         = 4,
  iconType           = [[sea]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 570,
  maxVelocity        = 2.88,
  metalStorage       = 0,
  minWaterDepth      = 6,
  mobilestandorders  = 1,
  movementClass      = [[BOAT4]],
  name               = [[Phantom]],
  noAutoFire         = false,
  noChaseCategory    = [[MOBILE]],
  objectName         = [[CORSJAM]],
  onoffable          = true,
  radarDistanceJam   = 900,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[CORE]],
  sightDistance      = 403,
  smoothAnim         = false,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[SHIP]],
  turnRate           = 512,
  unitname           = [[corsjam]],
  waterline          = 2,
  windgenerator      = 0.001,
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
      [[radjam2]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[MOBILE]],
      def                = [[BOGUS_GROUND_MISSILE]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  BOGUS_GROUND_MISSILE = {
    areaOfEffect       = 48,
    craterBoost        = 0,
    craterMult         = 0,
    impulseBoost       = 0,
    impulseFactor      = 0,
    lineOfSight        = true,
    metalpershot       = 0,
    name               = [[Missiles]],
    range              = 800,
    reloadtime         = 0.5,
    renderType         = 1,
    startVelocity      = 450,
    tolerance          = 9000,
    turnRate           = 33000,
    turret             = true,
    weaponAcceleration = 101,
    weaponTimer        = 0.1,
    weaponType         = [[Cannon]],
    weaponVelocity     = 650,
    damage = {
      default            = 0,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 342,
    description        = [[Phantom Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 4,
    footprintZ         = 4,
    height             = 20,
    hitdensity         = 100,
    metal              = 88,
    object             = [[CORSJAM_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2016,
    description        = [[Phantom Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 46,
    object             = [[4X4A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
