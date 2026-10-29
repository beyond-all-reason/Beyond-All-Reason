local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")
local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/units/transfer_units.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local function seedUnits(name, ...)
	local builder = MissionApiBuilder.new()
	for _, unitID in ipairs({ ... }) do
		builder:WithTrackedUnit(name, unitID)
	end
	builder:Install()
end

describe("mission_api.actions.transfer_units", function()

	before_each(function()
		MissionApiBuilder.new():Install()
		env.Spring = SpringSyncedBuilder.new():Build()
		-- No teams are registered on the mock, so pin ally teams explicitly.
		env.Spring.GetUnitAllyTeam = function(id)
			return 0
		end
		env.Spring.GetTeamAllyTeamID = function(teamID)
			return 1
		end -- different ally team by default
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "TransferUnits",
			unitName = "UnitName!",
			newTeam = "TeamID!",
			captured = "Boolean",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("is a no-op for an untracked unit name", function()
			action.actionFunction("ghost", 1)
			assert.are.equal(0, #env.Spring.calls.transferUnit)
		end)

		it("calls Spring.TransferUnit for each tracked unit", function()
			seedUnits("bots", 10, 11)
			action.actionFunction("bots", 2)
			assert.are.equal(2, #env.Spring.calls.transferUnit)
		end)

		it("passes given=true when the unit is already on the same ally team", function()
			seedUnits("scout", 5)
			env.Spring.GetUnitAllyTeam = function(id)
				return 1
			end
			env.Spring.GetTeamAllyTeamID = function(teamID)
				return 1
			end
			action.actionFunction("scout", 2)
			assert.is_true(env.Spring.calls.transferUnit[1].given)
		end)

		it("passes given=false when the unit is on a different ally team", function()
			seedUnits("enemy", 6)
			env.Spring.GetUnitAllyTeam = function(id)
				return 0
			end
			env.Spring.GetTeamAllyTeamID = function(teamID)
				return 1
			end
			action.actionFunction("enemy", 3)
			assert.is_false(env.Spring.calls.transferUnit[1].given)
		end)

		it("transfers to the correct newTeam", function()
			seedUnits("unit", 7)
			action.actionFunction("unit", 5)
			assert.are.equal(5, env.Spring.calls.transferUnit[1].newTeam)
		end)

		it("raises the transferringUnits fence only while transferring", function()
			seedUnits("unit", 8)
			local fenceDuringTransfer
			local transferUnit = env.Spring.TransferUnit
			env.Spring.TransferUnit = function(...)
				fenceDuringTransfer = GG["MissionAPI"].transferringUnits
				return transferUnit(...)
			end
			action.actionFunction("unit", 5)
			assert.is_true(fenceDuringTransfer)
			assert.is_nil(GG["MissionAPI"].transferringUnits)
		end)

		it("raises the capturingUnits fence only for a captured transfer", function()
			seedUnits("unit", 9)
			local fenceDuringTransfer
			local transferUnit = env.Spring.TransferUnit
			env.Spring.TransferUnit = function(...)
				fenceDuringTransfer = GG["MissionAPI"].capturingUnits
				return transferUnit(...)
			end
			action.actionFunction("unit", 5)
			assert.is_nil(fenceDuringTransfer)
			action.actionFunction("unit", 5, true)
			assert.is_true(fenceDuringTransfer)
			assert.is_nil(GG["MissionAPI"].capturingUnits)
		end)
	end)

end)
