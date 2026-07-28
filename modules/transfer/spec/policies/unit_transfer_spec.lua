---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local ConstructionEnums = require("modules/construction/enums")
local ContextFactoryModule = require("modules/transfer/context_factory")
local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")
local TransferEnums = require("modules/transfer/enums")
local UnitTransfer = require("modules/transfer/unit/synced")

describe("giving an ally a unit", function()
	local Contract = ModuleHandler.Contract(Modules.Transfer)

	---@param opts table
	---@param activePlayers integer|nil
	local function repo(opts, activePlayers)
		return {
			GetModOptions = function()
				return opts
			end,
			GetTeamRulesParam = function(_, key)
				return key == "numActivePlayers" and activePlayers or nil
			end,
		}
	end

	local lobby = {
		[TransferEnums.ModOptions.UnitSharingMode] = ConstructionEnums.UnitFilterCategory.All,
		[TransferEnums.ModOptions.UnitShareStunSeconds] = "5",
	}

	---@param fields table
	---@return UnitTransferTerms
	local function terms(fields)
		local ctx = { senderTeamId = 1, receiverTeamId = 2, areAlliedTeams = true, isCheatingEnabled = false }
		ctx.springRepo = repo(lobby, 1)
		ctx.modOptions = lobby
		for k, v in pairs(fields) do
			ctx[k] = v
		end
		return ModuleHandler.Evaluate(Contract.UnitTransfer, ctx)
	end

	it("goes through on the lobby's sharing mode, with the stun a gifted unit takes written on the terms", function()
		local granted = terms({})
		assert.is_true(granted.canShare)
		assert.are.same({ ConstructionEnums.UnitFilterCategory.All }, granted.sharingModes)
		assert.are.equal(5, granted.stunSeconds)
	end)

	it(
		"is refused, on the same terms to read, when sharing is off, the teams are enemies, or nobody is home",
		function()
			local off = { [TransferEnums.ModOptions.UnitSharingMode] = ConstructionEnums.UnitFilterCategory.None }
			assert.is_false(terms({ modOptions = off }).canShare)
			assert.is_false(terms({ areAlliedTeams = false }).canShare)
			local refused = terms({ springRepo = repo(lobby, 0) })
			assert.is_false(refused.canShare)
			assert.are.equal(5, refused.stunSeconds)
			assert.is_true(terms({ springRepo = repo(lobby, 0), isCheatingEnabled = true }).canShare)
		end
	)
end)

local Units = {
	AdvancedConstructor = "coracv",
	Pawn = "armpw",
	Fusion = "armfus",
	Constructor = "corcv",
}

---@class UnitTransferTestConfig
---@field mode string The sharing mode to test
---@field canShareUnits boolean Expected canShareUnits result
---@field testUnits table<string, boolean> Map of unit names to expected outcomes

---@type table<string, UnitTransferTestConfig>
local testConfigs = {
	[ConstructionEnums.UnitFilterCategory.None] = {
		mode = ConstructionEnums.UnitFilterCategory.None,
		canShareUnits = false,
		testUnits = {
			[Units.AdvancedConstructor] = false,
			[Units.Fusion] = false,
		},
	},
	[ConstructionEnums.UnitFilterCategory.All] = {
		mode = ConstructionEnums.UnitFilterCategory.All,
		canShareUnits = true,
		testUnits = {
			[Units.AdvancedConstructor] = true,
			[Units.Fusion] = true,
		},
	},
	[ConstructionEnums.UnitFilterCategory.Combat] = {
		mode = ConstructionEnums.UnitFilterCategory.Combat,
		canShareUnits = true,
		testUnits = {
			[Units.Pawn] = true,
			[Units.Constructor] = false,
			[Units.AdvancedConstructor] = false,
			[Units.Fusion] = false,
		},
	},
	[ConstructionEnums.UnitFilterCategory.Constructors] = {
		mode = ConstructionEnums.UnitFilterCategory.Constructors,
		canShareUnits = true,
		testUnits = {
			[Units.Constructor] = true,
			[Units.AdvancedConstructor] = true,
			[Units.Fusion] = false,
			[Units.Pawn] = false,
		},
	},
	[ConstructionEnums.UnitFilterCategory.Buildings] = {
		mode = ConstructionEnums.UnitFilterCategory.Buildings,
		canShareUnits = true,
		testUnits = {
			[Units.Fusion] = true,
			[Units.Constructor] = false,
			[Units.AdvancedConstructor] = false,
			[Units.Pawn] = false,
		},
	},
	[ConstructionEnums.UnitFilterCategory.Resource] = {
		mode = ConstructionEnums.UnitFilterCategory.Resource,
		canShareUnits = true,
		testUnits = {
			[Units.Fusion] = true,
			[Units.Constructor] = false,
			[Units.Pawn] = false,
		},
	},
	[ConstructionEnums.UnitFilterCategory.NonCombat] = {
		mode = ConstructionEnums.UnitFilterCategory.NonCombat,
		canShareUnits = true,
		testUnits = {
			[Units.Constructor] = true,
			[Units.AdvancedConstructor] = true,
			[Units.Fusion] = true,
			[Units.Pawn] = false,
		},
	},
}

describe("what each sharing mode lets through, unit by unit", function()
	local sender = Builders.Team:new():Human()
	local receiver = Builders.Team:new():Human()

	local spring = Builders.Spring.new():WithTeam(sender):WithTeam(receiver):WithAlliance(sender.id, receiver.id, true)

	for modeKey, config in pairs(testConfigs) do
		describe("WHEN unit sharing mode is set to " .. config.mode, function()
			spring:WithModOption(TransferEnums.ModOptions.UnitSharingMode, config.mode)
			local result ---@type UnitTransferTerms
			local unitIds = {} ---@type table<string, integer>
			local api ---@type SpringSyncedMock

			before_each(function()
				unitIds = {}
				sender.units = {}
				for unitDefName, _ in pairs(config.testUnits) do
					sender:WithUnit(unitDefName, function(id)
						unitIds[unitDefName] = id
					end)
				end
				spring:WithRealUnitDefs()
				api = spring:Build()
				local defsByKey = {}
				local defs = api.GetUnitDefs()
				for key, def in pairs(defs or {}) do
					defsByKey[key] = def
					if def.id then
						defsByKey[def.id] = def
					end
					if def.name then
						defsByKey[def.name] = def
					end
				end
				---@diagnostic disable-next-line: global-in-non-module
				_G.UnitDefs = defsByKey
				local ctx = ContextFactoryModule.create(api).policy(sender.id, receiver.id)
				result = UnitTransfer.GetPolicy(ctx)
			end)

			after_each(function()
				---@diagnostic disable-next-line: global-in-non-module
				_G.UnitDefs = nil
			end)

			it("should have correct sharing permissions", function()
				assert.equal(config.canShareUnits, result.canShare)
			end)

			for unitDefName, shouldAllow in pairs(config.testUnits) do
				it(
					"should " .. (shouldAllow and "allow" or "not allow") .. " validating transfer of " .. unitDefName,
					function()
						local unitId = unitIds[unitDefName]
						assert.is_not_nil(unitId)
						local validation = UnitTransfer.ValidateUnits(result, { unitId }, api, _G.UnitDefs)
						if not config.canShareUnits then
							assert.equal(0, validation.validUnitCount)
							assert.equal(0, validation.invalidUnitCount)
						else
							if shouldAllow then
								assert.equal(1, validation.validUnitCount)
								assert.equal(0, validation.invalidUnitCount)
							else
								assert.equal(0, validation.validUnitCount)
								assert.equal(1, validation.invalidUnitCount)
							end
						end
					end
				)
			end
		end)
	end
end)
