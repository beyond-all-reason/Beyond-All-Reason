---
--- Shared setup for the validation specs: definitions, engine mocks, and helpers
--- for validating a mission and asserting on the messages it produced.
---

require("spec_helper")

-- busted only exposes luassert as a global inside spec files, not in required modules.
local assert = require('luassert')

local Builders = VFS.Include("spec/builders/index.lua")

-- The definition files read ParameterTypes from GG when they are included, mirroring
-- the eager module loading in api_missions.lua. The mock is built rather than installed,
-- and GG is put back afterwards, so no other spec's mock is disturbed.
local previousMissionAPI = GG['MissionAPI']
GG['MissionAPI'] = Builders.MissionApi.new():Build()
local definitions = {
	ParameterTypes     = GG['MissionAPI'].Modules.ParameterTypes,
	ActionDefinitions  = VFS.Include('luarules/mission_api/actions_loader.lua').LoadActionDefinitions(),
	TriggerDefinitions = VFS.Include('luarules/mission_api/triggers_loader.lua').LoadTriggerDefinitions(),
}
GG['MissionAPI'] = previousMissionAPI

local validation = VFS.Include('luarules/mission_api/validation/mission_validation.lua')

local helper = {
	definitions  = definitions,
	triggerTypes = definitions.TriggerDefinitions.Types,
	actionTypes  = definitions.ActionDefinitions.Types,
}

--- Engine globals the validators read. Set per test, since other specs reset them.
function helper.mockEngineGlobals()
	Spring.GetTeamAllyTeamID = function() return true end
	Spring.GetAllyTeamList   = function() return { 0 } end
	_G.UnitDefNames          = { armwar = { id = 1 } }
	_G.FeatureDefNames       = { rockdef = { id = 1 } }
	_G.WeaponDefNames        = {}
end

--- @return MissionBuilder
function helper.mission()
	return Builders.Mission.new()
end

--- Validates a mission, given as a builder or a raw table. The returned result has
--- its errors and warnings flattened into `messages`, since both are asserted on.
--- @return table result { ok, errors, warnings, messages }
function helper.validate(mission)
	local raw = type(mission) == 'table' and mission.Build and mission:Build() or mission

	-- Validation must not read GG, so it is unset for the duration of the call.
	local installedMissionAPI = GG['MissionAPI']
	GG['MissionAPI'] = nil
	local succeeded, result = pcall(validation.ValidateMission, raw, definitions)
	GG['MissionAPI'] = installedMissionAPI

	assert(succeeded, result)

	local messages = {}
	for _, message in ipairs(result.errors) do
		messages[#messages + 1] = message
	end
	for _, message in ipairs(result.warnings) do
		messages[#messages + 1] = message
	end
	result.messages = messages

	return result
end

local function describeMessages(result)
	if #result.messages == 0 then
		return "no messages were reported"
	end
	return "reported messages:\n  " .. table.concat(result.messages, "\n  ")
end

--- @param result table as returned by helper.validate
function helper.assertMessage(result, message)
	assert.is_true(table.contains(result.messages, message),
		"expected message:\n  " .. message .. "\nbut " .. describeMessages(result))
end

--- @param result table as returned by helper.validate
function helper.assertNoMessage(result, message)
	assert.is_false(table.contains(result.messages, message),
		"expected no message:\n  " .. message .. "\nbut it was reported")
end

--- @param result table as returned by helper.validate
function helper.assertNoMessageContaining(result, text)
	assert.is_false(table.any(result.messages, function(message)
		return message:find(text, 1, true) ~= nil
	end), "expected no message containing:\n  " .. text .. "\nbut " .. describeMessages(result))
end

--- @param result table as returned by helper.validate
function helper.assertValid(result)
	assert.are.same({}, result.messages)
	assert.is_true(result.ok)
end

--- Validates a mission whose action 'a' is the one under test, referenced by a trigger.
function helper.validateAction(action)
	return helper.validate(helper.mission()
		:WithTrigger('t', {
			type       = helper.triggerTypes.TimeElapsed,
			parameters = { seconds = 1 },
			actions    = { 'a' },
		})
		:WithAction('a', action))
end

--- Validates a mission whose trigger 't' is the one under test, with a valid action.
function helper.validateTrigger(trigger)
	return helper.validate(helper.mission()
		:WithTrigger('t', trigger)
		:WithAction('ok', { type = helper.actionTypes.SendMessage, parameters = { message = 'ok' } }))
end

--- A valid trigger of the given type, referencing the 'ok' action from validateTrigger.
function helper.trigger(triggerType, parameters)
	return { type = triggerType, parameters = parameters, actions = { 'ok' } }
end

return helper
