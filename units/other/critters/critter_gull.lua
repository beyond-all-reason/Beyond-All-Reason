local unitName = "critter_gull"

unitDef = {
  name                = "SeaGull",
  description         = "I´m so fly",
  objectName          = [[critter_gull.s3o]],
  script              = [[critter_gull.lua]],
  iconType            = "blank",
  
  builder             = false,
  buildPic            = [[placeholder.png]],
  buildTime           = 10,
  ----cost
  buildCostEnergy     = 0,
  buildCostMetal      = 0,
  ----health
  maxDamage           = 10,
  idleAutoHeal        = 0,
  ----movement
  maxVelocity         = 1.8,
  acceleration        = 0.2,
  brakeRate           = 3.75,
  footprintx          = 1,
  footprintZ          = 1,
  Upright             = false,
  collide             = false,
  collision           = false,
  selfDestructCountdown = 0,
  turnRate            = 500,
  turnRadius          = 5,
  reclaimable         = false,
  stealth 			      = true,
  sonarStealth		    = true,
  ----aircraft related
  canFly              = true,
  cruiseAlt           = 200,
  hoverAttack         = true,
  airStrafe           = false,
  bankscale           = 1,
  maxBank             = 0.2,
  maxPitch            = 0.2,
  sightDistance       = 330,
  seismicSignature    = 0,
  canGuard            = true,
  canMove             = true,
  canPatrol           = true,
  canstop             = [[1]],
  canmove = true,
  category = "MOBILE WEAPON NOTLAND NOTSUB VTOL NOTSHIP NOTHOVER",
  mass                = 125,
  blocking            = false,
  capturable          = false,
    customparams = {
        nohealthbars = true,
    },
}

return lowerkeys({ [unitName] = unitDef })
