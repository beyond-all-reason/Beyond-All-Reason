-- UNITDEF -- ARMBRAWL --
--------------------------------------------------------------------------------

local unitName = "armbrawl"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.24,
  badTargetCategory  = [[VTOL]],
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 4.41,
  buildCostEnergy    = 5778,
  buildCostMetal     = 294,
  builder            = false,
  buildPic           = [[ARMBRAWL.DDS]],
  buildTime          = 13294,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND MOBILE WEAPON ANTIGATOR NOTSUB ANTIFLAME ANTIEMG ANTILASER VTOL NOTSHIP]],
  collide            = false,
  cruiseAlt          = 100,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Gunship]],
  energyMake         = 0.8,
  energyStorage      = 0,
  energyUse          = 0.8,
  explodeAs          = [[GUNSHIPEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  hoverAttack        = true,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 1135,
  maxSlope           = 10,
  maxVelocity        = 5.36,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  name               = [[Brawler]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMBRAWL]],
  scale              = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 550,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 792,
  unitname           = [[armbrawl]],
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
      def                = [[VTOL_EMG]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  VTOL_EMG = {
    areaOfEffect       = 8,
    burst              = 3,
    burstrate          = 0.1,
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
    range              = 380,
    reloadtime         = 0.475,
    renderType         = 4,
    rgbColor           = [[1 0.95 0.4]],
    size               = 2.5,
    soundStart         = [[brawlemg]],
    sprayAngle         = 1024,
    startsmoke         = 0,
    tolerance          = 6000,
    turret             = false,
    weaponTimer        = 1,
    weaponType         = [[Cannon]],
    weaponVelocity     = 450,
    damage = {
      commanders         = 8,
      default            = 16,
      flakboats          = 8,
      flaks              = 8,
      gunships           = 2,
      hgunships          = 2,
      l1bombers          = 2,
      l1fighters         = 2,
      l1subs             = 1,
      l2bombers          = 2,
      l2fighters         = 2,
      l2subs             = 1,
      l3subs             = 1,
      vradar             = 2,
      vtol               = 2,
      vtrans             = 2,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
