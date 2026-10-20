local RealUnitDefs = require("spec/support/real_unit_defs")

local HOLIDAY_MODELS_PATH = "unitbasedefs/holiday_models.lua"

-- first difference between two values, empty when they are equal
local function differences(before, after, path, found, skip)
	found = found or {}
	if type(before) ~= "table" or type(after) ~= "table" then
		if before ~= after then
			found[#found + 1] = string.format("%s: %s -> %s", path, tostring(before), tostring(after))
		end
		return found
	end
	local keys = {}
	for key in pairs(before) do
		keys[key] = true
	end
	for key in pairs(after) do
		keys[key] = true
	end
	for key in pairs(keys) do
		if not (skip and skip[key]) then
			differences(before[key], after[key], path .. "." .. tostring(key), found, skip)
		end
	end
	return found
end

local WRECK_MODEL = { object = true }

describe("holiday wrecks have only visual differences", function()
	local holidayModels = VFS.Include(HOLIDAY_MODELS_PATH)
	local regular ---@type table

	setup(function()
		regular = RealUnitDefs.byName({}, {})
	end)

	for modelsKey in pairs(holidayModels) do
		local holiday = modelsKey:lower()

		describe("during " .. holiday, function()
			local defs ---@type table<string, table?>

			setup(function()
				defs = RealUnitDefs.byName({}, { [holiday] = true })
			end)

			it("keep everything but their model", function()
				local bad = {}
				for unitName, before in pairs(regular) do
					local after = defs[unitName]
					if after then
						differences(before.corpse, after.corpse, unitName .. ".corpse", bad)
						differences(before.featuredefs, after.featuredefs, unitName .. ".featuredefs", bad, WRECK_MODEL)
					end
				end
				table.sort(bad)
				assert.same({}, bad)
			end)

			it("show a model that exists when they change it", function()
				local bad = {}
				for unitName, before in pairs(regular) do
					local after = defs[unitName]
					for featureName, feature in pairs(after and after.featuredefs or {}) do
						local old = before.featuredefs and before.featuredefs[featureName]
						if feature.object and (not old or old.object ~= feature.object) then
							if not VFS.FileExists("objects3d/" .. feature.object) then
								bad[#bad + 1] = unitName .. "." .. featureName .. ": " .. feature.object
							end
						end
					end
				end
				table.sort(bad)
				assert.same({}, bad)
			end)
		end)
	end
end)
