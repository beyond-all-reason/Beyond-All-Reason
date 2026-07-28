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

describe("Easy Tax stun mechanics #stun", function()
	local easyTaxMode = VFS.Include("modules/transfer/modes/easy_tax.lua")

	local function modeModOpts(modeConfig)
		local opts = {}
		for key, entry in pairs(modeConfig.modOptions) do
			local value = entry.value
			if type(value) == "boolean" then
				opts[key] = value and "1" or "0"
			else
				opts[key] = tostring(value)
			end
		end
		return opts
	end

	local sender = Builders.Team:new():Human()
	local receiver = Builders.Team:new():Human()
	local spring = Builders.Spring
		.new()
		:WithTeam(sender)
		:WithTeam(receiver)
		:WithAlliance(sender.id, receiver.id, true)
		:WithTeamRulesParam(receiver.id, "numActivePlayers", 1)
		:WithTeamRulesParam(sender.id, "numActivePlayers", 1)

	local mockDefs = {
		[1] = { id = 1, name = "mockfusion", customParams = { unitgroup = "energy" } },
		[2] = { id = 2, name = "mockcon", canAssist = true, buildOptions = {}, customParams = { techlevel = "1" } },
		[3] = { id = 3, name = "mockpawn", customParams = { unitgroup = "weapon" }, weapons = { "gun" } },
		[4] = { id = 4, name = "mockbuilder", isBuilder = true, customParams = { techlevel = "1" } },
	}

	describe("GetPolicy", function()
		it("should expose stunSeconds, stunCategory and buildDelaySeconds from Easy Tax config", function()
			local api = spring:Build()
			api.GetModOptions = function()
				return modeModOpts(easyTaxMode)
			end

			local ctx = ContextFactoryModule.create(api).policy(sender.id, receiver.id)
			local policy = UnitTransfer.GetPolicy(ctx)

			assert.equal(30, policy.stunSeconds)
			assert.equal(ConstructionEnums.UnitFilterCategory.Resource, policy.stunCategory)
			assert.equal(30, policy.buildDelaySeconds)
		end)

		it("should default stunSeconds and buildDelaySeconds to 0 when not configured", function()
			local api = spring:Build()
			api.GetModOptions = function()
				return { unit_sharing_mode = "all" }
			end

			local ctx = ContextFactoryModule.create(api).policy(sender.id, receiver.id)
			local policy = UnitTransfer.GetPolicy(ctx)

			assert.equal(0, policy.stunSeconds)
			assert.equal(0, policy.buildDelaySeconds)
		end)
	end)

	describe("ValidateUnits nanoframe blocking", function()
		it("should block nanoframes of stun-category units (resource building)", function()
			local nanoframeId = 901
			sender.units = {}
			sender.units[nanoframeId] = { unitDefId = 1, beingBuilt = true, buildProgress = 0.5 }
			local api = spring:Build()

			local policy = {
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 30,
				stunCategory = ConstructionEnums.UnitFilterCategory.Resource,
			}

			local result = UnitTransfer.ValidateUnits(policy, { nanoframeId }, api, mockDefs)
			assert.equal(0, result.validUnitCount)
			assert.equal(1, result.invalidUnitCount)
		end)

		it("should allow nanoframes of production units when stun category is resource", function()
			local nanoframeId = 902
			sender.units = {}
			sender.units[nanoframeId] = { unitDefId = 2, beingBuilt = true, buildProgress = 0.3 }
			local api = spring:Build()

			local policy = {
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 30,
				stunCategory = ConstructionEnums.UnitFilterCategory.Resource,
			}

			local result = UnitTransfer.ValidateUnits(policy, { nanoframeId }, api, mockDefs)
			assert.equal(1, result.validUnitCount)
			assert.equal(0, result.invalidUnitCount)
		end)

		it("should allow completed stun-category units", function()
			local completedId = 903
			sender.units = {}
			sender.units[completedId] = { unitDefId = 1, beingBuilt = false, buildProgress = 1.0 }
			local api = spring:Build()

			local policy = {
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 30,
				stunCategory = ConstructionEnums.UnitFilterCategory.Resource,
			}

			local result = UnitTransfer.ValidateUnits(policy, { completedId }, api, mockDefs)
			assert.equal(1, result.validUnitCount)
			assert.equal(0, result.invalidUnitCount)
		end)

		it("should allow combat nanoframes (not in EconomicPlusBuildings stun category)", function()
			local combatNanoId = 904
			sender.units = {}
			sender.units[combatNanoId] = { unitDefId = 3, beingBuilt = true, buildProgress = 0.3 }
			local api = spring:Build()

			local policy = {
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 30,
				stunCategory = ConstructionEnums.UnitFilterCategory.Resource,
			}

			local result = UnitTransfer.ValidateUnits(policy, { combatNanoId }, api, mockDefs)
			assert.equal(1, result.validUnitCount)
			assert.equal(0, result.invalidUnitCount)
		end)

		it("should allow all nanoframes when stunSeconds is 0", function()
			local nanoframeId = 905
			sender.units = {}
			sender.units[nanoframeId] = { unitDefId = 1, beingBuilt = true, buildProgress = 0.5 }
			local api = spring:Build()

			local policy = {
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 0,
				stunCategory = ConstructionEnums.UnitFilterCategory.Resource,
			}

			local result = UnitTransfer.ValidateUnits(policy, { nanoframeId }, api, mockDefs)
			assert.equal(1, result.validUnitCount)
			assert.equal(0, result.invalidUnitCount)
		end)

		it("should handle mixed nanoframes and completed units", function()
			local nanoId = 906
			local completedId = 907
			sender.units = {}
			sender.units[nanoId] = { unitDefId = 1, beingBuilt = true, buildProgress = 0.5 }
			sender.units[completedId] = { unitDefId = 1, beingBuilt = false, buildProgress = 1.0 }
			local api = spring:Build()

			local policy = {
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 30,
				stunCategory = ConstructionEnums.UnitFilterCategory.Resource,
			}

			local result = UnitTransfer.ValidateUnits(policy, { nanoId, completedId }, api, mockDefs)
			assert.equal(1, result.validUnitCount)
			assert.equal(1, result.invalidUnitCount)
			assert.equal(TransferEnums.UnitValidationOutcome.PartialSuccess, result.status)
		end)

		it("should block nanoframes with Combat stun category", function()
			local combatNanoId = 908
			sender.units = {}
			sender.units[combatNanoId] = { unitDefId = 3, beingBuilt = true, buildProgress = 0.4 }
			local api = spring:Build()

			local policy = {
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 15,
				stunCategory = ConstructionEnums.UnitFilterCategory.Combat,
			}

			local result = UnitTransfer.ValidateUnits(policy, { combatNanoId }, api, mockDefs)
			assert.equal(0, result.validUnitCount)
			assert.equal(1, result.invalidUnitCount)
		end)
	end)

	describe("ValidateUnits build-delay tally", function()
		it("counts mobile builders among the valid units", function()
			local builderId, fusionId = 910, 911
			sender.units = {}
			sender.units[builderId] = { unitDefId = 4, beingBuilt = false, buildProgress = 1.0 }
			sender.units[fusionId] = { unitDefId = 1, beingBuilt = false, buildProgress = 1.0 }
			local api = spring:Build()

			local policy = {
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 0,
			}

			local result = UnitTransfer.ValidateUnits(policy, { builderId, fusionId }, api, mockDefs)
			assert.equal(2, result.validUnitCount)
			assert.equal(1, result.buildDelayedUnitCount)
		end)

		it("counts zero when the selection has no mobile builders", function()
			local fusionId = 912
			sender.units = {}
			sender.units[fusionId] = { unitDefId = 1, beingBuilt = false, buildProgress = 1.0 }
			local api = spring:Build()

			local policy = {
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 0,
			}

			local result = UnitTransfer.ValidateUnits(policy, { fusionId }, api, mockDefs)
			assert.equal(0, result.buildDelayedUnitCount)
		end)
	end)

	describe("ValidateUnits stun tally", function()
		it("counts stun-category units among the valid units", function()
			local fusionId, builderId = 920, 921
			sender.units = {}
			sender.units[fusionId] = { unitDefId = 1, beingBuilt = false, buildProgress = 1.0 }
			sender.units[builderId] = { unitDefId = 4, beingBuilt = false, buildProgress = 1.0 }
			local api = spring:Build()

			local policy = {
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 30,
				stunCategory = ConstructionEnums.UnitFilterCategory.Resource,
			}

			local result = UnitTransfer.ValidateUnits(policy, { fusionId, builderId }, api, mockDefs)
			assert.equal(2, result.validUnitCount)
			assert.equal(1, result.stunnedUnitCount)
		end)

		it("counts zero when the selection has no stun-category units", function()
			local builderId = 922
			sender.units = {}
			sender.units[builderId] = { unitDefId = 4, beingBuilt = false, buildProgress = 1.0 }
			local api = spring:Build()

			local policy = {
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 30,
				stunCategory = ConstructionEnums.UnitFilterCategory.Resource,
			}

			local result = UnitTransfer.ValidateUnits(policy, { builderId }, api, mockDefs)
			assert.equal(0, result.stunnedUnitCount)
		end)
	end)
end)

-- The per-team factor cache the controller refreshes and the transfer reads.
---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local ContextFactoryModule = VFS.Include("modules/transfer/context_factory.lua")
local UnitTransfer = VFS.Include("modules/transfer/unit/synced.lua")
local UnitShared = VFS.Include("modules/transfer/unit/shared.lua")

local ALL = ConstructionEnums.UnitFilterCategory.All
local NONE = ConstructionEnums.UnitFilterCategory.None

describe("unit policy cache (per-team factors) #policy", function()
	local sender, receiver, enemy ---@type TeamBuilder, TeamBuilder, TeamBuilder
	local spring ---@type SpringSyncedBuilder

	before_each(function()
		sender = Builders.Team:new():Human()
		receiver = Builders.Team:new():Human()
		enemy = Builders.Team:new():Human()
		spring = Builders.Spring
			.new()
			:WithTeam(sender)
			:WithTeam(receiver)
			:WithTeam(enemy)
			:WithAlliance(sender.id, receiver.id, true)
			:WithAlliance(receiver.id, sender.id, true)
			:WithModOption(TransferEnums.ModOptions.UnitSharingMode, ALL)
			:WithTeamRulesParam(sender.id, "numActivePlayers", 1)
			:WithTeamRulesParam(receiver.id, "numActivePlayers", 1)
			:WithTeamRulesParam(enemy.id, "numActivePlayers", 1)
	end)

	local function populate()
		local springApi = spring:Build()
		local contextFactory = ContextFactoryModule.create(springApi)
		for _, teamId in ipairs(springApi.GetTeamList()) do
			UnitTransfer.CacheTeamFactor(springApi, teamId, contextFactory.policy(teamId, teamId))
		end
		return springApi, contextFactory
	end

	it("reconstructs an allied pair identically to a direct GetPolicy", function()
		local springApi, contextFactory = populate()
		local cached = UnitShared.GetCachedPolicyResult(sender.id, receiver.id, springApi)
		local direct = UnitTransfer.GetPolicy(contextFactory.policy(sender.id, receiver.id))
		assert.equal(direct.canShare, cached.canShare)
		assert.same(direct.sharingModes, cached.sharingModes)
	end)

	it("allows an allied pair under a shareable mode", function()
		local springApi = populate()
		assert.equal(true, UnitShared.GetCachedPolicyResult(sender.id, receiver.id, springApi).canShare)
	end)

	it("denies a cross-alliance pair", function()
		local springApi = populate()
		assert.equal(false, UnitShared.GetCachedPolicyResult(sender.id, enemy.id, springApi).canShare)
	end)

	it("denies when the sharing mode is None", function()
		spring:WithModOption(TransferEnums.ModOptions.UnitSharingMode, NONE)
		local springApi = populate()
		assert.equal(false, UnitShared.GetCachedPolicyResult(sender.id, receiver.id, springApi).canShare)
	end)

	it("denies when the receiver has no active players", function()
		spring:WithTeamRulesParam(receiver.id, "numActivePlayers", 0)
		local springApi = populate()
		assert.equal(false, UnitShared.GetCachedPolicyResult(sender.id, receiver.id, springApi).canShare)
	end)

	it("cheating bypasses the inactive-receiver gate", function()
		spring:WithTeamRulesParam(receiver.id, "numActivePlayers", 0)
		local springApi = populate()
		springApi.IsCheatingEnabled = function()
			return true
		end
		assert.equal(true, UnitShared.GetCachedPolicyResult(sender.id, receiver.id, springApi).canShare)
	end)

	it("cheating does NOT bypass the alliance gate (units, unlike resources)", function()
		local springApi = populate()
		springApi.IsCheatingEnabled = function()
			return true
		end
		assert.equal(false, UnitShared.GetCachedPolicyResult(sender.id, enemy.id, springApi).canShare)
	end)

	it("falls back to the global mode + alliance when factors are absent", function()
		local springApi = spring:Build()
		assert.equal(true, UnitShared.GetCachedPolicyResult(sender.id, receiver.id, springApi).canShare)
		assert.equal(false, UnitShared.GetCachedPolicyResult(sender.id, enemy.id, springApi).canShare)
	end)
end)
