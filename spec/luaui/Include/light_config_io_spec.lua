local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local env = SpecEnv.new()
local IO = SpecEnv.include(env, "luaui/Include/light_config_io.lua")

local CONFIG = table.concat({
	"-- header",
	"local unitLights = {",
	"",
	"\tarmpw = {",
	"\t\theadlight = { -- the lightname",
	'\t\t\tlightType = "cone",',
	'\t\t\tpieceName = "head",',
	"\t\t\tlightConfig = {",
	"\t\t\t\tposx = 0,",
	"\t\t\t\tradius = 50,",
	"\t\t\t},",
	"\t\t},",
	"\t\t-- the eyes glow",
	"\t\teyes = {",
	'\t\t\tlightType = "point",',
	"\t\t\tlightConfig = {",
	"\t\t\t\tradius = 5,",
	"\t\t\t},",
	"\t\t},",
	"\t},",
	'\t["arm-odd"] = {',
	"\t\tglow = {",
	'\t\t\tlightType = "point",',
	"\t\t\tlightConfig = {",
	"\t\t\t\tradius = 9,",
	"\t\t\t},",
	"\t\t},",
	"\t},",
	"}",
	"unitLights.armdecom = unitLights.armpw",
	"return unitLights",
	"",
}, "\r\n")

local function load(text)
	return assert(loadstring(text:gsub("\r", "")))()
end

local function light(lightType, config, pieceName, preset)
	return { lightType = lightType, pieceName = pieceName, config = config, extra = {}, preset = preset }
end

local WEAPONS = table.concat({
	"local BaseClasses = {",
	"\tLaserProjectile = {",
	'\t\tlightType = "beam", -- or cone or beam',
	"\t\tlightConfig = {",
	"\t\t\tradius = 100,",
	"\t\t},",
	"\t},",
	"\tExplosion = { -- spawned on explosions",
	'\t\tlightType = "point",',
	"\t\tlightConfig = {",
	"\t\t\tradius = 100,",
	"\t\t\tr = 1,",
	"\t\t},",
	"\t},",
	"\tExplosionXL = {",
	'\t\tlightType = "point",',
	"\t\tlightConfig = {",
	"\t\t\tradius = 300,",
	"\t\t},",
	"\t},",
	"}",
	"local explosionLightsNames = {}",
	'explosionLightsNames.corint_lrpc = GetLightClass("ExplosionXL", nil, "Large", {',
	"\tr = 2,",
	"})",
	"explosionLightsNames.corint_lrpc.yOffset = 16",
	"--[[",
	'explosionLightsNames["armkam_med_emg"] =',
	'GetLightClass("Explosion", nil, "Small", {r = 1})',
	"]]",
	"",
	"-- duplicate all weapons for scavengers",
	"function applyScavVariants(name, params) end",
	"for name, params in pairs(explosionLightsNames) do",
	"end",
	"",
}, "\r\n")

local function loadWeapons(text)
	local seen = {}
	local env = {
		pairs = pairs,
		GetLightClass = function(base, _, _, overrides)
			return { base = base, config = overrides }
		end,
	}
	local chunk = assert(loadstring(text:gsub("\r", "") .. "\nreturn explosionLightsNames"))
	setfenv(chunk, env)
	seen = chunk()
	return seen
end

describe("light_config_io", function()
	it("writes numbers that read back the same", function()
		for _, n in ipairs({ 0, 1, -3, 0.1, 0.07, 1.2, -11, 12345.678, 1 / 3 }) do
			assert.are.equal(n, tonumber(IO.formatNumber(n)))
		end
		assert.are.equal("0.1", IO.formatNumber(0.1))
		assert.are.equal("45", IO.formatNumber(45))
	end)

	it("lists unit blocks and their lights", function()
		local units = IO.listUnits(CONFIG)
		assert.are.same({ "headlight", "eyes" }, units.armpw)
		assert.are.same({ "glow" }, units["arm-odd"])
		assert.is_nil(units.armdecom)
	end)

	it("leaves the text alone when nothing is edited", function()
		assert.are.equal(CONFIG, IO.applyEdits(CONFIG, "armpw", {}))
	end)

	it("rewrites one light and keeps its neighbours and their comments", function()
		local out = IO.applyEdits(CONFIG, "armpw", {
			set = { eyes = light("point", { posy = 2.5, radius = 7, r = 1 }, "head") },
		})
		assert.is_truthy(out:find("headlight = { -- the lightname", 1, true))
		assert.is_truthy(out:find("-- the eyes glow", 1, true))
		assert.is_truthy(out:find("\r\n", 1, true))
		local t = load(out)
		assert.are.equal(7, t.armpw.eyes.lightConfig.radius)
		assert.are.equal(2.5, t.armpw.eyes.lightConfig.posy)
		assert.are.equal("head", t.armpw.eyes.pieceName)
		assert.are.equal(50, t.armpw.headlight.lightConfig.radius)
	end)

	it("adds new lights, removes lights and their comments", function()
		local out = IO.applyEdits(CONFIG, "armpw", {
			set = { beam = light("beam", { radius = 3, pos2z = 20 }) },
			remove = { eyes = true },
		})
		local t = load(out)
		assert.is_nil(t.armpw.eyes)
		assert.are.equal(20, t.armpw.beam.lightConfig.pos2z)
		assert.is_nil(out:find("the eyes glow", 1, true))
	end)

	it("opens a block for a unit that has none", function()
		local out = IO.applyEdits(CONFIG, "corak", { set = { a = light("point", { radius = 4 }) } })
		assert.are.equal(4, load(out).corak.a.lightConfig.radius)
	end)

	it("finds the unit a name is copied from", function()
		assert.are.equal("armpw", IO.aliasSource(CONFIG, "armdecom"))
		assert.is_nil(IO.aliasSource(CONFIG, "armpw"))
	end)

	it("writes a preset light as its overrides only", function()
		local presets = { glow = { lightType = "point", lightConfig = { r = 1, g = 0.5, a = 2, colortime = 30 } } }
		local lines = IO.serializeLight(
			"lamp",
			light("point", { posx = 1, radius = 8, r = 1, g = 0.5, a = 3, colortime = 30 }, "base", "glow"),
			presets
		)
		local text = table.concat(lines, "\n")
		assert.is_truthy(text:find('lamp = preset("glow", {', 1, true))
		assert.is_truthy(text:find("a = 3,", 1, true))
		assert.is_truthy(text:find("radius = 8,", 1, true))
		assert.is_nil(text:find("g = 0.5", 1, true))
		assert.is_nil(text:find("lightType", 1, true))
	end)

	it("reads a renderer light back from its parameter slots", function()
		local p = {}
		for i = 1, 29 do
			p[i] = 0
		end
		p[1], p[4], p[5], p[8], p[9], p[21] = 3, 40, 0.5, 0.3, 1.2, 0.6
		local described =
			IO.describe({ lightType = "cone", pieceName = "head", lightParamTable = p, alliedOnly = true })
		assert.are.equal(3, described.config.posx)
		assert.are.equal(0.5, described.config.dirx)
		assert.are.equal(0.3, described.config.theta)
		assert.are.equal(0.6, described.config.color2r)
		assert.is_true(described.extra.alliedOnly)
	end)

	it("reads the weapon base classes and picks one for a light", function()
		local classes = IO.listBaseClasses(WEAPONS)
		assert.are.same({ LaserProjectile = "beam", Explosion = "point", ExplosionXL = "point" }, classes)
		assert.are.equal("ExplosionXL", IO.baseClassFor(classes, "ExplosionXLLarge_r=2", "point", "explosion"))
		assert.are.equal("Explosion", IO.baseClassFor(classes, "ExplosionSmall", "point", "explosion"))
		assert.are.equal("LaserProjectile", IO.baseClassFor(classes, nil, "beam", "projectile"))
	end)

	it("replaces a weapon's override and leaves its other lines", function()
		local out = IO.applyWeaponEdit(
			WEAPONS,
			"explosion",
			"corint_lrpc",
			"ExplosionXL",
			light("point", { radius = 140, r = 1.5 })
		)
		local t = loadWeapons(out)
		assert.are.equal(140, t.corint_lrpc.config.radius)
		assert.are.equal(1.5, t.corint_lrpc.config.r)
		assert.are.equal(16, t.corint_lrpc.yOffset)
		assert.is_truthy(out:find('explosionLightsNames["armkam_med_emg"] =', 1, true))
	end)

	it("adds a weapon override above the name conversion, never inside a comment", function()
		local out =
			IO.applyWeaponEdit(WEAPONS, "explosion", "armkam_med_emg", "Explosion", light("point", { radius = 26 }))
		local t = loadWeapons(out)
		assert.are.equal(26, t.armkam_med_emg.config.radius)
		assert.are.equal("Explosion", t.armkam_med_emg.base)
		assert.is_truthy(out:find("})\r\n\r\n-- duplicate all weapons for scavengers", 1, true))
	end)

	it("writes into the last block when a unit is in the config twice", function()
		local text = table.concat({
			"local unitLights = {",
			"\tarmgeo = {",
			'\t\ta = { lightType = "point", lightConfig = { radius = 1 } },',
			"\t},",
			"\tarmgeo = {",
			'\t\tb = { lightType = "point", lightConfig = { radius = 2 } },',
			"\t},",
			"}",
			"return unitLights",
			"",
		}, "\n")
		local out = IO.applyEdits(text, "armgeo", { set = { b = light("point", { radius = 7 }) } }, {})
		local t = load(out)
		assert.are.equal(7, t.armgeo.b.lightConfig.radius)
		assert.is_truthy(out:find("a = { lightType", 1, true))
	end)

	it("keeps a block comment whole when the light under it is removed", function()
		local text = table.concat({
			"local unitLights = {",
			"\tarmpw = {",
			"\t\t--[[",
			"\t\told = {},",
			"\t\t--]]",
			"\t\teyes = {",
			'\t\t\tlightType = "point",',
			"\t\t},",
			"\t},",
			"}",
			"return unitLights",
			"",
		}, "\n")
		local out = IO.applyEdits(text, "armpw", { remove = { eyes = true } }, {})
		local t = load(out)
		assert.is_nil(t.armpw.old)
		assert.is_nil(t.armpw.eyes)
	end)

	it("refuses to split a one line block that holds lights, opens an empty one", function()
		local function config(block)
			return "local unitLights = {\n" .. block .. "\n}\nreturn unitLights\n"
		end
		local out, err = IO.applyEdits(
			config('\tarmllt = { glow = { lightType = "point" } },'),
			"armllt",
			{ set = { tip = light("point", { radius = 3 }) } },
			{}
		)
		assert.is_nil(out)
		assert.is_truthy(err:find("one line", 1, true))
		out = IO.applyEdits(
			config("\tarmllt = {}, -- later"),
			"armllt",
			{ set = { tip = light("point", { radius = 3 }) } },
			{}
		)
		assert.are.equal(3, load(out).armllt.tip.lightConfig.radius)
		assert.is_truthy(out:find("-- later", 1, true))
	end)

	it("refuses a second block for a unit written with spaces", function()
		local text = "local unitLights = {\n    armpw = {\n    },\n}\nreturn unitLights\n"
		local out, err = IO.applyEdits(text, "armpw", { set = { eyes = light("point", { radius = 3 }) } }, {})
		assert.is_nil(out)
		assert.is_truthy(err:find("armpw", 1, true))
	end)

	it("quotes a light named after a Lua keyword", function()
		local out = IO.applyEdits(CONFIG, "armpw", { set = { ["end"] = light("point", { radius = 4 }) } }, {})
		assert.is_truthy(out:find('["end"] = {', 1, true))
		assert.are.equal(4, load(out).armpw["end"].lightConfig.radius)
	end)

	it("writes a fade the light turned off when its preset has one", function()
		local presets = { pulse = { lightType = "point", lightConfig = { colortime = 30, color2r = 1 } } }
		local edited = light("point", { radius = 5, colortime = 0, color2r = 0 }, nil, "pulse")
		local out = IO.applyEdits(CONFIG, "armpw", { set = { eyes = edited } }, presets)
		assert.is_truthy(out:find("colortime = 0,", 1, true))
		assert.is_truthy(out:find("color2r = 0,", 1, true))
	end)

	it("replaces an alias line alone, leaving the next override", function()
		local text = table.concat({
			"local explosionLightsNames = {}",
			"explosionLightsNames.armx = explosionLightsNames.army",
			'explosionLightsNames.armz = GetLightClass("Explosion", nil, nil, {',
			"\tr = 3,",
			"})",
			"",
		}, "\n")
		local out = IO.applyWeaponEdit(text, "explosion", "armx", "Explosion", light("point", { radius = 9 }))
		assert.is_truthy(out:find("explosionLightsNames.armz = GetLightClass", 1, true))
		assert.is_truthy(out:find("explosionLightsNames.armx = GetLightClass", 1, true))
		assert.is_falsy(out:find("explosionLightsNames.army", 1, true))
	end)

	it("finds no body in a one line unitLights table", function()
		local units, err = IO.listUnits("local unitLights = {}\nlocal other = {\n}\n")
		assert.is_nil(units)
		assert.is_truthy(err)
	end)

	it("makes presets without placement, with size on request", function()
		local source = light("cone", { posx = 5, dirz = 1, theta = 0.4, radius = 90, r = 1, a = 0.5 })
		assert.is_nil(IO.presetFromLight(source, false).lightConfig.radius)
		local sized = IO.presetFromLight(source, true)
		assert.are.equal(90, sized.lightConfig.radius)
		assert.are.equal(0.4, sized.lightConfig.theta)
		assert.is_nil(sized.lightConfig.posx)
		assert.is_nil(sized.lightConfig.dirz)
		local reread = load(IO.serializePresets({ spot = sized }))
		assert.are.equal(0.5, reread.spot.lightConfig.a)
	end)
end)
