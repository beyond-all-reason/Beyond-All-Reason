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
end)
