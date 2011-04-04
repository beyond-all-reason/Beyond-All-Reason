-- UNITDEF -- ARMSJAM --
--------------------------------------------------------------------------------

local unitName = "armsjam"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.09,
  activateWhenBuilt  = true,
  badTargetCategory  = [[MOBILE]],
  bmcode             = 1,
  brakeRate          = 0.02,
  buildCostEnergy    = 1928,
  buildCostMetal     = 131,
  builder            = false,
  buildPic           = [[ARMSJAM.DDS]],
  buildTime          = 6708,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND MOBILE NOTSUB NOWEAPON SHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Radar Jammer Ship]],
  energyMake         = 18,
  energyStorage      = 0,
  energyUse          = 18,
  explodeAs          = [[SMALL_UNITEX]],
  floater            = true,
  footprintX         = 4,
  footprintZ         = 4,
  iconType           = [[sea]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 510,
  maxVelocity        = 3.1,
  metalStorage       = 0,
  minWaterDepth      = 6,
  mobilestandorders  = 1,
  movementClass      = [[BOAT4]],
  name               = [[Escort]],
  noAutoFire         = false,
  noChaseCategory    = [[MOBILE]],
  objectName         = [[ARMSJAM]],
  onoffable          = true,
  radarDistanceJam   = 980,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[ARM]],
  sightDistance      = 390,
  smoothAnim         = true,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[SHIP]],
  turnRate           = 540,
  unitname           = [[armsjam]],
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
      [[sharmmov]],
    },
    select = {
      [[radjam1]],
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
    damage             = 306,
    description        = [[Escort Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 4,
    footprintZ         = 4,
    height             = 40,
    hitdensity         = 100,
    metal              = 85,
    object             = [[ARMSJAM_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2016,
    description        = [[Escort Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 23,
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
