-- The shared unit library's catalogue (refactor plan, U2 + U7): classification and filter,
-- pure, fed stand-in UnitDefs and WeaponDefs shaped like the engine's. The same calls are
-- checked against the real defs by the harness (the Flea is a scout, the Shellshocker arty...).
local Catalogue = VFS.Include("luaui/RmlWidgets/gui_unit_library/unit_catalogue.lua")

local WEAPONS = {
	[1] = { name = "gun", type = "LaserCannon", range = 180 },
	[2] = { name = "rocket", type = "MissileLauncher", range = 475 },
	[3] = { name = "plasma", type = "Cannon", range = 710, highTrajectory = 1 },
	[4] = { name = "flak", type = "Cannon", range = 700 },
	[5] = { name = "abm", type = "StarburstLauncher", range = 72000, interceptor = 1 },
}

local function gun(id, onlyTargets)
	return { weaponDef = id, onlyTargets = onlyTargets or { notair = true, surface = true } }
end

local function def(name, fields)
	fields.name = name
	fields.customParams = fields.customParams or {}
	return fields
end

-- A small T1 land field: two scouts, raiders, a slow line, skirmishers, arty, AA, a builder,
-- plus buildings, a ship, a hover, a plane, and raptors that must not skew the scale.
local DEFS = {
	def("armflea", {
		humanName = "Flea",
		speed = 132,
		metalCost = 21,
		sightDistance = 600,
		weapons = { gun(1) },
		moveDef = { smClass = 1 },
		customParams = { techlevel = 1, subfolder = "ArmBots" },
	}),
	def("armfav", {
		humanName = "Rover",
		speed = 168,
		metalCost = 31,
		sightDistance = 635,
		weapons = { gun(1) },
		moveDef = { smClass = 0 },
		customParams = { techlevel = 1, subfolder = "ArmVehicles" },
	}),
	def("armpw", {
		humanName = "Pawn",
		speed = 87,
		metalCost = 54,
		sightDistance = 429,
		weapons = { gun(1) },
		moveDef = { smClass = 1 },
		customParams = { techlevel = 1, subfolder = "ArmBots" },
	}),
	def("corak", {
		humanName = "Grunt",
		speed = 81,
		metalCost = 43,
		sightDistance = 520,
		weapons = { gun(1) },
		moveDef = { smClass = 1 },
		customParams = { techlevel = 1, subfolder = "CorBots" },
	}),
	def("armflash", {
		humanName = "Blitz",
		speed = 101,
		metalCost = 110,
		sightDistance = 350,
		weapons = { gun(1) },
		moveDef = { smClass = 0 },
		customParams = { techlevel = 1, subfolder = "ArmVehicles" },
	}),
	def("armwar", {
		humanName = "Warrior",
		speed = 45,
		metalCost = 270,
		sightDistance = 380,
		weapons = { { weaponDef = 1 } },
		moveDef = { smClass = 1 },
		customParams = { techlevel = 1, subfolder = "ArmBots" },
	}),
	def("armstump", {
		humanName = "Stout",
		speed = 75,
		metalCost = 225,
		sightDistance = 350,
		weapons = { gun(1) },
		moveDef = { smClass = 0 },
		customParams = { techlevel = 1, subfolder = "ArmVehicles" },
	}),
	def("armrock", {
		humanName = "Rocketeer",
		speed = 50,
		metalCost = 120,
		sightDistance = 380,
		weapons = { gun(2) },
		moveDef = { smClass = 1 },
		customParams = { techlevel = 1, subfolder = "ArmBots" },
	}),
	def("corstorm", {
		humanName = "Storm",
		speed = 48,
		metalCost = 110,
		sightDistance = 380,
		weapons = { gun(2) },
		moveDef = { smClass = 1 },
		customParams = { techlevel = 1, subfolder = "CorBots" },
	}),
	def("armart", {
		humanName = "Shellshocker",
		speed = 54,
		metalCost = 135,
		sightDistance = 364,
		weapons = { gun(3) },
		moveDef = { smClass = 0 },
		customParams = { techlevel = 1, subfolder = "ArmVehicles" },
	}),
	def("armjeth", {
		humanName = "Crossbow",
		speed = 56,
		metalCost = 125,
		sightDistance = 380,
		weapons = { gun(4, { vtol = true }) },
		moveDef = { smClass = 1 },
		customParams = { techlevel = 1, subfolder = "ArmBots", unitgroup = "aa" },
	}),
	def("armck", {
		humanName = "Construction Bot",
		speed = 40,
		metalCost = 110,
		sightDistance = 300,
		isBuilder = true,
		buildOptions = { 1, 2 },
		moveDef = { smClass = 1 },
		customParams = { techlevel = 1, subfolder = "ArmBots", unitgroup = "builder" },
	}),
	def("armscab", {
		humanName = "Umbrella",
		speed = 51,
		metalCost = 1150,
		sightDistance = 450,
		weapons = { gun(5) },
		moveDef = { smClass = 1 },
		customParams = { techlevel = 2, subfolder = "ArmBots/T2", unitgroup = "antinuke" },
	}),
	def("armsolar", {
		humanName = "Solar Collector",
		isBuilding = true,
		speed = 0,
		metalCost = 150,
		customParams = { techlevel = 1, subfolder = "ArmBuildings/LandEconomy", unitgroup = "energy" },
	}),
	def("armllt", {
		humanName = "Sentry",
		isBuilding = true,
		speed = 0,
		metalCost = 85,
		weapons = { gun(1) },
		customParams = { techlevel = 1, subfolder = "ArmBuildings/LandDefenceOffence", unitgroup = "weapon" },
	}),
	def("armlab", {
		humanName = "Bot Lab",
		isBuilding = true,
		speed = 0,
		metalCost = 500,
		buildOptions = { 1, 2, 3, 4, 5, 6 },
		customParams = { techlevel = 1, subfolder = "ArmBuildings/LandFactories", unitgroup = "builder" },
	}),
	def("armradar", {
		humanName = "Radar Tower",
		isBuilding = true,
		speed = 0,
		metalCost = 55,
		customParams = { techlevel = 1, subfolder = "ArmBuildings/LandUtil", unitgroup = "util" },
	}),
	def("armtide", {
		humanName = "Tidal Generator",
		isBuilding = true,
		speed = 0,
		metalCost = 90,
		minWaterDepth = 20,
		customParams = { techlevel = 1, subfolder = "ArmBuildings/SeaEconomy", unitgroup = "energy" },
	}),
	def("armpt", {
		humanName = "Skater",
		speed = 110,
		metalCost = 90,
		sightDistance = 500,
		weapons = { gun(1) },
		moveDef = { smClass = 3 },
		minWaterDepth = 6,
		customParams = { techlevel = 1, subfolder = "ArmShips" },
	}),
	def("armsh", {
		humanName = "Skimmer",
		speed = 120,
		metalCost = 70,
		sightDistance = 450,
		weapons = { gun(1) },
		moveDef = { smClass = 2 },
		customParams = { techlevel = 1, subfolder = "ArmHovercraft" },
	}),
	def("armpeep", {
		humanName = "Peeper",
		canFly = true,
		speed = 375,
		metalCost = 52,
		sightDistance = 865,
		customParams = { techlevel = 1, subfolder = "ArmAircraft", unitgroup = "util" },
	}),
	def("armthund", {
		humanName = "Stormbringer",
		canFly = true,
		speed = 250,
		metalCost = 150,
		sightDistance = 430,
		weapons = { gun(1) },
		customParams = { techlevel = 1, subfolder = "ArmAircraft" },
	}),
	def("armsfig", {
		humanName = "Seaplane Fighter",
		canFly = true,
		speed = 300,
		metalCost = 90,
		sightDistance = 430,
		weapons = { gun(4, { vtol = true }) },
		customParams = { techlevel = 2, subfolder = "ArmSeaplanes", unitgroup = "aa" },
	}),
	def("raptor1", {
		humanName = "Raptor",
		speed = 200,
		metalCost = 5,
		sightDistance = 900,
		weapons = { gun(1) },
		moveDef = { smClass = 1 },
		customParams = { techlevel = 1, subfolder = "other/raptors" },
	}),
	def("raptor2", {
		humanName = "Raptor Two",
		speed = 210,
		metalCost = 6,
		sightDistance = 900,
		weapons = { gun(1) },
		moveDef = { smClass = 1 },
		customParams = { techlevel = 1, subfolder = "other/raptors" },
	}),
	def("editorgodbuilder", { humanName = "God Builder", speed = 100 }),
}

local PICS = { ["unitpics/armpw.dds"] = true, ["unitpics/armsolar.dds"] = true }

local function build()
	return Catalogue.build(DEFS, function(path)
		return PICS[path] == true
	end, { bot = { bitmap = "icons/bot.png" } }, WEAPONS)
end

local function byName()
	local out = {}
	for _, entry in ipairs(build()) do
		out[entry.name] = entry
	end
	return out
end

local function names(entries)
	local out = {}
	for index, entry in ipairs(entries) do
		out[index] = entry.name
	end
	table.sort(out)
	return out
end

local function set(...)
	local out = {}
	for _, value in ipairs({ ... }) do
		out[value] = true
	end
	return out
end

describe("unit_catalogue", function()
	-- PtaQ, 2026-09-27: sort by power (from cost), type, size and more.
	describe("sort", function()
		local function e(name, fields)
			return {
				name = name,
				human = fields.human or name,
				hasPic = fields.hasPic ~= false,
				type = fields.type or "bot",
				tier = fields.tier or 1,
				stats = {
					power = fields.power or 0,
					footprint = fields.footprint or 0,
					speed = fields.speed or 0,
					range = fields.range or 0,
					health = fields.health or 0,
				},
			}
		end
		local list = {
			e("a", { human = "Alpha", power = 50, type = "veh", footprint = 9 }),
			e("b", { human = "Bravo", power = 300, type = "bot", footprint = 4 }),
			e("c", { human = "Charlie", power = 120, type = "bot", footprint = 16 }),
		}
		local function names(sorted)
			local out = {}
			for index, entry in ipairs(sorted) do
				out[index] = entry.name
			end
			return table.concat(out, "")
		end

		it("sorts by power, biggest first or last", function()
			assert.are.equal("bca", names(Catalogue.sort(list, "power", true)))
			assert.are.equal("acb", names(Catalogue.sort(list, "power", false)))
		end)

		it("sorts by type in the chips' order, the strongest first within a type", function()
			assert.are.equal("bca", names(Catalogue.sort(list, "type", false)))
		end)

		it("sorts by footprint size", function()
			assert.are.equal("cab", names(Catalogue.sort(list, "size", true)))
		end)

		it("by name is the catalogue's own order, and reverses", function()
			assert.are.equal("abc", names(Catalogue.sort(list, "name", false)))
			assert.are.equal("cba", names(Catalogue.sort(list, "name", true)))
		end)

		it("returns a copy and knows its keys", function()
			local sorted = Catalogue.sort(list, "power", true)
			assert.are_not.equal(list, sorted)
			assert.are.equal("a", list[1].name)
			assert.is_true(Catalogue.sortKnown("health"))
			assert.is_false(Catalogue.sortKnown("colour"))
			assert.is_true(Catalogue.sortDefaultDesc("power"))
			assert.is_false(Catalogue.sortDefaultDesc("name"))
		end)

		it("reads power, health and footprint off a unit def", function()
			local stats = Catalogue.statsOf(
				{ metalCost = 100, energyCost = 1200, health = 900, xsize = 4, zsize = 6, speed = 50 },
				{}
			)
			assert.are.equal(120, stats.power)
			assert.are.equal(900, stats.health)
			assert.are.equal(6, stats.footprint)
		end)
	end)

	describe("build", function()
		it("offers every unit but editor furniture, pictures first", function()
			local entries = build()
			assert.are.equal(#DEFS - 1, #entries)
			assert.are.equal("armpw", entries[1].name)
			assert.is_nil(byName().editorgodbuilder)
		end)

		it("falls back to a blank picture", function()
			assert.are.equal("/unitpics/armpw.dds", byName().armpw.img)
			assert.are.equal("/icons/inverted/blank.png", byName().armflea.img)
		end)
	end)

	describe("type and domain", function()
		local e = byName()
		it("reads bots, vehicles, ships, hovercraft, aircraft and seaplanes", function()
			assert.are.equal("bot", e.armpw.type)
			assert.are.equal("veh", e.armfav.type)
			assert.are.equal("ship", e.armpt.type)
			assert.are.equal("hover", e.armsh.type)
			assert.are.equal("air", e.armpeep.type)
			assert.are.equal("seaplane", e.armsfig.type)
		end)

		it("sorts buildings into turret, eco, util and factory", function()
			assert.are.equal("turret", e.armllt.type)
			assert.are.equal("eco", e.armsolar.type)
			assert.are.equal("util", e.armradar.type)
			assert.are.equal("factory", e.armlab.type)
		end)

		it("gives a hovercraft land AND sea, a ship and a sea building sea, a plane air", function()
			assert.are.same(set("land", "sea"), e.armsh.domains)
			assert.are.same(set("sea"), e.armpt.domains)
			assert.are.same(set("sea"), e.armtide.domains)
			assert.are.same(set("air"), e.armpeep.domains)
			assert.are.same(set("land"), e.armpw.domains)
		end)
	end)

	describe("roles, inferred against the same tier and domain", function()
		local e = byName()
		it("calls a mobile unit with build options a builder, and only that", function()
			assert.are.same(set("builder"), e.armck.roles)
		end)

		it("calls a unit whose guns only reach aircraft AA", function()
			assert.are.same(set("aa"), e.armjeth.roles)
		end)

		it("finds scouts by sight for the cost and speed, not by being cheap alone", function()
			assert.is_true(e.armflea.roles.scout == true)
			assert.is_true(e.armfav.roles.scout == true)
			assert.is_nil(e.corak.roles.scout, "the Grunt is cheap but slow")
			assert.is_nil(e.armpw.roles.scout, "the Pawn is quick but short-sighted")
		end)

		it("finds raiders: quick, cheap, short-ranged", function()
			assert.is_true(e.armpw.roles.raider == true)
			assert.is_nil(e.armwar.roles.raider, "slow and dear")
		end)

		it("finds skirmishers by range, and artillery by a lobbed weapon", function()
			assert.is_true(e.armrock.roles.skirmish == true)
			assert.is_true(e.armart.roles.arty == true)
			assert.is_nil(e.armart.roles.skirmish, "artillery, not both")
		end)

		it("does not count an interceptor as a gun", function()
			assert.is_nil(e.armscab.roles.arty)
			assert.is_false(e.armscab.stats.armed)
		end)

		it(
			"gives aircraft only air roles: an unarmed long-sighted plane scouts, a bomber is not a skirmisher",
			function()
				assert.is_true(e.armpeep.roles.scout == true)
				assert.is_nil(e.armthund.roles.skirmish)
				assert.is_nil(e.armthund.roles.arty)
			end
		)

		it("does not let raptors set the scale", function()
			-- Two fast, cheap, far-sighted raptors would otherwise push the Flea out of the top.
			assert.is_true(e.armflea.roles.scout == true)
		end)
	end)

	describe("filter", function()
		local entries = build()

		it("ANDs the rows and ORs within one", function()
			assert.are.same(
				{ "armpw" },
				names(Catalogue.filter(entries, { faction = set("arm"), type = set("bot"), role = set("raider") }))
			)
			local both = names(Catalogue.filter(entries, { type = set("ship", "hover") }))
			assert.are.same({ "armpt", "armsh" }, both)
		end)

		it("reads a domain row as a set: ALL SEA includes the hovercraft", function()
			local sea = names(Catalogue.filter(entries, { domain = set("sea") }))
			assert.are.same({ "armpt", "armsh", "armtide" }, sea)
		end)

		it("searches names and tags, every word", function()
			assert.are.same({ "armart" }, names(Catalogue.filter(entries, { search = "t1 arty arm" })))
			assert.are.same({ "armpw" }, names(Catalogue.filter(entries, { search = "  PAWN " })))
			assert.are.same({ "armsfig" }, names(Catalogue.filter(entries, { search = "seaplane" })))
		end)

		it("treats an empty row as no filter", function()
			assert.are.equal(#entries, #Catalogue.filter(entries, { faction = {}, tier = {} }))
		end)

		it("counts each chip as if it were the only choice in its row", function()
			local counts = Catalogue.counts(entries, { faction = set("arm"), type = set("bot") })
			-- The faction row is ignored for its own counts: COR would show its two bots.
			assert.are.equal(2, counts.faction.cor, "the Grunt and the Storm")
			-- The type row is ignored for its own counts: ARM has two aircraft, one seaplane.
			assert.are.equal(2, counts.type.air)
			assert.are.equal(1, counts.type.seaplane)
			-- Other rows are counted under BOTH filters: ARM bots that raid is the Pawn alone.
			assert.are.equal(1, counts.role.raider)
		end)
	end)

	describe("toggle", function()
		it("plain: that value alone; again: clear the row", function()
			assert.are.same(set("arm"), Catalogue.toggle({}, "arm", false))
			assert.are.same(set("cor"), Catalogue.toggle(set("arm"), "cor", false))
			assert.are.same({}, Catalogue.toggle(set("arm"), "arm", false))
		end)

		it("shift: add, and remove", function()
			assert.are.same(set("arm", "cor"), Catalogue.toggle(set("arm"), "cor", true))
			assert.are.same(set("cor"), Catalogue.toggle(set("arm", "cor"), "arm", true))
		end)
	end)

	it("remembers recent picks most-recent-first, without repeats, up to a limit", function()
		local recent = Catalogue.remember({}, "armpw")
		recent = Catalogue.remember(recent, "corak")
		recent = Catalogue.remember(recent, "armpw")
		assert.are.same({ "armpw", "corak" }, recent)
		assert.are.equal(2, #Catalogue.remember({ "a", "b", "c" }, "d", 2))
	end)
end)
