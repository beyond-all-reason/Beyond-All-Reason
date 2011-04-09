-- UNITDEF -- CORCUT --
--------------------------------------------------------------------------------

local unitName = "corcut"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.125,
  amphibious         = 1,
  badTargetCategory  = [[VTOL]],
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 3.938,
  buildCostEnergy    = 5897,
  buildCostMetal     = 220,
  builder            = false,
  buildPic           = [[CORCUT.DDS]],
  buildTime          = 11970,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  canSubmerge        = true,
  category           = [[ALL MOBILE WEAPON ANTIGATOR VTOL ANTIFLAME ANTIEMG ANTILASER NOTLAND NOTSUB NOTSHIP]],
  collide            = false,
  cruiseAlt          = 100,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Seaplane Gunship]],
  energyMake         = 0.6,
  energyStorage      = 0,
  energyUse          = 0.6,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  hoverAttack        = true,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 580,
  maxSlope           = 10,
  maxVelocity        = 5.08,
  maxWaterDepth      = 255,
  metalStorage       = 0,
  mobilestandorders  = 1,
  moverate1          = 8,
  name               = [[Cutlass]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORCUT]],
  scale              = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 595,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 828,
  unitname           = [[corcut]],
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
      [[seapsel2]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[VTOL_ROCKET2]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  VTOL_ROCKET2 = {
    areaOfEffect       = 128,
    burnblow           = true,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASHSMALLBUILDINGEX]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    name               = [[RiotCannon]],
    noSelfDamage       = true,
    pitchtolerance     = 12000,
    range              = 430,
    reloadtime         = 1.3,
    renderType         = 4,
    soundHit           = [[xplosml3]],
    soundStart         = [[canlite3]],
    soundTrigger       = true,
    startsmoke         = 1,
    turret             = false,
    weaponType         = [[Cannon]],
    weaponVelocity     = 600,
    damage = {
      commanders         = 53,
      default            = 105,
      flakboats          = 53,
      flaks              = 53,
      gunships           = 17,
      hgunships          = 17,
      l1bombers          = 17,
      l1fighters         = 17,
      l1subs             = 5,
      l2bombers          = 17,
      l2fighters         = 17,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 17,
      vtol               = 17,
      vtrans             = 53,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
