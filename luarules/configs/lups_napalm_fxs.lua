local napalm = {
  default = {
    colormap        = { {0, 0, 0, 0.01}, {0.75, 0.75, 0.9, 0.02}, {0.45, 0.2, 0.3, 0.1}, {0.4, 0.16, 0.1, 0.12}, {0.3, 0.15, 0.01, 0.15},  {0.3, 0.15, 0.01, 0.15}, {0.3, 0.15, 0.01, 0.15}, {0.1, 0.035, 0.01, 0.15}, {0, 0, 0, 0.01} },
    count           = 4,
    life            = 175,
    lifeSpread      = 40,
	delay			= 0,
	delaySpread		= 0,
    emitVector      = {0,1,0},
    emitRotSpread   = 90,
    force           = {0,0.3,0},

    partpos         = "r*sin(alpha),0,r*cos(alpha) | r=rand()*15, alpha=rand()*2*pi",

    rotSpeed        = 0.25,
    rotSpeedSpread  = -0.5,
    rotSpread       = 360,
    rotExp          = 1.5,

    speed           = 0.225,
    speedSpread     = 0.05,
    speedExp        = 7,

    size            = 40,
    sizeSpread      = 10,
    sizeGrowth      = 0.15,
    sizeExp         = 2.5,

    layer           = 1,
    texture         = "bitmaps/GPL/flame.png",
  },
  firewalker = {
	count = 400,
	partpos = "r*sin(alpha),-60+2*r,r*cos(alpha) | r=rand()*75, alpha=rand()*2*pi",
	delay = 0,
	delaySpread = 390,
  },
}
local heat = {
  default = {
    count         = 1,
    emitVector    = {0,1,0},
    emitRotSpread = 60,
    force         = {0,0.5,0},

    life          = 270,
    lifeSpread    = 70,

    speed           = 0.25,
    speedSpread     = 0.25,
    speedExp        = 7,

    size            = 100,
    sizeSpread      = 40,
    sizeGrowth      = 0.3,
    sizeExp         = 2.5,

    strength      = 0.75,
    scale         = 5.0,
    animSpeed     = 0.25,
    heat          = 6.5,

    texture       = 'bitmaps/GPL/Lups/mynoise2.png',
  },
  firewalker = {
	life = 1600,
	size = 350,
	lifeSpread = 300,
	speed           = 0.025,
	speedSpread     = 0.01,
	sizeGrowth		= 0.06,
  },
}

for name,def in pairs(napalm) do
	if name ~= "default" then
		napalm[name] = Spring.Utilities.MergeTable(def,napalm.default,true)
	end
end
for name,def in pairs(heat) do
	if name ~= "default" then
		heat[name] = Spring.Utilities.MergeTable(def,heat.default,true)
	end
end

return napalm, heat