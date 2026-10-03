---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local ConstructionEnums = require("modules/construction/enums")
local Helpers = require("modules/transfer/spec/support/synced_helpers")
local TransferEnums = require("modules/transfer/enums")
local withSpring, unitDefsById = Helpers.withSpring, Helpers.unitDefsById

-- Units shared under the policy: the terms decide, each unit is validated, what passes moves as a gift.
describe("sharing units", function()
	local Synced = require("modules/transfer/api_synced").Units
	local sender ---@type TeamBuilder
	local receiver ---@type TeamBuilder
	local unitID ---@type integer

	before_each(function()
		sender = Builders.Team:new():Human()
		receiver = Builders.Team:new():Human()
		sender:WithUnit("armpw", function(id)
			unitID = id --[[@as integer]]
		end)
	end)

	after_each(function()
		---@diagnostic disable-next-line: global-in-non-module
		_G.UnitDefs = nil
	end)

	---@param mode string
	---@return table mock
	local function springWithMode(mode)
		local mock = Builders.Spring
			.new()
			:WithTeam(sender)
			:WithTeam(receiver)
			:WithAlliance(sender.id, receiver.id, true)
			:WithModOption(TransferEnums.ModOptions.UnitSharingMode, mode)
			:WithModOption(TransferEnums.ModOptions.UnitShareStunSeconds, 0)
			:WithModOption(ConstructionEnums.ModOptions.ConstructorBuildDelay, 0)
			:WithRealUnitDefs()
			:Build()
		---@diagnostic disable-next-line: global-in-non-module
		_G.UnitDefs = unitDefsById(mock)
		return mock
	end

	it("shares nothing from an empty list, and says so", function()
		local mock = springWithMode(ConstructionEnums.UnitFilterCategory.All)
		withSpring(mock, function(sent)
			assert.is_false(Synced.Share({}, receiver.id, sender.id).success)
			assert.are.same({}, sent)
		end)
	end)

	it("refuses when the mode forbids sharing", function()
		local mock = springWithMode(ConstructionEnums.UnitFilterCategory.None)
		withSpring(mock, function(sent)
			local result = Synced.Share({ unitID }, receiver.id, sender.id)
			assert.is_false(result.success)
			assert.are.equal(TransferEnums.UnitValidationOutcome.Failure, result.outcome)
			assert.are.equal(sender.id, mock.GetUnitTeam(unitID))
			assert.are.same({}, sent)
		end)
	end)

	it("refuses a unit the mode does not cover, and names it", function()
		local mock = springWithMode(ConstructionEnums.UnitFilterCategory.Buildings)
		withSpring(mock, function()
			local result = Synced.Share({ unitID }, receiver.id, sender.id)
			assert.is_false(result.success)
			assert.are.same({ unitID }, result.validationResult.invalidUnitIds)
			assert.are.equal(sender.id, mock.GetUnitTeam(unitID))
		end)
	end)

	it("moves the units and announces the outcome", function()
		local mock = springWithMode(ConstructionEnums.UnitFilterCategory.All)
		withSpring(mock, function(sent)
			local result = (Synced.Share({ unitID }, receiver.id, sender.id))
			assert.is_true(result.success)
			assert.are.equal(TransferEnums.UnitValidationOutcome.Success, result.outcome)
			assert.are.equal(receiver.id, mock.GetUnitTeam(unitID))
			assert.are.same({ "unit_transfer:success:" .. sender.id }, sent)
		end)
	end)

	it("transfers every unit the validation passed, as a gift, and reports the partial", function()
		local mock = springWithMode(ConstructionEnums.UnitFilterCategory.All)
		withSpring(mock, function()
			local transfer = spy.on(mock, "TransferUnit")
			local result = (Synced.Share({ unitID, 9999 }, receiver.id, sender.id))
			assert.spy(transfer).was.called(1)
			assert.spy(transfer).was.called_with(unitID, receiver.id, true)
			assert.are.equal(TransferEnums.UnitValidationOutcome.PartialSuccess, result.outcome)
			assert.are.same({ 9999 }, result.validationResult.invalidUnitIds)
			assert.is_true(result.policyResult.canShare, "the result carries the terms it acted on")
		end)
	end)
end)

-- Units given by fiat: no policy asked; the engine is told a give is in flight so the policy stands aside.
describe("giving units", function()
	local params = {} ---@type table<string, integer>
	local getParam, setParam

	before_each(function()
		params = {}
		getParam, setParam = Spring.GetGameRulesParam, Spring.SetGameRulesParam
		Spring.GetGameRulesParam = function(name)
			return params[name]
		end
		Spring.SetGameRulesParam = function(name, value)
			params[name] = value
		end
	end)

	after_each(function()
		Spring.GetGameRulesParam, Spring.SetGameRulesParam = getParam, setParam
	end)

	it("the policy stands aside while a give is in flight", function()
		local TransferApi = require("modules/transfer/api")
		params.isGiveInProgress = 1
		assert.is_true(TransferApi.MayTransfer(7, Spring.GetGaiaTeamID and Spring.GetGaiaTeamID() or 2, 0, false))
	end)

	it("and only while it is in flight", function()
		local TransferApi = require("modules/transfer/api")
		params.isGiveInProgress = 0
		local saved = { Spring.GetModOptions, Spring.AreTeamsAllied, Spring.GetTeamRulesParam }
		Spring.GetModOptions = function()
			return {}
		end
		Spring.AreTeamsAllied = function()
			return false
		end
		Spring.GetTeamRulesParam = function()
			return nil
		end
		local answer = TransferApi.MayTransfer(7, 2, 0, false)
		Spring.GetModOptions, Spring.AreTeamsAllied, Spring.GetTeamRulesParam = saved[1], saved[2], saved[3]
		assert.is_false(
			answer,
			"an ordinary unallied share is refused, which is exactly why a give has to announce itself"
		)
	end)

	it("raises the announcement for the move and lowers it after", function()
		local Synced = require("modules/transfer/api_synced").Units
		local duringMove = {}
		local savedTransfer = Spring.TransferUnit
		Spring.TransferUnit = function(unitID, toTeamID, given)
			duringMove[#duringMove + 1] =
				{ unitID = unitID, to = toTeamID, given = given, flag = params.isGiveInProgress }
			return true
		end
		local moved = Synced.Give({ 11, 12 }, 0)
		Spring.TransferUnit = savedTransfer
		assert.are.equal(2, moved)
		assert.are.same({
			{ unitID = 11, to = 0, given = true, flag = 1 },
			{ unitID = 12, to = 0, given = true, flag = 1 },
		}, duringMove, "the flag must be up while the engine is asking")
		assert.are.equal(0, params.isGiveInProgress, "and down again once the move is done")
	end)
end)
