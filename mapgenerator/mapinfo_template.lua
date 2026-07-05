--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- mapinfo.lua
--

local mapinfo = {
	name        = "${NAME}",
	shortname   = "",
	description = "${DESCRIPTION}",
	author      = "",
	version     = "",
	--mutator   = "deployment";
	--mapfile   = "", --// location of smf/sm3 file (optional)
	modtype     = 3, --// 1=primary, 0=hidden, 3=map
	depend      = {"Map Helper v1"},
	replace     = {},

	--startpic   = "", --// deprecated
	--StartMusic = "", --// deprecated

	maphardness     = 100,
	notDeformable   = false,
	gravity         = 130,
	tidalStrength   = 0,
	maxMetal        = 0.02,
	extractorRadius = 500.0,
	voidWater       = false,
	autoShowMetal   = true,


	smf = {
		--minheight = 1000,
		--maxheight = -300,
		--smtFileName0 = "",
		--smtFileName1 = "",
		--smtFileName.. = "",
		--smtFileNameN = "",
	},

	sound = {
		--// Sets the _reverb_ preset (= echo parameters),
		--// passfilter (the direct sound) is unchanged.
		--//
		--// To get a list of all possible presets check:
		--//   https://github.com/spring/spring/blob/master/rts/System/Sound/EFXPresets.cpp
		--//
		--// Hint:
		--// You can change the preset at runtime via:
		--//   /tset UseEFX [1|0]
		--//   /tset snd_eaxpreset preset_name   (may change to a real cmd in the future)
		--//   /tset snd_filter %gainlf %gainhf  (may    "   "  "  "    "  "   "    "   )
		preset = "default",

		passfilter = {
			--// Note, you likely want to set these
			--// tags due to the fact that they are
			--// _not_ set by `preset`!
			--// So if you want to create a muffled
			--// sound you need to use them.
			gainlf = 1.0,
			gainhf = 1.0,
		},

		reverb = {
			--// Normally you just want use the `preset` tag
			--// but you can use handtweak a preset if wanted
			--// with the following tags.
			--// To know their function & ranges check the
			--// official OpenAL1.1 SDK document.

			--density
			--diffusion
			--gain
			--gainhf
			--gainlf
			--decaytime
			--decayhflimit
			--decayhfratio
			--decaylfratio
			--reflectionsgain
			--reflectionsdelay
			--reflectionspan
			--latereverbgain
			--latereverbdelay
			--latereverbpan
			--echotime
			--echodepth
			--modtime
			--moddepth
			--airabsorptiongainhf
			--hfreference
			--lfreference
			--roomrollofffactor
		},
	},

	resources = {
		--grassBladeTex = "",

		--grassShadingTex = "",
		--detailTex = "",
		--specularTex = "",
		--splatDetailTex = "",
		--splatDistrTex = "",
		--skyReflectModTex = "",
		--detailNormalTex = "",
		--lightEmissionTex = "",
	},

	splats = {
		texScales = {0.02, 0.02, 0.02, 0.02},
		texMults  = {1.0, 1.0, 1.0, 1.0},
	},

	atmosphere = {
		minWind      = 5.0,
		maxWind      = 25.0,

		fogStart     = 0.1,
		fogEnd       = 1.0,
		fogColor     = {0.7, 0.7, 0.8},

		sunColor     = {1.0, 1.0, 1.0},
		skyColor     = {0.1, 0.15, 0.7},
		skyDir       = {0.0, 0.0, -1.0},
		skyBox       = "",

		cloudDensity = 0.5,
		cloudColor   = {1.0, 1.0, 1.0},
	},

	grass = {
		bladeWaveScale = 1.0,
		bladeWidth  = 0.32,
		bladeHeight = 4.0,
		bladeAngle  = 1.57,
		bladeColor  = {0.59, 0.81, 0.57}, --// does nothing when `grassBladeTex` is set
	},

	lighting = {
		--// dynsun
		sunStartAngle = 0.0,
		sunOrbitTime  = 1440.0,
		sunDir        = {0.0, 1.0, 2.0, 1e9},

		--// unit & ground lighting
		groundAmbientColor  = {0.5, 0.5, 0.5},
		groundDiffuseColor  = {0.5, 0.5, 0.5},
		groundSpecularColor = {0.1, 0.1, 0.1},
		groundShadowDensity = 0.8,
		unitAmbientColor    = {0.4, 0.4, 0.4},
		unitDiffuseColor    = {0.7, 0.7, 0.7},
		unitSpecularColor   = {0.7, 0.7, 0.7},
		unitShadowDensity   = 0.8,

		specularExponent    = 100.0,
	},

	water = {
		damage =  0.0,

		repeatX = 0.0,
		repeatY = 0.0,

		absorb    = {0.0, 0.0, 0.0},
		baseColor = {0.0, 0.0, 0.0},
		minColor  = {0.0, 0.0, 0.0},

		ambientFactor  = 1.0,
		diffuseFactor  = 1.0,
		specularFactor = 1.0,
		specularPower  = 20.0,

		planeColor = {0.0, 0.4, 0.0},

		surfaceColor  = {0.75, 0.8, 0.85},
		surfaceAlpha  = 0.55,
		diffuseColor  = {1.0, 1.0, 1.0},
		specularColor = {0.5, 0.5, 0.5},

		fresnelMin   = 0.2,
		fresnelMax   = 0.8,
		fresnelPower = 4.0,

		reflectionDistortion = 1.0,

		blurBase      = 2.0,
		blurExponent = 1.5,

		perlinStartFreq  =  8.0,
		perlinLacunarity = 3.0,
		perlinAmplitude  =  0.9,
		windSpeed = 1.0,

		waveOffsetFactor = 0.0;
		waveLength = 0.15;
		waveFoamDistortion = 0.05;
		waveFoamIntensity = 0.5;

		causticsResolution = 75.0;
		causticsStrength = 0.08;

		shoreWaves = true,
		forceRendering = false,

		--// undefined == load them from resources.lua!
		--texture =       "",
		--foamTexture =   "",
		--normalTexture = "",
		--caustics = {
		--	"",
		--	"",
		--},
	},

	teams = {
		${START_POSITIONS}
	},

	terrainTypes = {
		[0] = {
			name = "Default",
			hardness = 1.0,
			receiveTracks = true,
			moveSpeeds = {
				tank  = 1.0,
				kbot  = 1.0,
				hover = 1.0,
				ship  = 1.0,
			},
		},
	},

	custom = {
		fog = {
			color    = {0.26, 0.30, 0.41},
			height   = "80%", --// allows either absolute sizes or in percent of map's MaxHeight
			fogatten = 0.003,
		},
		precipitation = {
			density   = 30000,
			size      = 1.5,
			speed     = 50,
			windscale = 1.2,
			texture   = 'LuaGaia/effects/snowflake.png',
		},
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Helper

local function lowerkeys(ta)
	local fix = {}
	for i,v in pairs(ta) do
		if (type(i) == "string") then
			if (i ~= i:lower()) then
				fix[#fix+1] = i
			end
		end
		if (type(v) == "table") then
			lowerkeys(v)
		end
	end

	for i=1,#fix do
		local idx = fix[i]
		ta[idx:lower()] = ta[idx]
		ta[idx] = nil
	end
end

lowerkeys(mapinfo)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Map Options

if (Spring) then
	local function tmerge(t1, t2)
		for i,v in pairs(t2) do
			if (type(v) == "table") then
				t1[i] = t1[i] or {}
				tmerge(t1[i], v)
			else
				t1[i] = v
			end
		end
	end

	-- make code safe in unitsync
	if (not Spring.GetMapOptions) then
		Spring.GetMapOptions = function() return {} end
	end
	function tobool(val)
		local t = type(val)
		if (t == 'nil') then
			return false
		elseif (t == 'boolean') then
			return val
		elseif (t == 'number') then
			return (val ~= 0)
		elseif (t == 'string') then
			return ((val ~= '0') and (val ~= 'false'))
		end
		return false
	end

	getfenv()["mapinfo"] = mapinfo
		local files = VFS.DirList("mapconfig/mapinfo/", "*.lua")
		table.sort(files)
		for i=1,#files do
			local newcfg = VFS.Include(files[i])
			if newcfg then
				lowerkeys(newcfg)
				tmerge(mapinfo, newcfg)
			end
		end
	getfenv()["mapinfo"] = nil

	--------------------------------------------------------------------------------
	-- Blank-map (InitBlank) DNTS splat support
	--
	-- CBlankMapGenerator injects the chosen splat set as blank_map_splat* map
	-- options (the engine lowercases option keys). Mirror them into the SSMF
	-- resources/splats tables so the standard map-load path loads the detail-normal
	-- array and compiles the DNTS shader variant, exactly like an archived map that
	-- declares them in mapinfo. SMFReadMap additionally gates DNTS on a non-empty
	-- splatDistrTex; when none is supplied we set a placeholder name so the engine
	-- synthesizes the blank (255,0,0,0) distribution that runtime map editors read
	-- and paint into. Inert on maps that don't carry these options.
	-- Keys are written lowercase to match the post-lowerkeys() table; the engine's
	-- LuaTable lookups are case-insensitive.
	local mapOpts = Spring.GetMapOptions()
	if mapOpts and mapOpts["blank_map_splatdetailnormaltex1"] then
		local res, spl = mapinfo.resources, mapinfo.splats
		local scales = spl.texscales or {0.02, 0.02, 0.02, 0.02}
		local mults  = spl.texmults  or {1.0, 1.0, 1.0, 1.0}
		for ch = 1, 4 do
			local tex = mapOpts["blank_map_splatdetailnormaltex" .. ch]
			if tex and tex ~= "" then
				res["splatdetailnormaltex" .. ch] = tex
			end
			scales[ch] = tonumber(mapOpts["blank_map_splattexscale" .. ch]) or scales[ch]
			mults[ch]  = tonumber(mapOpts["blank_map_splattexmult"  .. ch]) or mults[ch]
		end
		spl.texscales = scales
		spl.texmults  = mults
		res.splatdetailnormaldiffusealpha = tobool(mapOpts["blank_map_splatdetailnormaldiffusealpha"])
		-- Compatibility gate: some engine paths still key splat activation on
		-- splatDetailTex being non-empty even when DNTS normals are provided.
		local legacyDetail = mapOpts["blank_map_splatdetailtex"]
		if legacyDetail and legacyDetail ~= "" then
			res.splatdetailtex = legacyDetail
		elseif mapOpts["blank_map_splatdetailnormaltex1"] then
			res.splatdetailtex = mapOpts["blank_map_splatdetailnormaltex1"]
		end
		-- A non-empty distr name flips the DNTS gate. A real path loads; a missing
		-- one falls back to the blank (255,0,0,0) distribution editors paint on.
		local distr = mapOpts["blank_map_splatdistr"]
		res.splatdistrtex = (distr and distr ~= "" and distr) or "blank_generated_splatdistr.png"
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return mapinfo

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
