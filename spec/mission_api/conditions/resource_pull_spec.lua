local TeamBuilder = VFS.Include("spec/builders/team_builder.lua")
local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")
local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local TriggerBuilder = VFS.Include("spec/builders/trigger_builder.lua")
local TriggerContextBuilder = VFS.Include("spec/builders/trigger_context_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and Game.gameSpeed / Spring.GetTeamResources inside its handler.
MissionApiBuilder.new():Install()

local resourcePull = MissionSpecEnv.include(env, "luarules/mission_api/conditions/resource_pull.lua")
local onGameFrame = resourcePull.callins.GameFrame

describe("mission_api.conditions.resource_pull", function()
	local function trigger(parameters)
		return TriggerBuilder.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = TriggerContextBuilder.new():Build()
		return context, context.sampledValues
	end

	local triggerID = "t"

	-- Pull comes from a built team, so the tuple GetTeamResources returns keeps the
	-- engine's field order.
	local function resources(metal, energy)
		local team = TeamBuilder.new():WithID(0):WithMetalPull(metal):WithEnergyPull(energy or metal)
		return SpringSyncedBuilder.new():WithTeam(team):Build().GetTeamResources
	end

	it("declares its type, kind and parameters", function()
		assert.are.equal("ResourcePull", resourcePull.type)
		assert.are.equal("metric", resourcePull.kind)
		local required = {}
		for _, parameter in ipairs(resourcePull.parameters) do
			required[parameter.name] = parameter.required
		end
		assert.are.same({ teamName = true, resource = true }, required)
	end)

	it("only samples once per second", function()
		local context, sampled = newContext()
		env.Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamName = 0, resource = "metal" }), triggerID, context, 1)
		assert.are.same({}, sampled())
	end)

	it("samples the pull of the named resource", function()
		local context, sampled = newContext()
		env.Spring.GetTeamResources = resources(10, 25)
		onGameFrame(trigger({ teamName = 0, resource = "metal" }), triggerID, context, Game.gameSpeed)
		onGameFrame(trigger({ teamName = 0, resource = "energy" }), triggerID, context, Game.gameSpeed)
		assert.are.same({ 10, 25 }, sampled())
	end)
end)
