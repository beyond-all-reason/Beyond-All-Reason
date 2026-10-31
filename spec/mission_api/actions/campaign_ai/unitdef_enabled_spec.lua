local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/campaign_ai/unitdef_enabled.lua")
local summarizeSchema = require("mission_api.schema_spec_helper")

local calls

local function actionOfType(actionType)
	for _, action in ipairs(actions) do
		if action.type == actionType then
			return action
		end
	end
end

local function dispatch(action, parameters)
	MissionApiBuilder.new()
		:WithActionDefinitions({ Functions = { action.actionFunction }, Parameters = { action.parameters } })
		:WithAction("action", { type = 1, parameters = parameters })
		:Install()
	VFS.Include("luarules/mission_api/actions_dispatcher.lua").Invoke("action")
end

describe("mission_api.actions.unitdef_enabled", function()
	before_each(function()
		calls = {}
		GG.CampaignAI = {
			SetUnitDefsEnabled = function(unitDefIDs, isEnabled, teamID)
				calls[#calls + 1] = { unitDefIDs = unitDefIDs, isEnabled = isEnabled, teamID = teamID }
			end,
		}
		_G.UnitDefNames = { armwar = { id = 7 } } ---@diagnostic disable-line: global-in-non-module
	end)

	after_each(function()
		GG.CampaignAI = nil
	end)

	it("declares the parameters of both types", function()
		assert.are.same({
			type = "EnableUnitDef",
			unitDefName = "UnitDefName!",
			teamID = "TeamID!",
		}, summarizeSchema(actionOfType("EnableUnitDef")))
		assert.are.same({
			type = "DisableUnitDef",
			unitDefName = "UnitDefName!",
			teamID = "TeamID!",
		}, summarizeSchema(actionOfType("DisableUnitDef")))
	end)

	it("EnableUnitDef enables the unit def for the given team", function()
		dispatch(actionOfType("EnableUnitDef"), { unitDefName = "armwar", teamID = 3 })

		assert.are.same({ { unitDefIDs = { 7 }, isEnabled = true, teamID = 3 } }, calls)
	end)

	it("DisableUnitDef disables the unit def for the given team", function()
		dispatch(actionOfType("DisableUnitDef"), { unitDefName = "armwar", teamID = 3 })

		assert.are.same({ { unitDefIDs = { 7 }, isEnabled = false, teamID = 3 } }, calls)
	end)
end)
