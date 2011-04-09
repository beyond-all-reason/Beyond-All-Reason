-- UNITDEF -- CORFMINE3 --
--------------------------------------------------------------------------------

local unitName = "corfmine3"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  badTargetCategory  = [[VTOL]],
  bmcode             = 0,
  brakeRate          = 0,
  buildCostEnergy    = 1500,
  buildCostMetal     = 25,
  builder            = false,
  buildPic           = [[CORFMINE3.DDS]],
  buildTime          = 150,
  canAttack          = false,
  canGuard           = false,
  canMove            = false,
  canPatrol          = false,
  canstop            = 0,
  category           = [[ALL WEAPON MINE KAMIKAZE NOTSUB NOTAIR]],
  cloakCost          = 2,
  collide            = false,
  collisionvolumeoffsets = [[0 -0.5 0]],
  collisionvolumescales = [[20 5 20]],
  collisionvolumetest = 1,
  collisionvolumetype = [[Ell]],
  defaultmissiontype = [[Standby_Mine]],
  description        = [[Heavy Mine]],
  energyStorage      = 0,
  energyUse          = 0,
  explodeAs          = [[FMINE_HEAVY]],
  firestandorders    = 0,
  firestate          = 2,
  footprintX         = 1,
  footprintZ         = 1,
  iconType           = [[building]],
  idleAutoHeal       = 10,
  idleTime           = 300,
  initCloaked        = true,
  maxDamage          = 10,
  maxSlope           = 40,
  maxVelocity        = 0,
  maxWaterDepth      = 10,
  metalStorage       = 0,
  minCloakDistance   = 8,
  minWaterDepth      = 0,
  name               = [[1100 NS]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORFMINE3]],
  seismicSignature   = 0,
  selfDestructAs     = [[FMINE_HEAVY]],
  selfDestructCountdown = 0,
  side               = [[CORE]],
  sightDistance      = 71.5,
  smoothAnim         = false,
  standingfireorder  = 2,
  stealth            = true,
  TEDClass           = [[SPECIAL]],
  turnRate           = 0,
  unitname           = [[corfmine3]],
  waterline          = 1,
  workerTime         = 0,
  yardMap            = [[w]],
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
      [[servsml6]],
    },
    select = {
      [[minesel2]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[MINE_DUMMY]],
      onlyTargetCategory = [[NOTAIR]],
    },
    [2]  = {
      def                = [[MINE_DETONATOR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  MINE_DETONATOR = {
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
      default            = 0,
      mines              = 100,
    },
  },
  MINE_DUMMY = {
    areaOfEffect       = 0,
    craterBoost        = 0,
    craterMult         = 0,
    edgeEffectiveness  = 0,
    explosionGenerator = [[]],
    fireSubmersed      = true,
    impulseBoost       = 0,
    impulseFactor      = 0,
    name               = [[Crawlingbomb Dummy Weapon]],
    range              = 64,
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

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
