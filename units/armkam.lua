-- UNITDEF -- ARMKAM --
--------------------------------------------------------------------------------

local unitName = "armkam"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.154,
  badTargetCategory  = [[VTOL]],
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 3.75,
  buildCostEnergy    = 2226,
  buildCostMetal     = 125,
  builder            = false,
  buildPic           = [[ARMKAM.DDS]],
  buildTime          = 5046,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL WEAPON NOTSUB VTOL]],
  collide            = false,
  cruiseAlt          = 60,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Light Gunship]],
  energyStorage      = 0,
  energyUse          = 0.8,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  hoverAttack        = true,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 350,
  maxSlope           = 10,
  maxVelocity        = 6.16,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  moverate1          = 3,
  name               = [[Banshee]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMKAM]],
  scale              = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 520,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 693,
  unitname           = [[armkam]],
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
      [[vtolarmv]],
    },
    select = {
      [[vtolarac]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[MED_EMG]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  MED_EMG = {
    areaOfEffect       = 8,
    burst              = 3,
    burstrate          = 0.25,
    craterBoost        = 0,
    craterMult         = 0,
    endsmoke           = 0,
    explosionGenerator = [[custom:BRAWLIMPACTS]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    intensity          = 0.8,
    lineOfSight        = true,
    name               = [[E.M.G.]],
    noSelfDamage       = true,
    pitchtolerance     = 12000,
    range              = 350,
    reloadtime         = 0.7,
    renderType         = 4,
    rgbColor           = [[1 0.95 0.4]],
    size               = 2.25,
    soundStart         = [[brawlemg]],
    sprayAngle         = 1024,
    startsmoke         = 0,
    tolerance          = 6000,
    turret             = false,
    weaponTimer        = 1,
    weaponType         = [[Cannon]],
    weaponVelocity     = 350,
    damage = {
      commanders         = 3,
      default            = 9,
      flakboats          = 3,
      flaks              = 3,
      gunships           = 1,
      hgunships          = 1,
      l1bombers          = 1,
      l1fighters         = 1,
      l1subs             = 1,
      l2bombers          = 1,
      l2fighters         = 1,
      l2subs             = 1,
      l3subs             = 1,
      vradar             = 1,
      vtol               = 1,
      vtrans             = 1,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
