require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and Game.gameSpeed / Spring.GetTeamResources inside its handler.
Builders.MissionApi.new():Install()

local resourcePull = VFS.Include("luarules/mission_api/triggers/resource_pull.lua")
local onGameFrame = resourcePull.callins.GameFrame

describe("mission_api.triggers.resource_pull", function()
	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.timesFired
	end

	local triggerID = "t"

	-- Pull comes from a built team, so the tuple GetTeamResources returns keeps the
	-- engine's field order.
	local function resources(pull)
		local team = Builders.Team.new():WithID(0):WithMetalPull(pull):WithEnergyPull(pull)
		return Builders.Spring.new():WithTeam(team):Build().GetTeamResources
	end

	it("declares its type and parameters", function()
		assert.are.equal("ResourcePull", resourcePull.type)
		local names = {}
		for _, parameter in ipairs(resourcePull.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.teamID)
		assert.is_true(names.metal)
		assert.is_true(names.energy)
		assert.are.same({ "metal", "energy" }, resourcePull.parameters.requiresOneOf)
	end)

	it("only evaluates once per second", function()
		local context, fired = newContext()
		Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, metal = 5 }), triggerID, context, 1)
		assert.are.equal(0, fired())
	end)

	it("fires when metal pull meets the threshold", function()
		local context, fired = newContext()
		Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, metal = 5 }), triggerID, context, Game.gameSpeed)
		assert.are.equal(1, fired())
	end)

	it("does not fire when metal pull is below the threshold", function()
		local context, fired = newContext()
		Spring.GetTeamResources = resources(1)
		onGameFrame(trigger({ teamID = 0, metal = 5 }), triggerID, context, Game.gameSpeed)
		assert.are.equal(0, fired())
	end)

	it("fires when energy pull meets the threshold", function()
		local context, fired = newContext()
		Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, energy = 5 }), triggerID, context, Game.gameSpeed)
		assert.are.equal(1, fired())
	end)

	it("requires both thresholds to be met when both are set", function()
		local context, fired = newContext()
		Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, metal = 5, energy = 20 }), triggerID, context, Game.gameSpeed)
		assert.are.equal(0, fired())
	end)
end)
