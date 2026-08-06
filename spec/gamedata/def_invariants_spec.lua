local Builders = VFS.Include("spec/builders/index.lua")

describe("UnitDefs invariants", function()
	local defs
	local buildable = {}

	setup(function()
		defs = Builders.Spring.new():WithRealUnitDefs():Build():GetUnitDefs()

		for _, def in pairs(defs) do
			for _, option in ipairs(def.buildoptions or {}) do
				buildable[option] = true
			end
		end
	end)

	it("only offers build options that name a real unit", function()
		local missing = {}
		for name, def in pairs(defs) do
			for _, option in ipairs(def.buildoptions or {}) do
				if not defs[option] then
					missing[#missing + 1] = name .. " -> " .. tostring(option)
				end
			end
		end

		assert.same({}, missing)
	end)

	it("gives every unit positive health", function()
		local bad = {}
		for name, def in pairs(defs) do
			local health = def.maxdamage or def.health
			if type(health) ~= "number" or health <= 0 then
				bad[#bad + 1] = name .. " = " .. tostring(health)
			end
		end

		assert.same({}, bad)
	end)

	-- Critters, decorations and spawner helpers cannot be built and have no vision.
	it("gives every buildable unit a sight distance", function()
		local bad = {}
		for name in pairs(buildable) do
			local def = defs[name]
			if def and (type(def.sightdistance) ~= "number" or def.sightdistance <= 0) then
				bad[#bad + 1] = name .. " = " .. tostring(def.sightdistance)
			end
		end

		assert.same({}, bad)
	end)

	it("derives terraformspeed from workertime", function()
		local bad = {}
		for name, def in pairs(defs) do
			if type(def.workertime) == "number" and def.terraformspeed ~= def.workertime * 30 then
				bad[#bad + 1] = name .. " workertime=" .. tostring(def.workertime) .. " terraformspeed=" .. tostring(def.terraformspeed)
			end
		end

		assert.same({}, bad)
	end)

	it("keeps resource customparams paired with the engine fields", function()
		local bad = {}
		for name, def in pairs(defs) do
			local cp = def.customparams or {}

			local extracts = (tonumber(def.extractsmetal) or 0) > 0
			local flagged = (tonumber(cp.metal_extractor) or 0) > 0
			if extracts ~= flagged then
				bad[#bad + 1] = name .. ": extractsmetal=" .. tostring(def.extractsmetal) .. " metal_extractor=" .. tostring(cp.metal_extractor)
			end

			if cp.energyconv_capacity ~= nil or cp.energyconv_efficiency ~= nil then
				if not ((tonumber(cp.energyconv_capacity) or 0) > 0 and (tonumber(cp.energyconv_efficiency) or 0) > 0) then
					bad[#bad + 1] = name .. ": energyconv " .. tostring(cp.energyconv_capacity) .. "/" .. tostring(cp.energyconv_efficiency)
				end
			end
		end

		assert.same({}, bad)
	end)

	it("gives every unit a cost and a build time", function()
		local bad = {}
		for name, def in pairs(defs) do
			if type(def.metalcost) ~= "number" or def.metalcost < 0 then
				bad[#bad + 1] = name .. " metalcost=" .. tostring(def.metalcost)
			end
			if type(def.energycost) ~= "number" or def.energycost < 0 then
				bad[#bad + 1] = name .. " energycost=" .. tostring(def.energycost)
			end
			if type(def.buildtime) ~= "number" or def.buildtime <= 0 then
				bad[#bad + 1] = name .. " buildtime=" .. tostring(def.buildtime)
			end
		end

		assert.same({}, bad)
	end)

	it("keeps wreck and heap hitpoints in step with unit health", function()
		local bad = {}
		for name, def in pairs(defs) do
			local cp = def.customparams or {}
			if def.featuredefs and type(def.health) == "number" and not cp.iscommander and not cp.iseffigy then
				for _, key in ipairs({ "dead", "heap" }) do
					local feature = def.featuredefs[key]
					if feature and feature.damage ~= def.health then
						bad[#bad + 1] = name .. "." .. key .. " damage=" .. tostring(feature.damage) .. " health=" .. tostring(def.health)
					end
				end
			end
		end

		assert.same({}, bad)
	end)

	it("derives vertdisp from the footprint", function()
		local bad = {}
		for name, def in pairs(defs) do
			local footprintx, footprintz = def.footprintx, def.footprintz

			for _, key in ipairs({ "footprintx", "footprintz" }) do
				local value = def[key]
				if type(value) ~= "number" or value % 1 ~= 0 or value < 0 then
					bad[#bad + 1] = name .. "." .. key .. " = " .. tostring(value)
				end
			end

			if type(footprintx) == "number" and type(footprintz) == "number" then
				local expected = math.min(10, 5.5 + (footprintx + footprintz) / 12)
				local actual = tonumber((def.customparams or {}).vertdisp)
				if not actual or math.abs(actual - expected) > 1e-9 then
					bad[#bad + 1] = string.format("%s vertdisp=%s footprint %sx%s wants %s", name, tostring(actual), tostring(footprintx), tostring(footprintz), tostring(expected))
				end
			end
		end

		assert.same({}, bad)
	end)

	it("mirrors yardmap into customparams for the build preview", function()
		local bad = {}
		for name, def in pairs(defs) do
			local exported = (def.customparams or {}).buildsquare_yardmap
			if def.yardmap ~= exported then
				bad[#bad + 1] = string.format("%s yardmap=%s buildsquare_yardmap=%s", name, tostring(def.yardmap), tostring(exported))
			end
		end

		assert.same({}, bad)
	end)

	local function isTriple(value)
		local count = 0
		for token in tostring(value):gmatch("%S+") do
			if not tonumber(token) then return false end
			count = count + 1
		end

		return count == 3
	end

	it("writes volume scales as three numbers", function()
		local bad = {}
		for name, def in pairs(defs) do
			if def.collisionvolumescales ~= nil then
				if not isTriple(def.collisionvolumescales) then
					bad[#bad + 1] = name .. ".collisionvolumescales = " .. tostring(def.collisionvolumescales)
				end
				if def.collisionvolumetype == nil then
					bad[#bad + 1] = name .. " has collisionvolumescales but no collisionvolumetype"
				end
			end

			if def.selectionvolumescales ~= nil and not isTriple(def.selectionvolumescales) then
				bad[#bad + 1] = name .. ".selectionvolumescales = " .. tostring(def.selectionvolumescales)
			end
		end

		assert.same({}, bad)
	end)

	it("points every weapon slot at a weapondef the unit owns", function()
		local bad = {}
		for name, def in pairs(defs) do
			local weaponNames = {}
			for key in pairs(def.weapondefs or {}) do
				weaponNames[tostring(key):lower()] = true
			end

			for slot, weapon in pairs(def.weapons or {}) do
				if type(weapon) ~= "table" or type(weapon.def) ~= "string" then
					bad[#bad + 1] = name .. "[" .. tostring(slot) .. "] has no def string"
				elseif not weaponNames[weapon.def:lower()] then
					bad[#bad + 1] = name .. "[" .. tostring(slot) .. "] -> " .. weapon.def
				end
			end
		end

		assert.same({}, bad)
	end)

	it("pairs turret speed customparams with a real weapon slot", function()
		local bad = {}
		for name, def in pairs(defs) do
			local cp = def.customparams or {}
			local weapons = def.weapons or {}

			for slot = 1, 12 do
				local x = cp["weapon" .. slot .. "turretx"]
				local y = cp["weapon" .. slot .. "turrety"]
				if x ~= nil or y ~= nil then
					if x == nil or y == nil then
						bad[#bad + 1] = name .. " weapon" .. slot .. " turret x/y not paired"
					elseif not tonumber(x) or not tonumber(y) then
						bad[#bad + 1] = name .. " weapon" .. slot .. " turret speed is not numeric"
					end

					if weapons[slot] == nil then
						bad[#bad + 1] = name .. " weapon" .. slot .. " turret speed has no weapon slot"
					end
				end
			end
		end

		assert.same({}, bad)
	end)

	it("only names categories that exist", function()
		local known = {}
		for _, def in pairs(defs) do
			for token in tostring(def.category or ""):gmatch("%S+") do
				known[token] = true
			end
		end

		local bad = {}
		for name, def in pairs(defs) do
			for _, field in ipairs({ "exemptcategory", "nochasecategory", "nochase" }) do
				for token in tostring(def[field] or ""):gmatch("%S+") do
					if not known[token] then
						bad[#bad + 1] = name .. " " .. field .. " " .. token
					end
				end
			end
		end

		assert.same({}, bad)
	end)

	local function isState(value, lowest, highest)
		return type(value) == "number" and value % 1 == 0 and value >= lowest and value <= highest
	end

	it("keeps firestate and movestate inside the engine enums", function()
		local bad = {}
		for name, def in pairs(defs) do
			if def.firestate ~= nil and not isState(def.firestate, -1, 3) then
				bad[#bad + 1] = name .. " firestate = " .. tostring(def.firestate)
			end
			if def.movestate ~= nil and not isState(def.movestate, -1, 2) then
				bad[#bad + 1] = name .. " movestate = " .. tostring(def.movestate)
			end
		end

		assert.same({}, bad)
	end)

	local aircraftOnly = {
		"hoverattack", "turnradius", "maxbank", "maxpitch", "bankingallowed", "crashdrag",
		"wingangle", "wingdrag", "maxrudder", "maxelevator", "maxaileron",
	}

	it("keeps flight tags on aircraft", function()
		local bad = {}
		for name, def in pairs(defs) do
			if def.canfly and def.movementclass then
				bad[#bad + 1] = name .. " flies and has movementclass " .. tostring(def.movementclass)
			end

			for _, tag in ipairs(aircraftOnly) do
				if def[tag] ~= nil and def.canfly ~= true then
					bad[#bad + 1] = name .. " has " .. tag .. " but cannot fly"
				end
			end
		end

		assert.same({}, bad)
	end)

	it("only sets a cloak firestate on units that cloak", function()
		local bad = {}
		for name, def in pairs(defs) do
			local raw = (def.customparams or {}).firestateoncloak
			if raw ~= nil then
				local state = tonumber(raw)
				if not state or state % 1 ~= 0 or state < 0 or state > 3 then
					bad[#bad + 1] = name .. " firestateoncloak = " .. tostring(raw)
				end
				if not def.cancloak and (tonumber(def.cloakcost) or 0) <= 0 then
					bad[#bad + 1] = name .. " sets firestateoncloak but cannot cloak"
				end
			end
		end

		assert.same({}, bad)
	end)

	it("names a movedef that movedefs.lua emits", function()
		-- movedefs.lua reads Game.speedModClasses at load; the spec globals do not define it.
		_G.Game = _G.Game or {}
		local previous = Game.speedModClasses
		Game.speedModClasses = previous or { Tank = 0, KBot = 1, Hover = 2, Ship = 3 }
		local moveDefs = VFS.Include("gamedata/movedefs.lua")
		Game.speedModClasses = previous

		assert.is_true(#(moveDefs or {}) > 0)

		local emitted = {}
		for _, moveDef in ipairs(moveDefs) do
			emitted[moveDef.name] = true
		end

		local bad = {}
		for name, def in pairs(defs) do
			if def.movementclass and not emitted[def.movementclass] then
				bad[#bad + 1] = name .. " -> " .. tostring(def.movementclass)
			end
		end

		assert.same({}, bad)
	end)

	it("leaves a legal water depth window", function()
		local bad = {}
		for name, def in pairs(defs) do
			if def.minwaterdepth and def.maxwaterdepth and def.minwaterdepth >= def.maxwaterdepth then
				bad[#bad + 1] = string.format("%s minwaterdepth=%s maxwaterdepth=%s", name, tostring(def.minwaterdepth), tostring(def.maxwaterdepth))
			end
		end

		assert.same({}, bad)
	end)

	it("gives every declared build distance a positive range", function()
		local bad = {}
		for name, def in pairs(defs) do
			if def.builddistance ~= nil and (type(def.builddistance) ~= "number" or def.builddistance <= 0) then
				bad[#bad + 1] = name .. " builddistance = " .. tostring(def.builddistance)
			end
		end

		assert.same({}, bad)
	end)

	it("keeps build lists well formed and backed by build power", function()
		local bad = {}
		for name, def in pairs(defs) do
			if type(def.buildoptions) ~= "table" then
				bad[#bad + 1] = name .. " buildoptions is " .. type(def.buildoptions)
			else
				local count = 0
				for index, option in pairs(def.buildoptions) do
					count = count + 1
					if type(index) ~= "number" then
						bad[#bad + 1] = name .. " buildoptions has non-array key " .. tostring(index)
					elseif type(option) ~= "string" then
						bad[#bad + 1] = name .. " buildoptions[" .. index .. "] is " .. type(option)
					end
				end

				if count ~= #def.buildoptions then
					bad[#bad + 1] = name .. " buildoptions has a hole"
				end

				if def.buildoptions[1] and (type(def.workertime) ~= "number" or def.workertime <= 0) then
					bad[#bad + 1] = name .. " has a build list but workertime = " .. tostring(def.workertime)
				end
			end
		end

		assert.same({}, bad)
	end)

	it("gives every unit a numeric techlevel", function()
		local bad = {}
		for name, def in pairs(defs) do
			local techlevel = (def.customparams or {}).techlevel
			if techlevel == nil then
				bad[#bad + 1] = name .. " has no techlevel"
			elseif not tonumber(techlevel) then
				bad[#bad + 1] = name .. " techlevel = " .. tostring(techlevel)
			end
		end

		assert.same({}, bad)
	end)

	it("links every scavenger def back to a real parent", function()
		local bad = {}
		for name, def in pairs(defs) do
			local cp = def.customparams or {}
			if cp.isscavenger then
				if not cp.fromunit then
					bad[#bad + 1] = name .. " isscavenger with no fromunit"
				elseif not defs[cp.fromunit] then
					bad[#bad + 1] = name .. " fromunit -> missing def " .. tostring(cp.fromunit)
				end
			elseif cp.fromunit ~= nil then
				bad[#bad + 1] = name .. " carries fromunit " .. tostring(cp.fromunit) .. " without isscavenger"
			end
		end

		assert.same({}, bad)
	end)

	local evolutionConditions = { timer = true, timer_global = true, health = true, power = true, xp = true }
	local healthTransfers = { flat = true, percentage = true, full = true }

	it("keeps evolution customparams inside the values the gadget understands", function()
		local bad = {}
		for name, def in pairs(defs) do
			local cp = def.customparams or {}

			local level = cp.evocomlvl
			if level ~= nil and (type(level) ~= "number" or level % 1 ~= 0 or level < 1 or level > 10) then
				bad[#bad + 1] = name .. " evocomlvl = " .. tostring(level)
			end

			local condition = cp.evolution_condition
			if condition ~= nil and not evolutionConditions[condition] then
				bad[#bad + 1] = name .. " evolution_condition = " .. tostring(condition)
			end
			if cp.evolution_health_transfer ~= nil and not healthTransfers[cp.evolution_health_transfer] then
				bad[#bad + 1] = name .. " evolution_health_transfer = " .. tostring(cp.evolution_health_transfer)
			end

			if (condition == "timer" or condition == "timer_global") and not tonumber(cp.evolution_timer) then
				bad[#bad + 1] = name .. " timer evolution without a numeric evolution_timer"
			end
			if condition == "power" then
				if not tonumber(cp.evolution_power_multiplier) then
					bad[#bad + 1] = name .. " power evolution without evolution_power_multiplier"
				end
				if not tonumber(cp.evolution_power_threshold) then
					bad[#bad + 1] = name .. " power evolution without evolution_power_threshold"
				end
			end
		end

		assert.same({}, bad)
	end)

	it("pairs transport capacity with transport size", function()
		local bad = {}
		for name, def in pairs(defs) do
			local capacity = tonumber(def.transportcapacity) or 0
			local size = tonumber(def.transportsize) or 0

			if capacity > 0 then
				if capacity % 1 ~= 0 then
					bad[#bad + 1] = name .. " transportcapacity = " .. tostring(def.transportcapacity)
				end
				if size <= 0 then
					bad[#bad + 1] = name .. " transportcapacity without transportsize"
				end
			end

			if size > 0 and capacity <= 0 then
				bad[#bad + 1] = name .. " transportsize without transportcapacity"
			end
		end

		assert.same({}, bad)
	end)

	local inheritTokens = { TURRET = true, MOBILEBUILT = true, DRONE = true, BOTCANNON = true }

	it("uses known tokens for inherited xp", function()
		local bad = {}
		for name, def in pairs(defs) do
			local cp = def.customparams or {}
			local usesInherit = false

			for _, key in ipairs({ "childreninheritxp", "parentsinheritxp" }) do
				local list = cp[key]
				if list ~= nil then
					usesInherit = true
					if type(list) ~= "string" then
						bad[#bad + 1] = name .. " " .. key .. " is " .. type(list)
					else
						for token in list:gmatch("%S+") do
							if not inheritTokens[token] then
								bad[#bad + 1] = name .. " " .. key .. " has unknown token " .. token
							end
						end
					end
				end
			end

			if usesInherit then
				local multiplier = tonumber(cp.inheritxpratemultiplier)
				if not multiplier or multiplier <= 0 then
					bad[#bad + 1] = name .. " inherits xp with no positive inheritxpratemultiplier"
				end
			end
		end

		assert.same({}, bad)
	end)

	it("runs the category pass on every non-object def", function()
		local bad = {}
		for name, def in pairs(defs) do
			local category = tostring(def.category or "")
			if not category:find("OBJECT", 1, true) and not category:find("ALL", 1, true) then
				bad[#bad + 1] = name .. " = " .. category
			end
		end

		assert.same({}, bad)
	end)

	it("keeps fall damage multipliers numeric and non-negative", function()
		local bad = {}
		for name, def in pairs(defs) do
			local cp = def.customparams or {}
			for _, key in ipairs({ "fall_damage_multiplier", "water_fall_damage_multiplier" }) do
				local raw = cp[key]
				if raw ~= nil then
					local value = tonumber(raw)
					if not value or value < 0 then
						bad[#bad + 1] = name .. "." .. key .. " = " .. tostring(raw)
					end
				end
			end
		end

		assert.same({}, bad)
	end)

	it("points i18nfromunit at a real translation key", function()
		local json = VFS.Include("common/luaUtilities/json.lua")
		local handle = assert(io.open("language/en/units.json", "r"))
		local contents = handle:read("*a")
		handle:close()
		local names = json.decode(contents).units.names

		local bad = {}
		for name, def in pairs(defs) do
			local proxy = (def.customparams or {}).i18nfromunit
			if proxy ~= nil and not names[proxy] then
				bad[#bad + 1] = name .. " -> units.names." .. tostring(proxy)
			end
		end

		assert.same({}, bad)
	end)

	it("points normaltex at a file that ships", function()
		local checked = {}
		local bad = {}
		for name, def in pairs(defs) do
			local normaltex = (def.customparams or {}).normaltex
			if normaltex ~= nil then
				if type(normaltex) ~= "string" then
					bad[#bad + 1] = name .. " normaltex is " .. type(normaltex)
				else
					if checked[normaltex] == nil then
						checked[normaltex] = VFS.FileExists(normaltex)
					end
					if not checked[normaltex] then
						bad[#bad + 1] = name .. " -> " .. normaltex
					end
				end
			end
		end

		assert.same({}, bad)
	end)

	it("writes paralyzemultiplier as a number", function()
		local bad = {}
		for name, def in pairs(defs) do
			local multiplier = (def.customparams or {}).paralyzemultiplier
			if multiplier ~= nil and (type(multiplier) ~= "number" or multiplier < 0) then
				bad[#bad + 1] = name .. " = " .. tostring(multiplier) .. " (" .. type(multiplier) .. ")"
			end
		end

		assert.same({}, bad)
	end)

	-- Cosmetic hats and shoulder decorations ship mass = 0 on purpose.
	it("gives every damageable unit a positive mass", function()
		local bad = {}
		for name, def in pairs(defs) do
			local cp = def.customparams or {}
			if def.mass ~= nil and not cp.decoration then
				if type(def.mass) ~= "number" or def.mass <= 0 then
					bad[#bad + 1] = name .. " mass = " .. tostring(def.mass)
				end
			end
		end

		assert.same({}, bad)
	end)

	it("writes the durability flags as booleans", function()
		local bad = {}
		for name, def in pairs(defs) do
			for _, key in ipairs({ "repairable", "reclaimable", "capturable", "hidedamage", "leavesghost" }) do
				local value = def[key]
				if value ~= nil and type(value) ~= "boolean" then
					bad[#bad + 1] = name .. "." .. key .. " = " .. tostring(value) .. " (" .. type(value) .. ")"
				end
			end
		end

		assert.same({}, bad)
	end)

	-- weapontype DGun is how the commander D-gun is declared; the engine derives manualFire from it.
	-- dummycom is the pregame placeholder for a random faction choice and ships no weapondefs at all.
	local manualFireExempt = { dummycom = true, dummycom_scav = true }

	it("backs canmanualfire with a manual fire weapon", function()
		local bad = {}
		for name, def in pairs(defs) do
			if (def.canmanualfire or def.candgun) and not manualFireExempt[name] then
				local found = false
				for _, weapon in pairs(def.weapondefs or {}) do
					if type(weapon) == "table" and (weapon.manualfire or weapon.commandfire or tostring(weapon.weapontype or ""):lower() == "dgun") then
						found = true
					end
				end

				if not found then
					bad[#bad + 1] = name
				end
			end
		end

		assert.same({}, bad)
	end)

	it("never makes cloaking cheaper while moving", function()
		local bad = {}
		for name, def in pairs(defs) do
			local standing = tonumber(def.cloakcost)
			local moving = tonumber(def.cloakcostmoving)
			local mobile = (tonumber(def.speed) or 0) > 0 or def.canmove == true

			if mobile and standing and moving and moving < standing then
				bad[#bad + 1] = string.format("%s cloakcost=%s cloakcostmoving=%s", name, tostring(standing), tostring(moving))
			end
		end

		assert.same({}, bad)
	end)

	it("keeps buildangle inside one turn of engine heading", function()
		local bad = {}
		for name, def in pairs(defs) do
			local angle = def.buildangle
			if angle ~= nil and (type(angle) ~= "number" or angle % 1 ~= 0 or angle < 0 or angle > 65536) then
				bad[#bad + 1] = name .. " buildangle = " .. tostring(angle)
			end
		end

		assert.same({}, bad)
	end)

	-- legmohobp is finished but unbuildable and still waiting on its portrait.
	local buildpicExempt = { legmohobp = true, legmohobp_scav = true, legmohobpct = true, legmohobpct_scav = true }

	it("points buildpic at a file that ships", function()
		local checked = {}
		local bad = {}
		for name, def in pairs(defs) do
			local buildpic = def.buildpic
			if buildpic ~= nil and not buildpicExempt[name] then
				if type(buildpic) ~= "string" or buildpic == "" then
					bad[#bad + 1] = name .. " buildpic = " .. tostring(buildpic)
				else
					if checked[buildpic] == nil then
						checked[buildpic] = VFS.FileExists("unitpics/" .. buildpic)
					end
					if not checked[buildpic] then
						bad[#bad + 1] = name .. " -> " .. buildpic
					end
				end
			end
		end

		assert.same({}, bad)
	end)
end)
