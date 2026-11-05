local UnitDefsBuilder = VFS.Include("spec/builders/unit_defs_builder.lua")
local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/build_options/dynamic_build_options.lua")
local summarizeSchema = require("mission_api.schema_spec_helper")

local unitDefs = UnitDefsBuilder.new():WithUnitDefs({
	[42] = { name = "armsolar" },
	[7] = { name = "armck", isBuilder = true },
	[9] = { name = "armlab", isBuilder = true, isFactory = true },
})
local unitDefNames = unitDefs:GetUnitDefNames()

-- team 1: a construction bot, a bot lab and a solar collector
local teamUnitDefIDs = { [1] = { [100] = 7, [101] = 9, [102] = 42 } }

env.CMD.REMOVE = 2

local function findAction(actionType)
	for _, action in ipairs(actions) do
		if action.type == actionType then
			return action
		end
	end
	error("no action of type " .. actionType)
end

local addAction = findAction("AddBuildOption")
local removeAction = findAction("RemoveBuildOption")

describe("mission_api.actions.dynamic_build_options", function()

	---@type { add: table[], remove: table[], block: table[], unblock: table[], orders: table[] }
	local calls

	before_each(function()
		calls = { add = {}, remove = {}, block = {}, unblock = {}, orders = {} }
		env.UnitDefNames = unitDefNames
		env.UnitDefs = unitDefs:GetUnitDefsByID()
		env.Spring.GetTeamUnits = function(teamID)
			local unitIDs = {}
			for unitID in pairs(teamUnitDefIDs[teamID] or {}) do
				unitIDs[#unitIDs + 1] = unitID
			end
			table.sort(unitIDs)
			return unitIDs
		end
		env.Spring.GetUnitDefID = function(unitID)
			return teamUnitDefIDs[1][unitID]
		end
		env.Spring.GiveOrderToUnit = function(unitID, cmdID, params, options)
			calls.orders[#calls.orders + 1] = { unitID = unitID, cmdID = cmdID, params = params, options = options }
		end
		GG["BuildBlocking"] = {
			AddBlockedUnit = function(unitDefID, teamID, reasonKey, builderUnitDefID)
				calls.block[#calls.block + 1] = {
					unitDefID = unitDefID,
					teamID = teamID,
					reasonKey = reasonKey,
					builderUnitDefID = builderUnitDefID,
				}
			end,
			RemoveBlockedUnit = function(unitDefID, teamID, reasonKey, builderUnitDefID)
				calls.unblock[#calls.unblock + 1] = {
					unitDefID = unitDefID,
					teamID = teamID,
					reasonKey = reasonKey,
					builderUnitDefID = builderUnitDefID,
				}
				return true
			end,
		}
		GG["DynamicBuildOptions"] = {
			Add = function(builtUnitDefID, builderUnitDefID, position)
				calls.add[#calls.add + 1] = {
					builtUnitDefID = builtUnitDefID,
					builderUnitDefID = builderUnitDefID,
					position = position,
				}
				return true
			end,
			Remove = function(builtUnitDefID, builderUnitDefID)
				calls.remove[#calls.remove + 1] = {
					builtUnitDefID = builtUnitDefID,
					builderUnitDefID = builderUnitDefID,
				}
				return true
			end,
		}
	end)

	after_each(function()
		GG["DynamicBuildOptions"] = nil
		GG["BuildBlocking"] = nil
	end)

	it("declares AddBuildOption and its parameters", function()
		assert.are.same({
			type = "AddBuildOption",
			builtDefName = "UnitDefName!",
			builderDefName = "UnitDefName",
			buildMenuPosition = "PositiveInteger",
			teamName = "TeamName",
			requiresOneOf = { "builderDefName", "teamName" },
		}, summarizeSchema(addAction))
	end)

	it("declares RemoveBuildOption and its parameters", function()
		assert.are.same({
			type = "RemoveBuildOption",
			builtDefName = "UnitDefName!",
			builderDefName = "UnitDefName",
			teamName = "TeamName",
			requiresOneOf = { "builderDefName", "teamName" },
		}, summarizeSchema(removeAction))
	end)

	describe("AddBuildOption", function()
		it("adds the option to the builder type at the end of its build options", function()
			addAction.actionFunction("armsolar", "armck", nil)

			assert.are.equal(1, #calls.add)
			assert.are.same({ builtUnitDefID = 42, builderUnitDefID = 7 }, calls.add[1])
			assert.are.equal(0, #calls.remove)
		end)

		it("passes the build menu position through", function()
			addAction.actionFunction("armsolar", "armck", 3)

			assert.are.equal(1, #calls.add)
			assert.are.same({ builtUnitDefID = 42, builderUnitDefID = 7, position = 3 }, calls.add[1])
		end)

		it("shows the option to a team again by lifting its hidden block, leaving the unit defs alone", function()
			addAction.actionFunction("armsolar", nil, nil, 1)

			assert.are.same({ { unitDefID = 42, teamID = 1, reasonKey = "hidden" } }, calls.unblock)
			assert.are.equal(0, #calls.add)
		end)
	end)

	describe("RemoveBuildOption", function()
		it("removes the option from the builder type", function()
			removeAction.actionFunction("armsolar", "armck")

			assert.are.equal(1, #calls.remove)
			assert.are.same({ builtUnitDefID = 42, builderUnitDefID = 7 }, calls.remove[1])
			assert.are.equal(0, #calls.add)
			assert.are.equal(0, #calls.orders)
		end)

		it("hides the option from one team with a hidden block, leaving the builder types alone", function()
			removeAction.actionFunction("armsolar", nil, 1)

			assert.are.same({ { unitDefID = 42, teamID = 1, reasonKey = "hidden" } }, calls.block)
			assert.are.equal(0, #calls.remove)
		end)

		it("drops the type's queued orders from the team's builders and factories", function()
			removeAction.actionFunction("armsolar", nil, 1)

			assert.are.same({
				{ unitID = 100, cmdID = 2, params = { -42 }, options = { "alt" } },
				{ unitID = 101, cmdID = 2, params = { -42 }, options = { "alt", "ctrl" } },
			}, calls.orders)
		end)

		it("leaves the queues of other teams alone", function()
			removeAction.actionFunction("armsolar", nil, 0)

			assert.are.equal(0, #calls.orders)
		end)

		it("is undone for the team by AddBuildOption with the team", function()
			removeAction.actionFunction("armsolar", nil, 0)
			addAction.actionFunction("armsolar", nil, nil, 0)

			assert.are.same(calls.block[1], calls.unblock[1])
		end)
	end)

end)
