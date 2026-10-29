local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")
local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/units/despawn_units.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local function seedUnits(name, ...)
	local builder = MissionApiBuilder.new()
	for _, unitID in ipairs({ ... }) do
		builder:WithTrackedUnit(name, unitID)
	end
	builder:Install()
end

describe("mission_api.actions.despawn_units", function()

	local destroyCalls, addResourceCalls

	before_each(function()
		MissionApiBuilder.new():Install()
		env.Spring = SpringSyncedBuilder.new():Build()
		destroyCalls = env.Spring.calls.destroyUnit
		addResourceCalls = env.Spring.calls.addTeamResource
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "DespawnUnits",
			unitName = "UnitName!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("is a no-op for an untracked unit name", function()
			action.actionFunction("ghost")

			assert.are.equal(0, #destroyCalls)
		end)

		it("removes the unit silently, with no wreck and no explosion", function()
			seedUnits("scout", 3)

			action.actionFunction("scout")

			assert.are.equal(1, #destroyCalls)
			assert.are.equal(3, destroyCalls[1].unitID)
			assert.is_false(destroyCalls[1].selfd)
			assert.is_true(destroyCalls[1].reclaimed)
		end)

		it("grants no resources, unlike ReclaimUnits", function()
			seedUnits("scout", 3)

			action.actionFunction("scout")

			assert.are.equal(0, #addResourceCalls)
		end)

		it("despawns every unit tracked under the name", function()
			seedUnits("squad", 1, 2, 3)

			action.actionFunction("squad")

			assert.are.equal(3, #destroyCalls)
		end)

		it("skips dead units", function()
			seedUnits("dead", 5)
			env.Spring.GetUnitIsDead = function(unitID)
				return true
			end

			action.actionFunction("dead")

			assert.are.equal(0, #destroyCalls)
		end)

		it("only affects units tracked under the given name", function()
			MissionApiBuilder.new():WithTrackedUnit("scouts", 1):WithTrackedUnit("tanks", 2):Install()

			action.actionFunction("scouts")

			assert.are.equal(1, #destroyCalls)
			assert.are.equal(1, destroyCalls[1].unitID)
		end)
	end)

end)
