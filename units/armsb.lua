-- UNITDEF -- ARMSB --
--------------------------------------------------------------------------------

local unitName = "armsb"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.096,
  altfromsealevel    = 1,
  amphibious         = 1,
  attackrunlength    = 260,
  badTargetCategory  = [[VTOL]],
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 0.5,
  buildCostEnergy    = 7544,
  buildCostMetal     = 169,
  builder            = false,
  buildPic           = [[ARMSB.DDS]],
  buildTime          = 9684,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  canSubmerge        = true,
  category           = [[ALL NOTLAND MOBILE WEAPON ANTIGATOR NOTSUB ANTIFLAME ANTIEMG ANTILASER VTOL NOTSHIP]],
  collide            = false,
  cruiseAlt          = 250,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Seaplane Bomber]],
  energyMake         = 1.1,
  energyStorage      = 0,
  energyUse          = 1.1,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1380,
  maxDamage          = 750,
  maxSlope           = 10,
  maxVelocity        = 8.91,
  maxWaterDepth      = 255,
  metalStorage       = 0,
  mobilestandorders  = 1,
  moverate1          = 8,
  name               = [[Tsunami]],
  noAutoFire         = true,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMSB]],
  scale              = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[CRAWL_BLASTSML]],
  side               = [[ARM]],
  sightDistance      = 455,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 392,
  unitname           = [[armsb]],
  workerTime         = 0,
  sounds = {
    build              = [[nanlath1]],
    canceldestruct     = [[cancel2]],
    repair             = [[repair1]],
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
      [[vtolcrmv]],
    },
    select = {
      [[seapsel1]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[ARM_SEAADVBOMB]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARM_SEAADVBOMB = {
    areaOfEffect       = 100,
    burst              = 7,
    burstrate          = 0.19,
    collideFriendly    = false,
    commandfire        = true,
    craterBoost        = 0,
    craterMult         = 0,
    dropped            = true,
    edgeEffectiveness  = 0.7,
    explosionGenerator = [[custom:ARM_BIGBOMB_EXPLOSION]],
    gravityaffected    = [[true]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    manualBombSettings = true,
    model              = [[bomb]],
    name               = [[SeaAdvancedBombs]],
    noSelfDamage       = true,
    range              = 1280,
    reloadtime         = 9,
    renderType         = 6,
    soundHit           = [[xplomed2]],
    soundStart         = [[bombrel]],
    weaponType         = [[AircraftBomb]],
    damage = {
      antibomber         = 95,
      default            = 210,
      l1bombers          = 5,
      l1subs             = 5,
      l2bombers          = 5,
      l2subs             = 5,
      l3subs             = 5,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
