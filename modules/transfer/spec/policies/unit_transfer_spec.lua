---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local UnitTransfer = VFS.Include("modules/transfer/unit/synced.lua")
local ContextFactoryModule = VFS.Include("modules/transfer/context_factory.lua")

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

describe(TransferEnums.ModOptions.UnitSharingMode .. " #policy", function()
	local sender = Builders.Team:new():Human()
	local receiver = Builders.Team:new():Human()

	local spring = Builders.Spring.new():WithTeam(sender):WithTeam(receiver):WithAlliance(sender.id, receiver.id, true)

	for modeKey, config in pairs(testConfigs) do
		describe("WHEN unit sharing mode is set to " .. config.mode, function()
			spring:WithModOption(TransferEnums.ModOptions.UnitSharingMode, config.mode)
			local result ---@type UnitPolicyResult
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
