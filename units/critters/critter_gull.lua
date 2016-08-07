local unitName = "critter_gull"

unitDef = {
  name                = "SeaGull",
  description         = "I´m so fly",
  objectName          = [[critter_gull.s3o]],
  script              = [[critter_gull.lua]],
  iconType            = "blank",
  bmcode              = [[1]],
  
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
  moverate1           = [[3]],
  footprintx          = 1,
  footprintZ          = 1,
  Upright             = false,
  maneuverleashlength = 1280,
  collide             = false,
  collision           = false,
  selfDestructCountdown = 0,
  steeringmode        = [[1]],
  TEDClass            = [[VTOL]],
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
  sightDistance       = 0,
  seismicSignature    = 0,
  canGuard            = true,
  canMove             = true,
  canPatrol           = true,
  canstop             = [[1]],
  category            = [[VTOL]],
  mass                = 125,
	blocking						= false,
	capturable          = false,
}

return lowerkeys({ [unitName] = unitDef })
