local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/resources/add_resources.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.add_resources", function()

	before_each(function()
		env.Spring = SpringSyncedBuilder.new():Build()
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "AddResources",
			teamID = "TeamID!",
			metal = "Number",
			energy = "Number",
			requiresOneOf = { "metal", "energy" },
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("calls AddTeamResource for positive metal", function()
			action.actionFunction(1, 200, nil)
			assert.are.equal(1, #env.Spring.calls.addTeamResource)
			assert.are.equal(1, env.Spring.calls.addTeamResource[1].teamID)
			assert.are.equal("metal", env.Spring.calls.addTeamResource[1].resource)
			assert.are.equal(200, env.Spring.calls.addTeamResource[1].amount)
		end)

		it("calls UseTeamResource for negative metal", function()
			action.actionFunction(1, -100, nil)
			assert.are.equal(1, #env.Spring.calls.useTeamResource)
			assert.are.equal(1, env.Spring.calls.useTeamResource[1].teamID)
			assert.are.equal("metal", env.Spring.calls.useTeamResource[1].resource)
			assert.are.equal(100, env.Spring.calls.useTeamResource[1].amount)
		end)

		it("skips metal when metal is nil", function()
			action.actionFunction(1, nil, 50)
			-- energy is added, but no metal call should be for 'metal' resource
			local metalAdded = false
			for _, c in ipairs(env.Spring.calls.addTeamResource) do
				if c.resource == "metal" then
					metalAdded = true
				end
			end
			assert.is_false(metalAdded)
			-- energy was added
			assert.are.equal(1, #env.Spring.calls.addTeamResource)
			assert.are.equal("energy", env.Spring.calls.addTeamResource[1].resource)
		end)

		it("calls AddTeamResource for positive energy", function()
			action.actionFunction(2, nil, 500)
			assert.are.equal(1, #env.Spring.calls.addTeamResource)
			assert.are.equal(2, env.Spring.calls.addTeamResource[1].teamID)
			assert.are.equal("energy", env.Spring.calls.addTeamResource[1].resource)
			assert.are.equal(500, env.Spring.calls.addTeamResource[1].amount)
		end)

		it("calls UseTeamResource for negative energy", function()
			action.actionFunction(2, nil, -300)
			assert.are.equal(1, #env.Spring.calls.useTeamResource)
			assert.are.equal(2, env.Spring.calls.useTeamResource[1].teamID)
			assert.are.equal("energy", env.Spring.calls.useTeamResource[1].resource)
			assert.are.equal(300, env.Spring.calls.useTeamResource[1].amount)
		end)

		it("adds both metal and energy when both are positive", function()
			action.actionFunction(0, 100, 200)
			assert.are.equal(2, #env.Spring.calls.addTeamResource)
		end)

		it("does nothing for zero metal", function()
			action.actionFunction(0, 0, nil)
			assert.are.equal(0, #env.Spring.calls.addTeamResource)
			assert.are.equal(0, #env.Spring.calls.useTeamResource)
		end)

		it("does nothing for zero energy", function()
			action.actionFunction(0, nil, 0)
			assert.are.equal(0, #env.Spring.calls.addTeamResource)
			assert.are.equal(0, #env.Spring.calls.useTeamResource)
		end)
	end)

end)
