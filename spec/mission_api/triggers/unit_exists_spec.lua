require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and UnitDefs inside its handler.
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

_G.UnitDefs = { [1] = { name = "armpw" }, [2] = { name = "corfast" } }

local unitExists = VFS.Include("luarules/mission_api/triggers/unit_exists.lua")
local onMetaUnitAdded = unitExists.callins.MetaUnitAdded

describe("mission_api.triggers.unit_exists", function()
	local function trigger(parameters)
		return { parameters = parameters or {}, settings = {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			ActivateTrigger = function()
				fired = fired + 1
			end,
		}
		return context, function()
			return fired
		end
	end

	local triggerID = "t"

	it("declares its type and parameters, requiring unitDefName", function()
		assert.are.equal("UnitExists", unitExists.type)
		assert.are.equal("unitDefName", unitExists.parameters[1].name)
		assert.is_true(unitExists.parameters[1].required)
		assert.are.equal("teamID", unitExists.parameters[2].name)
		assert.is_falsy(unitExists.parameters[2].required)
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		onMetaUnitAdded(trigger({ unitDefName = "corfast" }), triggerID, context, 100, 1, 0) -- unitDefID 1 = armpw
		assert.are.equal(0, fired())
	end)

	it("filters by teamID", function()
		local context, fired = newContext()
		onMetaUnitAdded(trigger({ unitDefName = "armpw", teamID = 5 }), triggerID, context, 100, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("fires for a matching unit", function()
		local context, fired = newContext()
		onMetaUnitAdded(trigger({ unitDefName = "armpw", teamID = 0 }), triggerID, context, 100, 1, 0)
		assert.are.equal(1, fired())
	end)
end)
