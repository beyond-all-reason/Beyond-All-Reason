local RealUnitDefs = require("spec/support/real_unit_defs")

local HOLIDAY_MODELS_PATH = "unitbasedefs/holiday_models.lua"

local function isEventModel(objectName)
	return objectName ~= nil and objectName:lower():find("units/event/", 1, true) ~= nil
end

-- alldefs_post looks units up by name with any _scav suffix removed, so scavenger copies match too.
local function listedEntry(models, unitName)
	return models[unitName] or models[(unitName:gsub("_scav$", ""))]
end

-- A decoy commander that looks different from its commander gives itself away.
local function decoyMismatches(defs)
	local bad = {}
	for unitName, def in pairs(defs) do
		local isDecoy = def.customparams.isdecoycommander and def.decoyfor
		local commander = isDecoy and defs[def.decoyfor]
		if isDecoy and not commander then
			bad[#bad + 1] = unitName .. " is a decoy for a missing " .. def.decoyfor
		elseif commander then
			if def.objectname ~= commander.objectname then
				bad[#bad + 1] = string.format(
					"%s wears %s, %s wears %s",
					unitName,
					tostring(def.objectname),
					def.decoyfor,
					tostring(commander.objectname)
				)
			end
			if def.customparams.holidayhatcount ~= commander.customparams.holidayhatcount then
				bad[#bad + 1] = string.format(
					"%s has %s hats, %s has %s",
					unitName,
					tostring(def.customparams.holidayhatcount),
					def.decoyfor,
					tostring(commander.customparams.holidayhatcount)
				)
			end
		end
	end
	table.sort(bad)
	return bad
end

describe("holiday unit defs", function()
	local holidayModels = VFS.Include(HOLIDAY_MODELS_PATH)
	local regular ---@type table

	setup(function()
		regular = RealUnitDefs.byName({}, {})
	end)

	describe("outside every event", function()
		it("keeps the regular models", function()
			local bad = {}
			for name, def in pairs(regular) do
				if isEventModel(def.objectname) then
					bad[#bad + 1] = name .. ": " .. def.objectname
				end
			end
			assert.same({}, bad)
		end)

		it("bakes in no hats", function()
			local bad = {}
			for name, def in pairs(regular) do
				if def.customparams.holidayhatcount ~= nil then
					bad[#bad + 1] = name
				end
			end
			assert.same({}, bad)
		end)

		it("dresses decoy commanders like their commander", function()
			assert.same({}, decoyMismatches(regular))
		end)
	end)

	-- GetCurrentHolidays names each event by its holiday_models key in lower case.
	for modelsKey, models in pairs(holidayModels) do
		local holiday = modelsKey:lower()

		describe("during " .. holiday, function()
			local defs ---@type table

			setup(function()
				defs = RealUnitDefs.byName({}, { [holiday] = true })
			end)

			it("swaps in the event model for each listed unit and its scavenger copy", function()
				local bad = {}
				for unitName in pairs(models) do
					if not defs[unitName] then
						bad[#bad + 1] = unitName .. " has no def"
					end
				end
				for unitName, def in pairs(defs) do
					local entry = listedEntry(models, unitName)
					if entry and def.objectname ~= entry.model then
						bad[#bad + 1] =
							string.format("%s: %s, expected %s", unitName, tostring(def.objectname), entry.model)
					end
				end
				assert.same({}, bad)
			end)

			it("stamps the baked-in hat count for each listed unit and its scavenger copy", function()
				local bad = {}
				for unitName, def in pairs(defs) do
					local entry = listedEntry(models, unitName)
					if entry and def.customparams.holidayhatcount ~= entry.hats then
						bad[#bad + 1] = string.format(
							"%s: holidayhatcount = %s, expected %s",
							unitName,
							tostring(def.customparams.holidayhatcount),
							tostring(entry.hats)
						)
					end
				end
				assert.same({}, bad)
			end)

			-- Some defs pick their model at random, so this compares kinds of model, not names.
			it("leaves every other unit's model alone", function()
				local bad = {}
				for unitName, def in pairs(defs) do
					if not listedEntry(models, unitName) then
						if not regular[unitName] then
							bad[#bad + 1] = unitName .. " only exists during the event"
						elseif isEventModel(def.objectname) then
							bad[#bad + 1] = unitName .. ": " .. tostring(def.objectname)
						elseif def.customparams.holidayhatcount ~= nil then
							bad[#bad + 1] = unitName .. " has baked-in hats"
						end
					end
				end
				for unitName in pairs(regular) do
					if not defs[unitName] then
						bad[#bad + 1] = unitName .. " is missing during the event"
					end
				end
				assert.same({}, bad)
			end)

			it("dresses decoy commanders like their commander", function()
				assert.same({}, decoyMismatches(defs))
			end)
		end)
	end
end)
