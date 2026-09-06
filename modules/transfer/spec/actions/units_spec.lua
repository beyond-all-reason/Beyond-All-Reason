---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local UnitShared = VFS.Include("modules/transfer/unit/shared.lua")
local ResourceShared = VFS.Include("modules/transfer/resource/shared.lua")
local Helpers = VFS.Include("modules/transfer/spec/support/action_helpers.lua")
local withSpring, unitDefsById = Helpers.withSpring, Helpers.unitDefsById

describe("transfer.units", function()
	local registry ---@type { byName: table<string, ActionDescriptor>, list: ActionDescriptor[] }

	setup(function()
		ModuleHandler.ResetCaches()
		registry = ModuleHandler.LoadActions(Modules.Transfer)
	end)

	--- validate is optional on a descriptor; every transfer action registers one.
	---@param name string
	---@param request table
	---@return boolean allowed, string? reason
	local function validate(name, request)
		local fn = assert(registry.byName[name].validate, name .. " registers validate")
		return fn(request)
	end

	it("validate refuses a team sharing with itself", function()
		local allowed, reason = validate("units", { from = 1, to = 1, unitIDs = { 7 } })
		assert.is_false(allowed)
		assert.is_truthy(tostring(reason):find("itself", 1, true))
	end)

	it("validate refuses an empty unit list", function()
		assert.is_false(validate("units", { from = 0, to = 1, unitIDs = {} }))
	end)

	it("validate refuses a request the api did not resolve a grant for", function()
		local allowed, reason = validate("units", { from = 0, to = 1, unitIDs = { 7 } })
		assert.is_false(allowed)
		assert.is_truthy(tostring(reason):find("grant", 1, true))
	end)

	describe("units", function()
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

		--- What api.lua builds: the parameters plus the grant and validation it resolved.
		---@param mock table
		---@return table request
		local function requestOn(mock)
			local grant = UnitShared.GetCachedPolicyResult(sender.id, receiver.id, mock)
			return {
				from = sender.id,
				to = receiver.id,
				unitIDs = { unitID },
				grant = grant,
				validation = UnitShared.ValidateUnits(grant, { unitID }, mock),
			}
		end

		it("validate refuses when the mode forbids sharing", function()
			local mock = springWithMode(ConstructionEnums.UnitFilterCategory.None)
			withSpring(mock, function()
				local allowed, reason = validate("units", requestOn(mock))
				assert.is_false(allowed)
				assert.is_truthy(tostring(reason):find("mode", 1, true))
			end)
		end)

		it("validate refuses a unit the mode does not cover, so execute is never reached", function()
			local mock = springWithMode(ConstructionEnums.UnitFilterCategory.Buildings)
			withSpring(mock, function()
				local allowed, reason = validate("units", requestOn(mock))
				assert.is_false(allowed)
				assert.is_truthy(tostring(reason):find("none of the units", 1, true))
				assert.are.equal(sender.id, mock.GetUnitTeam(unitID))
			end)
		end)

		it("execute moves the units and announces the outcome", function()
			local mock = springWithMode(ConstructionEnums.UnitFilterCategory.All)
			withSpring(mock, function(sent)
				local request = requestOn(mock)
				assert.is_true(validate("units", request))
				local result = registry.byName.units.execute(request)
				assert.is_true(result.success)
				assert.are.equal(TransferEnums.UnitValidationOutcome.Success, result.outcome)
				assert.are.equal(receiver.id, mock.GetUnitTeam(unitID))
				assert.are.same({ "unit_transfer:success:" .. sender.id }, sent)
			end)
		end)

		it("execute transfers every unit the validation passed, as a gift, and reports the partial", function()
			local mock = springWithMode(ConstructionEnums.UnitFilterCategory.All)
			withSpring(mock, function()
				local request = requestOn(mock)
				request.unitIDs = { unitID, 9999 }
				request.validation = UnitShared.ValidateUnits(request.grant, request.unitIDs, mock)
				local transfer = spy.on(mock, "TransferUnit")
				local result = registry.byName.units.execute(request)
				assert.spy(transfer).was.called(1)
				assert.spy(transfer).was.called_with(unitID, receiver.id, true)
				assert.are.equal(TransferEnums.UnitValidationOutcome.PartialSuccess, result.outcome)
				assert.are.same({ 9999 }, result.validationResult.invalidUnitIds)
				assert.are.equal(request.grant, result.policyResult, "the result carries the grant it acted on")
			end)
		end)

		it("execute acts on the grant it was handed, never on what the game would resolve", function()
			local allowing = springWithMode(ConstructionEnums.UnitFilterCategory.All)
			local request = requestOn(allowing)
			local forbidding = springWithMode(ConstructionEnums.UnitFilterCategory.None)
			withSpring(forbidding, function()
				assert.is_true(validate("units", request))
				local result = registry.byName.units.execute(request)
				assert.is_true(result.success)
				assert.are.equal(receiver.id, forbidding.GetUnitTeam(unitID))
			end)
		end)
	end)
end)
