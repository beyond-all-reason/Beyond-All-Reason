require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and UnitDefs inside its handler.
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

_G.UnitDefs = { [1] = { name = "armpw" }, [2] = { name = "corfast" } }

local unitKilled = VFS.Include("luarules/mission_api/triggers/unit_killed.lua")
local onUnitDestroyed = unitKilled.callins.UnitDestroyed

describe("mission_api.triggers.unit_killed", function()
	local function trigger(parameters)
		return { parameters = parameters or {}, settings = {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			DoesUnitHaveName = function()
				return true
			end,
			ActivateTrigger = function()
				fired = fired + 1
			end,
		}
		return context, function()
			return fired
		end
	end

	local triggerID = "t"

	it("declares its type and parameters", function()
		assert.are.equal("UnitKilled", unitKilled.type)
		local names = {}
		for _, parameter in ipairs(unitKilled.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.are.same({ "unitName", "unitDefName" }, unitKilled.parameters.requiresOneOf)
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		onUnitDestroyed(trigger({ unitName = "engineers" }), triggerID, context, 100, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		onUnitDestroyed(trigger({ unitDefName = "corfast" }), triggerID, context, 100, 1, 0) -- unitDefID 1 = armpw
		assert.are.equal(0, fired())
	end)

	it("filters by teamID", function()
		local context, fired = newContext()
		onUnitDestroyed(trigger({ unitDefName = "armpw", teamID = 5 }), triggerID, context, 100, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("fires for a matching kill", function()
		local context, fired = newContext()
		onUnitDestroyed(trigger({ unitDefName = "armpw", teamID = 0 }), triggerID, context, 100, 1, 0)
		assert.are.equal(1, fired())
	end)
end)
