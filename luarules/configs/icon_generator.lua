-----------------------------------------------------------------------
-----------------------------------------------------------------------
--
--  Icon Generator Config File
--



--// Info
if info then
	local ratios = { [""] = (1 / 1) } -- {["16to10"]=(10/16), ["1to1"]=(1/1), ["5to4"]=(4/5)} --, ["4to3"]=(3/4)}
	local resolutions = { { 256, 256 }, {400, 400} } -- {{128,128},{64,64}}	-- NOTE: setting too high will crash spring
	local schemes = { "" }  --, "cor"}

	return schemes, resolutions, ratios
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------

--// filename ext
imageExt = ".png"   -- unfortumnately .dds wont be with mipmaps

--// render into a fbo in 4x size
renderScale = 4

--// faction colors (check (and needs) LuaRules/factions.lua)
factionTeams = {
	arm = 1, --// armada
	cor = 1, --// cortex
	scav = 2,
	legion = 2,
	raptor = 2, --// raptor
	unknown = 2, --// unknown
}

-- Gets scheme from gadget when this is included
factionColors = function(faction)

	color = {
		arm = { 0.08, 0.17, 1.0 }, --// armada
		cor = { 1.0, 0.03, 0.0 }, --// cortex
		raptor = { 0.8, 0.53, 0.07 }, --// raptor
		scav = { 0.38, 0, 0.38 }, --// scavengers
		legion = {0, 1, 0}, --// legion
		unknown = { 0.03, 1, 0.03 }, --// unknown
		Blue = { 0, 0, 0 },
		Red = { 1, 1, 1 }
	}
	Spring.Echo('Queried faction: ' .. faction .. ', scheme: ' .. scheme)

	if color[faction] then
		return color[faction]
	else
		if color[scheme] then
			return color[scheme]
		else
			return color['unknown']
		end
	end

end

-----------------------------------------------------------------------
-----------------------------------------------------------------------

local IconConfig = {
	[1] = { -- for buildpics (use 256x256)
		--// render options textured
		textured = true,
		lightAmbient = { 0.6, 0.6, 0.6 },
		lightDiffuse = { 1.05, 1.05, 1.05 },
		lightPos = { -0.3, 0.5, 0.55 }, --{-0.2,0.4,0.5},

		--// Ambient Occlusion & Outline settings
		aoPower = 3,
		aoContrast = 3,
		aoTolerance = 0,
		olContrast = 0,
		olTolerance = 0,

		halo = false,
	},

	[2] = { -- gif animation (use 350x350)
		--// render options textured
		textured = true,
		lightAmbient = { 1, 1, 1 },
		lightDiffuse = { 0, 0, 0 },
		lightPos = { 0, 0, 0 }, --{-0.2,0.4,0.5},

		--// Ambient Occlusion & Outline settings
		aoPower = 3,
		aoContrast = 2,
		aoTolerance = 0,
		olContrast = 0,
		olTolerance = 0,

		halo = false,

	},
}

local selConfig = 2

textured = IconConfig[selConfig].textured
lightAmbient = IconConfig[selConfig].lightAmbient
lightDiffuse = IconConfig[selConfig].lightDiffuse
lightPos = IconConfig[selConfig].lightPos
aoPower = IconConfig[selConfig].aoPower
aoContrast = IconConfig[selConfig].aoContrast
aoTolerance = IconConfig[selConfig].aoTolerance
olContrast = IconConfig[selConfig].olContrast
olTolerance = IconConfig[selConfig].olTolerance
halo = IconConfig[selConfig].halo


-----------------------------------------------------------------------
-----------------------------------------------------------------------

--// backgrounds
background = true
local water = "LuaRules/Images/bg_water.png"
local builder = "LuaRules/Images/constructionunit.png"

local function Greater30(a)
	return a > 30;
end
local function GreaterEq15(a)
	return a >= 15;
end
local function GreaterZero(a)
	return a > 0;
end
local function GreaterEqZero(a)
	return a >= 0;
end
local function GreaterFour(a)
	return a > 4;
end
local function LessEqZero(a)
	return a <= 0;
end

backgrounds = {
	--{check={waterline=GreaterEq15,minWaterDepth=GreaterZero},texture=water},
	--{check={floatOnWater=false,minWaterDepth=GreaterFour},texture=water},
	--{check={floatOnWater=true,minWaterDepth=GreaterZero},texture=water},
	--{check={isBuilder=true,canMove = true},texture=builder},
}


-----------------------------------------------------------------------
-----------------------------------------------------------------------


local Default = {
	--  default settings for rendering
	-- zoom   := used to make all model icons same in size (DON'T USE, it is just for auto-configuration!)
	-- offset := used to center the model in the fbo (not in the final icon!) (DON'T USE, it is just for auto-configuration!)
	-- rot    := facing direction
	-- angle  := topdown angle of the camera (0 degree = frontal, 90 degree = topdown)
	-- clamp  := clip everything beneath it (hide underground stuff)
	-- scale  := render the model x times as large and then scale down, to replaces missing AA support of FBOs (and fix rendering of very tine structures like antennas etc.))
	-- unfold := unit needs cob to unfolds
	-- move   := send moving cob events (works only with unfold)
	-- attack := send attack cob events (works only with unfold)
	-- shotangle := vertical aiming, useful for arties etc. (works only with unfold+attack)
	-- wait   := wait that time in gameframes before taking the screenshot (default 300) (works only with unfold)
	-- border := free space around the final icon (in percent/100)
	-- empty  := empty model (used for fake units in CA)
	-- attempts := number of tries to scale the model to fit in the icon

	[1] = {
		border = 0.05,
		angle = 26,
		rot = "right",
		clamp = -50, --i dont think BAR has to really clamp stuff
		scale = 1.5, --was 1.5
		empty = false,
		attempts = 2,
		wait = 60,
		zoom = 1.0,
		offset = { 0, 0, 0 },
		unfold = true, --new for bar
	},

	[2] = {},
	[3] = {},
	[4] = {},

}

defaults = Default[1]


-----------------------------------------------------------------------
-----------------------------------------------------------------------

--// per unitdef settings
unitConfigs = {


	[UnitDefNames.cormex.id] = {
		clamp = 0,
		unfold = true,
		wait = 60,
	},
	[UnitDefNames.cordoom.id] = {
		unfold = true,
	},

	[UnitDefNames.armamd.id] = {
		unfold = false,
	},
	[UnitDefNames.armclaw.id] = {
		unfold = false,
	},
	[UnitDefNames.armmmkr.id] = {
		unfold = false,
	},
	[UnitDefNames.armpb.id] = {
		unfold = false,
	},
	[UnitDefNames.armferret.id] = {
		unfold = false,
	},
	[UnitDefNames.corcs.id] = {
		unfold = false,
	},
	[UnitDefNames.corfmd.id] = {
		unfold = false,
	},
	[UnitDefNames.corsilo.id] = {
		unfold = false,
	},
	[UnitDefNames.corvipe.id] = {
		unfold = false,
	},
	[UnitDefNames.armsilo.id] = {
		unfold = false,
	},
	[UnitDefNames.cortron.id] = {
		unfold = false,
	},

	[UnitDefNames.cormaw.id] = {
		unfold = false,
	},

	[UnitDefNames.cormexp.id] = {
		unfold = false,
	},
	[UnitDefNames.corsolar.id] = {
		unfold = true,
		wait = 80,
	},
	[UnitDefNames.armrad.id] = {
		wait = 360,
	},
	[UnitDefNames.corgant.id] = {
		wait = 90,
	},
	[UnitDefNames.corgantuw.id] = {
		wait = 90,
	},
	[UnitDefNames.cortoast.id] = {
		wait = 1,
	},
	[UnitDefNames.armplat.id] = {
		wait = 65,
	},

}

for i = 1, #UnitDefs do
	if UnitDefs[i].canFly then
		if unitConfigs[i] then
			if unitConfigs[i].unfold ~= false then
				unitConfigs[i].unfold = true
				unitConfigs[i].move = true
			end
		else
			unitConfigs[i] = { unfold = true, move = true }
		end

		-- give ticks etc.. larger padding
	elseif UnitDefs[i].canKamikaze then
		if unitConfigs[i] then
			if not unitConfigs[i].border then
				unitConfigs[i].border = 0.256
			end
		else
			unitConfigs[i] = { border = 0.256 }
		end
	end
end
