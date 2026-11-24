local UnitDefsBuilder = VFS.Include("spec/builders/unit_defs_builder.lua")
local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/build_options/unit_type_limit.lua")
local summarizeSchema = require("mission_api.schema_spec_helper")

local unitDefNames = UnitDefsBuilder.new():WithUnitDefs({ [50] = { name = "armsilo" } }):GetUnitDefNames()

local function findAction(actionType)
	for _, action in ipairs(actions) do
		if action.type == actionType then
			return action
		end
	end
	error("no action of type " .. actionType)
end

local setAction = findAction("SetUnitTypeLimit")
local removeAction = findAction("RemoveUnitTypeLimit")

describe("mission_api.actions.unit_type_limit", function()
	---@type table[]
	local calls

	before_each(function()
		calls = {}
		env.UnitDefNames = unitDefNames
		GG["UnitTypeLimits"] = {
			Set = function(teamID, unitDefID, limit)
				calls[#calls + 1] = { teamID = teamID, unitDefID = unitDefID, limit = limit }
			end,
		}
	end)

	after_each(function()
		GG["UnitTypeLimits"] = nil
	end)

	it("declares SetUnitTypeLimit and its parameters", function()
		assert.are.same({
			type = "SetUnitTypeLimit",
			unitDefName = "UnitDefName!",
			teamName = "TeamName!",
			limit = "PositiveInteger!",
		}, summarizeSchema(setAction))
	end)

	it("declares RemoveUnitTypeLimit and its parameters", function()
		assert.are.same({
			type = "RemoveUnitTypeLimit",
			unitDefName = "UnitDefName!",
			teamName = "TeamName!",
		}, summarizeSchema(removeAction))
	end)

	it("caps the unit type for the team", function()
		setAction.actionFunction("armsilo", 1, 2)

		assert.are.same({ { teamID = 1, unitDefID = 50, limit = 2 } }, calls)
	end)

	it("takes the cap away", function()
		removeAction.actionFunction("armsilo", 1)

		assert.are.same({ { teamID = 1, unitDefID = 50 } }, calls)
	end)
end)
