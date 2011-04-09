-- UNITDEF -- ARMATL --
--------------------------------------------------------------------------------

local unitName = "armatl"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  badTargetCategory  = [[HOVER NOTSHIP]],
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 16384,
  buildCostEnergy    = 8594,
  buildCostMetal     = 981,
  builder            = false,
  buildPic           = [[ARMATL.DDS]],
  buildTime          = 9262,
  canAttack          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[GUARD_NOMOVE]],
  description        = [[Advanced Torpedo Launcher]],
  energyMake         = 0.1,
  energyStorage      = 0,
  energyUse          = 0.1,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 4,
  footprintZ         = 4,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 1520,
  maxVelocity        = 0,
  metalStorage       = 0,
  minWaterDepth      = 12,
  name               = [[Moray]],
  noAutoFire         = false,
  objectName         = [[ARMATL]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 585,
  smoothAnim         = true,
  standingfireorder  = 2,
  TEDClass           = [[WATER]],
  turnRate           = 0,
  unitname           = [[armatl]],
  waterline          = 30,
  workerTime         = 0,
  yardMap            = [[oooooooooooooooo]],
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
      [[torpadv2]],
    },
    select = {
      [[torpadv2]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[HOVER NOTSHIP]],
      def                = [[ARMATL_TORPEDO]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMATL_TORPEDO = {
    areaOfEffect       = 32,
    avoidFriendly      = false,
    burnblow           = true,
    collideFriendly    = false,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH3]],
    guidance           = true,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    model              = [[Advtorpedo]],
    name               = [[LongRangeTorpedo]],
    noSelfDamage       = true,
    propeller          = 1,
    range              = 915,
    reloadtime         = 3.1,
    renderType         = 1,
    selfprop           = true,
    soundHit           = [[xplodep1]],
    soundStart         = [[torpedo1]],
    startVelocity      = 80,
    tolerance          = 1167,
    tracks             = true,
    turnRate           = 99000,
    turret             = true,
    waterWeapon        = true,
    weaponAcceleration = 60,
    weaponTimer        = 10,
    weaponType         = [[TorpedoLauncher]],
    weaponVelocity     = 380,
    damage = {
      commanders         = 1500,
      default            = 750,
      krogoth            = 1500,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 312,
    description        = [[Moray Wreckage]],
    energy             = 0,
    footprintX         = 4,
    footprintZ         = 4,
    height             = 20,
    hitdensity         = 100,
    metal              = 548,
    object             = [[ARMATL_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
