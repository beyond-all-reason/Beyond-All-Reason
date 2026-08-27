require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and Spring.GetTeamResources inside its handler.
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

local resourceStored = VFS.Include("luarules/mission_api/triggers/resource_stored.lua")
local onGameFrame = resourceStored.callins.GameFrame

describe("mission_api.triggers.resource_stored", function()
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

	-- select(1, ...) is the current stored level.
	local function resources(level)
		return function()
			return level
		end
	end

	it("declares its type and parameters", function()
		assert.are.equal("ResourceStored", resourceStored.type)
		local names = {}
		for _, parameter in ipairs(resourceStored.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.teamID)
		assert.is_true(names.metal)
		assert.is_true(names.energy)
		assert.are.same({ "metal", "energy" }, resourceStored.parameters.requiresOneOf)
	end)

	it("evaluates every frame, with no interval gate", function()
		local context, fired = newContext()
		Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, metal = 5 }), triggerID, context)
		assert.are.equal(1, fired())
	end)

	it("fires when the stored metal meets the threshold", function()
		local context, fired = newContext()
		Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, metal = 5 }), triggerID, context)
		assert.are.equal(1, fired())
	end)

	it("does not fire when the stored metal is below the threshold", function()
		local context, fired = newContext()
		Spring.GetTeamResources = resources(1)
		onGameFrame(trigger({ teamID = 0, metal = 5 }), triggerID, context)
		assert.are.equal(0, fired())
	end)

	it("fires when the stored energy meets the threshold", function()
		local context, fired = newContext()
		Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, energy = 5 }), triggerID, context)
		assert.are.equal(1, fired())
	end)

	it("requires both thresholds to be met when both are set", function()
		local context, fired = newContext()
		Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, metal = 5, energy = 20 }), triggerID, context)
		assert.are.equal(0, fired())
	end)
end)
