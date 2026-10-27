local Builders = VFS.Include("spec/builders/index.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and Spring.GetTeamResources inside its handler.
Builders.MissionApi.new():Install()

local resourceStored = MissionSpecEnv.include(env, "luarules/mission_api/conditions/resource_stored.lua")
local onGameFrame = resourceStored.callins.GameFrame

describe("mission_api.conditions.resource_stored", function()
	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.sampledValues
	end

	local triggerID = "t"

	-- Stored levels come from a built team, so the tuple GetTeamResources returns
	-- keeps the engine's field order.
	local function resources(metal, energy)
		local team = Builders.Team.new():WithID(0):WithMetal(metal):WithEnergy(energy or metal)
		return Builders.Spring.new():WithTeam(team):Build().GetTeamResources
	end

	it("declares its type, kind and parameters", function()
		assert.are.equal("ResourceStored", resourceStored.type)
		assert.are.equal("metric", resourceStored.kind)
		local required = {}
		for _, parameter in ipairs(resourceStored.parameters) do
			required[parameter.name] = parameter.required
		end
		assert.are.same({ teamID = true, resource = true }, required)
	end)

	it("samples every frame, with no interval gate", function()
		local context, sampled = newContext()
		env.Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, resource = "metal" }), triggerID, context)
		assert.are.same({ 10 }, sampled())
	end)

	it("samples the stored amount of the named resource", function()
		local context, sampled = newContext()
		env.Spring.GetTeamResources = resources(10, 25)
		onGameFrame(trigger({ teamID = 0, resource = "metal" }), triggerID, context)
		onGameFrame(trigger({ teamID = 0, resource = "energy" }), triggerID, context)
		assert.are.same({ 10, 25 }, sampled())
	end)

	it("never activates the trigger itself, leaving the bounds to the gadget", function()
		local context = newContext()
		env.Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, resource = "metal" }), triggerID, context)
		assert.are.equal(0, context.timesFired())
	end)
end)
