-- UNITDEF -- ARMVADER --
--------------------------------------------------------------------------------

local unitName = "armvader"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.132,
  activateWhenBuilt  = true,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.162,
  buildCostEnergy    = 5473,
  buildCostMetal     = 61,
  builder            = false,
  buildPic           = [[ARMVADER.DDS]],
  buildTime          = 7901,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT MOBILE WEAPON ALL NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[CORPSE]],
  defaultmissiontype = [[Standby]],
  description        = [[Crawling Bomb]],
  energyMake         = 0.1,
  energyStorage      = 0,
  energyUse          = 0.1,
  explodeAs          = [[CRAWL_BLASTSML]],
  firestandorders    = 1,
  firestate          = 2,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  mass               = 1500,
  maxDamage          = 400,
  maxSlope           = 32,
  maxVelocity        = 2.8,
  maxWaterDepth      = 112,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[AKBOT2]],
  name               = [[Invader]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMVADER]],
  seismicSignature   = 0,
  selfDestructAs     = [[CRAWL_BLAST]],
  selfDestructCountdown = 0,
  side               = [[ARM]],
  sightDistance      = 273,
  smoothAnim         = true,
  standingfireorder  = 0,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[KBOT]],
  turninplace        = 0,
  turnRate           = 1540,
  unitname           = [[armvader]],
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
      [[servsml5]],
    },
    select = {
      [[servsml5]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[CRAWL_DUMMY]],
      onlyTargetCategory = [[NOTAIR]],
    },
    [2]  = {
      def                = [[CRAWL_DETONATOR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CRAWL_DETONATOR = {
    areaOfEffect       = 5,
    ballistic          = true,
    craterBoost        = 0,
    craterMult         = 0,
    edgeEffectiveness  = 0,
    explosionGenerator = [[]],
    fireSubmersed      = true,
    gravityaffected    = [[true]],
    impulseBoost       = 0,
    impulseFactor      = 0,
    name               = [[Mine Detonator]],
    range              = 1,
    reloadtime         = 0.1,
    renderType         = 4,
    weaponType         = [[Cannon]],
    weaponVelocity     = 1000,
    damage = {
      crawlingbombs      = 1000,
      default            = 0,
    },
  },
  CRAWL_DUMMY = {
    areaOfEffect       = 0,
    craterBoost        = 0,
    craterMult         = 0,
    edgeEffectiveness  = 0,
    explosionGenerator = [[]],
    fireSubmersed      = true,
    impulseBoost       = 0,
    impulseFactor      = 0,
    name               = [[Crawlingbomb Dummy Weapon]],
    range              = 80,
    reloadtime         = 0.1,
    tolerance          = 100000,
    weaponType         = [[Melee]],
    weaponVelocity     = 100000,
    damage = {
      default            = 0,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  CORPSE = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 148,
    description        = [[Invader Wreckage]],
    featureDead        = [[HEAP]],
    footprintX         = 1,
    footprintZ         = 1,
    height             = 20,
    hitdensity         = 100,
    metal              = 49,
    object             = [[ARMVADER_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 148,
    description        = [[Invader Heap]],
    footprintX         = 1,
    footprintZ         = 1,
    height             = 4,
    hitdensity         = 100,
    metal              = 12,
    object             = [[1X1B]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
