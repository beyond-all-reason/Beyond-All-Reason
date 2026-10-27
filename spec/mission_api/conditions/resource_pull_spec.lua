local Builders = VFS.Include("spec/builders/index.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and Game.gameSpeed / Spring.GetTeamResources inside its handler.
Builders.MissionApi.new():Install()

local resourcePull = MissionSpecEnv.include(env, "luarules/mission_api/conditions/resource_pull.lua")
local onGameFrame = resourcePull.callins.GameFrame

describe("mission_api.conditions.resource_pull", function()
	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.sampledValues
	end

	local triggerID = "t"

	-- Pull comes from a built team, so the tuple GetTeamResources returns keeps the
	-- engine's field order.
	local function resources(metal, energy)
		local team = Builders.Team.new():WithID(0):WithMetalPull(metal):WithEnergyPull(energy or metal)
		return Builders.Spring.new():WithTeam(team):Build().GetTeamResources
	end

	it("declares its type, kind and parameters", function()
		assert.are.equal("ResourcePull", resourcePull.type)
		assert.are.equal("metric", resourcePull.kind)
		local required = {}
		for _, parameter in ipairs(resourcePull.parameters) do
			required[parameter.name] = parameter.required
		end
		assert.are.same({ teamID = true, resource = true }, required)
	end)

	it("only samples once per second", function()
		local context, sampled = newContext()
		env.Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, resource = "metal" }), triggerID, context, 1)
		assert.are.same({}, sampled())
	end)

	it("samples the pull of the named resource", function()
		local context, sampled = newContext()
		env.Spring.GetTeamResources = resources(10, 25)
		onGameFrame(trigger({ teamID = 0, resource = "metal" }), triggerID, context, Game.gameSpeed)
		onGameFrame(trigger({ teamID = 0, resource = "energy" }), triggerID, context, Game.gameSpeed)
		assert.are.same({ 10, 25 }, sampled())
	end)
end)
