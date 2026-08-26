require("spec_helper")

local RegisterMissionApiModules = require("mission_api.spec_helper")

-- Condition descriptors read GG['MissionAPI'].Modules at load time. Registering
-- through the shared helper keeps this in step as descriptors take on new
-- module dependencies (detection levels, seismic contacts, and so on).
RegisterMissionApiModules()

local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local CONDITIONS_DIR = 'luarules/mission_api/conditions/'

-- Loaded straight off disk rather than through the loader, so this spec fails
-- when a descriptor file is wrong even if the loader would paper over it.
local descriptors = {}
for _, filePath in ipairs(VFS.DirList(CONDITIONS_DIR, '*.lua')) do
	local descriptor = VFS.Include(filePath)
	descriptors[descriptor.type] = { descriptor = descriptor, fileName = filePath:match('([^/]+)$') }
end

--- Metrics are levels: a value sampled now, which can move in either direction.
--- Everything else is an event: an occurrence, tallied upwards.
---
--- This list is deliberately explicit rather than derived. Membership is a
--- design decision per type, and the previous proxy for it ("declares a
--- Quantity parameter") was wrong in both directions: the cumulative
--- TotalUnits* tallies are events, and the Resource* levels are metrics.
local EXPECTED_METRICS = {
	ResourceIncome = true,
	ResourcePull   = true,
	ResourceStored = true,
	UnitsOwned     = true,
}

describe("mission_api.conditions", function()

	it("loads every descriptor with a type", function()
		assert.is_true(next(descriptors) ~= nil)
		for conditionType, entry in pairs(descriptors) do
			assert.is_string(conditionType, entry.fileName .. " must declare a string type")
		end
	end)

	it("declares a valid kind on every condition", function()
		local invalid = {}
		for conditionType, entry in pairs(descriptors) do
			local kind = entry.descriptor.kind
			if kind ~= 'event' and kind ~= 'metric' then
				invalid[#invalid + 1] = conditionType .. " (" .. tostring(kind) .. ")"
			end
		end
		table.sort(invalid)
		assert.are.same({}, invalid)
	end)

	it("classifies exactly the known levels as metrics", function()
		local actualMetrics = {}
		for conditionType, entry in pairs(descriptors) do
			if entry.descriptor.kind == 'metric' then
				actualMetrics[conditionType] = true
			end
		end
		assert.are.same(EXPECTED_METRICS, actualMetrics)
	end)

	it("treats the cumulative TotalUnits tallies as events, not metrics", function()
		-- They only ever increase, so they are occurrences being counted.
		for _, conditionType in ipairs({
			'TotalUnitsBuilt', 'TotalUnitsCaptured', 'TotalUnitsKilled', 'TotalUnitsLost',
		}) do
			local entry = descriptors[conditionType]
			assert.is_not_nil(entry, conditionType .. " should exist")
			assert.are.equal('event', entry.descriptor.kind, conditionType .. " should be an event")
		end
	end)

	it("treats the Resource levels as metrics, despite declaring no Quantity", function()
		for _, conditionType in ipairs({ 'ResourceStored', 'ResourceIncome', 'ResourcePull' }) do
			local entry = descriptors[conditionType]
			assert.is_not_nil(entry, conditionType .. " should exist")
			assert.are.equal('metric', entry.descriptor.kind, conditionType .. " should be a metric")
		end
	end)

	it("gives every condition a parameters table", function()
		for conditionType, entry in pairs(descriptors) do
			assert.is_table(entry.descriptor.parameters or {}, conditionType)
		end
	end)

	it("declares every parameter with a name and a known type", function()
		local problems = {}
		for conditionType, entry in pairs(descriptors) do
			for _, parameter in ipairs(entry.descriptor.parameters or {}) do
				if type(parameter.name) ~= 'string' then
					problems[#problems + 1] = conditionType .. ": parameter without a name"
				elseif ParameterTypes[parameter.type] == nil then
					problems[#problems + 1] = conditionType .. "." .. parameter.name
						.. ": unknown type " .. tostring(parameter.type)
				end
			end
		end
		table.sort(problems)
		assert.are.same({}, problems)
	end)

end)
