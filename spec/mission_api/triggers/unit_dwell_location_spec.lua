require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and UnitDefs / Spring.GetUnitDefID inside its handler.
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

_G.UnitDefs = { [1] = { name = "armpw" }, [2] = { name = "corfast" } }

local unitDwellLocation = VFS.Include("luarules/mission_api/triggers/unit_dwell_location.lua")
local onGameFrame = unitDwellLocation.callins.GameFrame

describe("mission_api.triggers.unit_dwell_location", function()
	before_each(function()
		Spring.GetUnitDefID = function()
			return 1
		end
	end)

	local function trigger(parameters)
		return { parameters = parameters or {}, settings = {} }
	end

	local function newContext(unitsInArea)
		local fired = 0
		local context = {
			DwellingUnitsInAreas = {},
			DoesUnitHaveName = function()
				return true
			end,
			GetUnitsInArea = function()
				return unitsInArea
			end,
			ActivateTrigger = function()
				fired = fired + 1
				return true
			end,
		}
		return context, function()
			return fired
		end
	end

	local triggerID = "t"
	local area = { x = 0, z = 0, radius = 100 }

	it("declares its type and parameters, requiring an area and duration", function()
		assert.are.equal("UnitDwellLocation", unitDwellLocation.type)
		local names, required = {}, {}
		for _, parameter in ipairs(unitDwellLocation.parameters) do
			names[parameter.name] = true
			if parameter.required then
				required[parameter.name] = true
			end
		end
		assert.are.same({ area = true, duration = true }, required)
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.are.same({ "unitName", "unitDefName" }, unitDwellLocation.parameters.requiresOneOf)
	end)

	it("does not fire before the unit has dwelt for the full duration", function()
		local t = trigger({ area = area, duration = 3, unitDefName = "armpw" })
		local context, fired = newContext({ 100 })
		onGameFrame(t, triggerID, context) -- enters and starts counting at 0
		onGameFrame(t, triggerID, context) -- 1
		assert.are.equal(0, fired())
	end)

	it("fires once the unit has dwelt for the full duration", function()
		local t = trigger({ area = area, duration = 2, unitDefName = "armpw" })
		local context, fired = newContext({ 100 })
		onGameFrame(t, triggerID, context) -- enters, count = 0
		onGameFrame(t, triggerID, context) -- count = 1
		onGameFrame(t, triggerID, context) -- count = 2, meets duration
		assert.are.equal(1, fired())
	end)

	it("does not fire again for the same dwell once activated", function()
		local t = trigger({ area = area, duration = 1, unitDefName = "armpw" })
		local context, fired = newContext({ 100 })
		onGameFrame(t, triggerID, context)
		onGameFrame(t, triggerID, context) -- fires here
		onGameFrame(t, triggerID, context)
		onGameFrame(t, triggerID, context)
		assert.are.equal(1, fired())
	end)

	it("resets the dwell count for a unit that leaves and re-enters", function()
		local t = trigger({ area = area, duration = 2, unitDefName = "armpw" })
		local context, fired = newContext({ 100 })
		onGameFrame(t, triggerID, context)
		context.GetUnitsInArea = function()
			return {}
		end
		onGameFrame(t, triggerID, context) -- unit left, entry removed
		context.GetUnitsInArea = function()
			return { 100 }
		end
		onGameFrame(t, triggerID, context) -- re-enters, count = 0
		onGameFrame(t, triggerID, context) -- count = 1
		assert.are.equal(0, fired())
	end)

	it("filters by unitName at the point of entering the area", function()
		local t = trigger({ area = area, duration = 1, unitName = "scouts" })
		local context, fired = newContext({ 100 })
		context.DoesUnitHaveName = function()
			return false
		end
		onGameFrame(t, triggerID, context)
		onGameFrame(t, triggerID, context)
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName at the point of entering the area", function()
		local t = trigger({ area = area, duration = 1, unitDefName = "corfast" }) -- unitDefID 1 = armpw
		local context, fired = newContext({ 100 })
		onGameFrame(t, triggerID, context)
		onGameFrame(t, triggerID, context)
		assert.are.equal(0, fired())
	end)

	it("tracks multiple units independently", function()
		local t = trigger({ area = area, duration = 1, unitDefName = "armpw" })
		local context, fired = newContext({ 100, 101 })
		onGameFrame(t, triggerID, context)
		onGameFrame(t, triggerID, context)
		assert.are.equal(2, fired())
	end)
end)
