-- UNITDEF -- CORMLV --
--------------------------------------------------------------------------------

local unitName = "cormlv"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.07,
  activateWhenBuilt  = true,
  bmcode             = 1,
  brakeRate          = 0.55,
  buildCostEnergy    = 1217,
  buildCostMetal     = 57,
  buildDistance      = 128,
  builder            = true,
  buildPic           = [[CORMLV.DDS]],
  buildTime          = 3640,
  canAssist          = false,
  canGuard           = false,
  canMove            = true,
  canPatrol          = false,
  canReclaim         = false,
  canreclamate       = 0,
  canRepair          = false,
  canRestore         = false,
  canstop            = 1,
  category           = [[ALL TANK MOBILE NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Stealthy Minelayer/Minesweeper]],
  energyMake         = 1,
  energyStorage      = 0,
  energyUse          = 1,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  leaveTracks        = true,
  maneuverleashlength = 640,
  mass               = 1500,
  maxDamage          = 155,
  maxSlope           = 16,
  maxVelocity        = 2.458,
  maxWaterDepth      = 0,
  metalMake          = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[TANK2]],
  name               = [[Spoiler]],
  noChaseCategory    = [[ALL]],
  objectName         = [[CORMLV]],
  onoffable          = false,
  radarDistanceJam   = 64,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[core]],
  sightDistance      = 188,
  smoothAnim         = false,
  standingfireorder  = 0,
  standingmoveorder  = 1,
  stealth            = true,
  steeringmode       = 1,
  TEDClass           = [[CNSTR]],
  terraformSpeed     = 120,
  trackOffset        = 12,
  trackStrength      = 5,
  trackStretch       = 1,
  trackType          = [[StdTank]],
  trackWidth         = 15,
  turnRate           = 580,
  unitname           = [[cormlv]],
  workerTime         = 40,
  buildoptions = {
    [[cormine1]],
    [[cormine3]],
    [[cordrag]],
    [[coreyes]],
  },
  sounds = {
    build              = [[nanlath2]],
    canceldestruct     = [[cancel2]],
    capture            = [[capture1]],
    repair             = [[repair2]],
    underattack        = [[warning1]],
    working            = [[reclaim1]],
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
      [[vcormove]],
    },
    select = {
      [[vcorsel]],
    },
  },
  weapons = {
    [1]  = {
      def                = [[MINESWEEP]],
      onlyTargetCategory = [[MINE]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  MINESWEEP = {
    areaOfEffect       = 512,
    collideFriendly    = false,
    craterBoost        = 0,
    craterMult         = 0,
    edgeEffectiveness  = 0.25,
    explosionGenerator = [[custom:MINESWEEP]],
    intensity          = 0,
    lineOfSight        = false,
    metalpershot       = 0,
    name               = [[MineSweep]],
    noSelfDamage       = true,
    range              = 200,
    reloadtime         = 3,
    renderType         = 4,
    rgbColor           = [[0 0 0]],
    thickness          = 0,
    tolerance          = 100,
    turret             = true,
    weaponTimer        = 0.1,
    weaponType         = [[Cannon]],
    weaponVelocity     = 3650,
    damage = {
      default            = 0,
      mines              = 1000,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 93,
    description        = [[Spoiler Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 37,
    object             = [[CORMLV_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 47,
    description        = [[Spoiler Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 15,
    object             = [[3X3F]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
