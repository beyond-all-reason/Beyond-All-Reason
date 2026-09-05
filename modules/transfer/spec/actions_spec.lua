
---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local UnitShared = VFS.Include("modules/transfer/unit/shared.lua")
local ResourceShared = VFS.Include("modules/transfer/resource/shared.lua")

--- Runs fn with the global Spring swapped for a builder mock. The action files resolve
--- Spring at call time, so this is the seam; the mock gains what the actions send through.
---@param mock table
---@param fn fun(sent: string[])
local function withSpring(mock, fn)
	local sent = {}
	mock.Log = mock.Log or Spring.Log
	mock.SendLuaUIMsg = function(msg)
		sent[#sent + 1] = msg
	end
	mock.SendMessageToTeam = mock.SendMessageToTeam or function() end
	mock.SendMessageToPlayer = mock.SendMessageToPlayer or function() end
	mock.GetUnitHealth = mock.GetUnitHealth or function()
		return 100, 100
	end
	mock.AddUnitDamage = mock.AddUnitDamage or function() end
	local savedSpring, savedSendToUnsynced = Spring, _G.SendToUnsynced
	---@diagnostic disable-next-line: global-in-non-module
	_G.Spring = mock
	---@diagnostic disable-next-line: global-in-non-module
	_G.SendToUnsynced = _G.SendToUnsynced or function() end
	local ok, err = pcall(fn, sent)
	---@diagnostic disable-next-line: global-in-non-module
	_G.Spring, _G.SendToUnsynced = savedSpring, savedSendToUnsynced
	if not ok then
		error(err, 0)
	end
end

--- ValidateUnits reads UnitDefs by id; the mock builder keys its defs by name.
---@param mock table
---@return table byId
local function unitDefsById(mock)
	local byKey = {}
	for key, def in pairs(mock.GetUnitDefs() or {}) do
		byKey[key] = def
		if def.id then
			byKey[def.id] = def
		end
		if def.name then
			byKey[def.name] = def
		end
	end
	return byKey
end

describe("transfer actions", function()
	local registry ---@type { byName: table<string, ActionDescriptor>, list: ActionDescriptor[] }

	setup(function()
		ModuleHandler.ResetCaches()
		registry = ModuleHandler.LoadActions("transfer")
	end)

	--- validate is optional on a descriptor; every transfer action registers one.
	---@param name string
	---@param request table
	---@return boolean allowed, string? reason
	local function validate(name, request)
		local fn = assert(registry.byName[name].validate, name .. " registers validate")
		return fn(request)
	end

	it("declares units and resources", function()
		assert.is_table(registry.byName.units)
		assert.is_table(registry.byName.resources)
	end)

	it("declares give and give_resources, the two that skip policy", function()
		assert.is_table(registry.byName.give)
		assert.is_table(registry.byName.give_resources)
	end)

	it("every action registers an execute", function()
		for _, action in ipairs(registry.list) do
			assert.is_function(action.execute, action.name .. " must register execute")
		end
	end)

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
		assert.is_false(validate("resources", { from = 0, to = 1, resource = "metal", amount = 5 }))
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

	describe("resources", function()
		it("validate refuses a resource that is not metal or energy", function()
			local allowed = validate("resources", { from = 0, to = 1, resource = "ore", amount = 5 })
			assert.is_false(allowed)
		end)

		it("validate refuses a non-positive amount", function()
			assert.is_false(validate("resources", { from = 0, to = 1, resource = "metal", amount = 0 }))
		end)

		it("execute deducts the taxed amount from the sender and credits the receiver", function()
			local sender = Builders.Team:new():Human():WithMetal(500):WithMetalStorage(1000)
			local receiver = Builders.Team:new():Human():WithMetal(0):WithMetalStorage(1000)
			local mock = Builders.Spring
				.new()
				:WithTeam(sender)
				:WithTeam(receiver)
				:WithAlliance(sender.id, receiver.id, true)
				:WithTeamRulesParam(sender.id, "numActivePlayers", 1)
				:WithTeamRulesParam(receiver.id, "numActivePlayers", 1)
				:WithModOption(TransferEnums.ModOptions.TaxResourceSharingAmount, 0.5)
				:Build()
			withSpring(mock, function()
				-- the factors the controller caches at start-up
				local ResourceTransfer = VFS.Include("modules/transfer/resource/synced.lua")
				local ContextFactoryModule = VFS.Include("modules/transfer/context_factory.lua")
				local factory = ContextFactoryModule.create(mock)
				for _, id in ipairs({ sender.id, receiver.id }) do
					ResourceTransfer.CacheTeamFactor(mock, id, "metal", factory.policy(id, id))
				end

				local request = {
					from = sender.id,
					to = receiver.id,
					resource = "metal",
					amount = 100,
					grant = ResourceShared.GetCachedPolicyResult(sender.id, receiver.id, "metal", mock),
				}
				assert.is_true(validate("resources", request))
				local result = registry.byName.resources.execute(request)
				assert.is_true(result.success)
				assert.are.equal(100, result.received)
				assert.are.equal(200, result.sent)
				assert.are.equal(300, mock.GetTeamResources(sender.id, "metal"))
				assert.are.equal(100, mock.GetTeamResources(receiver.id, "metal"))
			end)
		end)
	end)

	describe("give_resources", function()
		it("refuses a team handing to itself", function()
			local allowed, reason = validate("give_resources", {
				from = 2,
				to = 2,
				resource = "metal",
				amount = 5,
			})
			assert.is_false(allowed)
			assert.is_truthy(tostring(reason):find("itself", 1, true))
		end)

		it("moves the whole amount, both sides, untaxed", function()
			local sender = Builders.Team:new():Human():WithMetal(50):WithMetalStorage(1000)
			local receiver = Builders.Team:new():Human():WithMetal(10):WithMetalStorage(1000)
			local mock = Builders.Spring.new():WithTeam(sender):WithTeam(receiver):Build()
			withSpring(mock, function()
				local moved = registry.byName.give_resources.execute({
					from = sender.id,
					to = receiver.id,
					resource = "metal",
					amount = 40,
				})
				assert.are.equal(40, moved)
				assert.are.equal(10, mock.GetTeamResources(sender.id, "metal"))
				assert.are.equal(50, mock.GetTeamResources(receiver.id, "metal"))
			end)
		end)
	end)
end)
