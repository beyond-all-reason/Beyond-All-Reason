---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local ConstructionEnums = require("modules/construction/enums")
local TransferEnums = require("modules/transfer/enums")
local UnitShared = require("modules/transfer/unit/shared")

local Units = {
	AdvancedConstructor = "coracv",
	Pawn = "armpw",
	Fusion = "armfus",
	Constructor = "corcv",
}

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

describe("stun mechanics #stun", function()
	-- the dials an anti-co-op mode sets: a stun on gifted resource buildings, a build delay on gifted constructors
	local stunningModOpts = {
		unit_sharing_mode = "all",
		unit_share_stun_seconds = "30",
		unit_stun_category = "resource",
		constructor_build_delay = "30",
	}

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

	describe("Terms", function()
		it("should expose stunSeconds, stunCategory and buildDelaySeconds from the dials", function()
			local api = spring:Build()
			api.GetModOptions = function()
				return stunningModOpts
			end

			local policy = UnitShared.Terms(sender.id, receiver.id, api)

			assert.equal(30, policy.stunSeconds)
			assert.equal(ConstructionEnums.UnitFilterCategory.Resource, policy.stunCategory)
			assert.equal(30, policy.buildDelaySeconds)
		end)

		it("should default stunSeconds and buildDelaySeconds to 0 when not configured", function()
			local api = spring:Build()
			api.GetModOptions = function()
				return { unit_sharing_mode = "all" }
			end

			local policy = UnitShared.Terms(sender.id, receiver.id, api)

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
				senderTeamId = sender.id,
				receiverTeamId = receiver.id,
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 30,
				stunCategory = ConstructionEnums.UnitFilterCategory.Resource,
			}

			local result = UnitShared.ValidateUnits(policy, { nanoframeId }, api, mockDefs)
			assert.equal(0, result.validUnitCount)
			assert.equal(1, result.invalidUnitCount)
		end)

		it("should allow nanoframes of production units when stun category is resource", function()
			local nanoframeId = 902
			sender.units = {}
			sender.units[nanoframeId] = { unitDefId = 2, beingBuilt = true, buildProgress = 0.3 }
			local api = spring:Build()

			local policy = {
				senderTeamId = sender.id,
				receiverTeamId = receiver.id,
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 30,
				stunCategory = ConstructionEnums.UnitFilterCategory.Resource,
			}

			local result = UnitShared.ValidateUnits(policy, { nanoframeId }, api, mockDefs)
			assert.equal(1, result.validUnitCount)
			assert.equal(0, result.invalidUnitCount)
		end)

		it("should allow completed stun-category units", function()
			local completedId = 903
			sender.units = {}
			sender.units[completedId] = { unitDefId = 1, beingBuilt = false, buildProgress = 1.0 }
			local api = spring:Build()

			local policy = {
				senderTeamId = sender.id,
				receiverTeamId = receiver.id,
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 30,
				stunCategory = ConstructionEnums.UnitFilterCategory.Resource,
			}

			local result = UnitShared.ValidateUnits(policy, { completedId }, api, mockDefs)
			assert.equal(1, result.validUnitCount)
			assert.equal(0, result.invalidUnitCount)
		end)

		it("should allow combat nanoframes (not in EconomicPlusBuildings stun category)", function()
			local combatNanoId = 904
			sender.units = {}
			sender.units[combatNanoId] = { unitDefId = 3, beingBuilt = true, buildProgress = 0.3 }
			local api = spring:Build()

			local policy = {
				senderTeamId = sender.id,
				receiverTeamId = receiver.id,
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 30,
				stunCategory = ConstructionEnums.UnitFilterCategory.Resource,
			}

			local result = UnitShared.ValidateUnits(policy, { combatNanoId }, api, mockDefs)
			assert.equal(1, result.validUnitCount)
			assert.equal(0, result.invalidUnitCount)
		end)

		it("should allow all nanoframes when stunSeconds is 0", function()
			local nanoframeId = 905
			sender.units = {}
			sender.units[nanoframeId] = { unitDefId = 1, beingBuilt = true, buildProgress = 0.5 }
			local api = spring:Build()

			local policy = {
				senderTeamId = sender.id,
				receiverTeamId = receiver.id,
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 0,
				stunCategory = ConstructionEnums.UnitFilterCategory.Resource,
			}

			local result = UnitShared.ValidateUnits(policy, { nanoframeId }, api, mockDefs)
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
				senderTeamId = sender.id,
				receiverTeamId = receiver.id,
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 30,
				stunCategory = ConstructionEnums.UnitFilterCategory.Resource,
			}

			local result = UnitShared.ValidateUnits(policy, { nanoId, completedId }, api, mockDefs)
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
				senderTeamId = sender.id,
				receiverTeamId = receiver.id,
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 15,
				stunCategory = ConstructionEnums.UnitFilterCategory.Combat,
			}

			local result = UnitShared.ValidateUnits(policy, { combatNanoId }, api, mockDefs)
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
				senderTeamId = sender.id,
				receiverTeamId = receiver.id,
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 0,
			}

			local result = UnitShared.ValidateUnits(policy, { builderId, fusionId }, api, mockDefs)
			assert.equal(2, result.validUnitCount)
			assert.equal(1, result.buildDelayedUnitCount)
		end)

		it("counts zero when the selection has no mobile builders", function()
			local fusionId = 912
			sender.units = {}
			sender.units[fusionId] = { unitDefId = 1, beingBuilt = false, buildProgress = 1.0 }
			local api = spring:Build()

			local policy = {
				senderTeamId = sender.id,
				receiverTeamId = receiver.id,
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 0,
			}

			local result = UnitShared.ValidateUnits(policy, { fusionId }, api, mockDefs)
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
				senderTeamId = sender.id,
				receiverTeamId = receiver.id,
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 30,
				stunCategory = ConstructionEnums.UnitFilterCategory.Resource,
			}

			local result = UnitShared.ValidateUnits(policy, { fusionId, builderId }, api, mockDefs)
			assert.equal(2, result.validUnitCount)
			assert.equal(1, result.stunnedUnitCount)
		end)

		it("counts zero when the selection has no stun-category units", function()
			local builderId = 922
			sender.units = {}
			sender.units[builderId] = { unitDefId = 4, beingBuilt = false, buildProgress = 1.0 }
			local api = spring:Build()

			local policy = {
				senderTeamId = sender.id,
				receiverTeamId = receiver.id,
				canShare = true,
				sharingModes = { ConstructionEnums.UnitFilterCategory.All },
				stunSeconds = 30,
				stunCategory = ConstructionEnums.UnitFilterCategory.Resource,
			}

			local result = UnitShared.ValidateUnits(policy, { builderId }, api, mockDefs)
			assert.equal(0, result.stunnedUnitCount)
		end)
	end)
end)

local ALL = ConstructionEnums.UnitFilterCategory.All
local NONE = ConstructionEnums.UnitFilterCategory.None

-- The terms are one evaluation of the policy, on whichever handle asks: the gates are the policy's.
describe("the terms, evaluated where they are asked #policy", function()
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

	---@param a integer
	---@param b integer
	---@param api table? a built mock; a fresh build when nil
	---@return UnitTransferTerms
	local function termsFor(a, b, api)
		return UnitShared.Terms(a, b, api or spring:Build())
	end

	it("allows an allied pair under a shareable mode, with the mode's sharingModes", function()
		local terms = termsFor(sender.id, receiver.id)
		assert.is_true(terms.canShare)
		assert.same({ ALL }, terms.sharingModes)
		assert.equal(sender.id, terms.senderTeamId)
		assert.equal(receiver.id, terms.receiverTeamId)
	end)

	it("refuses a cross-alliance pair", function()
		assert.is_false(termsFor(sender.id, enemy.id).canShare)
	end)

	it("refuses when the sharing mode is None", function()
		spring:WithModOption(TransferEnums.ModOptions.UnitSharingMode, NONE)
		assert.is_false(termsFor(sender.id, receiver.id).canShare)
	end)

	it("refuses when the receiver has no active players", function()
		spring:WithTeamRulesParam(receiver.id, "numActivePlayers", 0)
		assert.is_false(termsFor(sender.id, receiver.id).canShare)
	end)

	it("cheating bypasses the inactive-receiver gate", function()
		spring:WithTeamRulesParam(receiver.id, "numActivePlayers", 0)
		local api = spring:Build()
		api.IsCheatingEnabled = function()
			return true
		end
		assert.is_true(termsFor(sender.id, receiver.id, api).canShare)
	end)

	it("cheating does NOT bypass the alliance gate (units, unlike resources)", function()
		local api = spring:Build()
		api.IsCheatingEnabled = function()
			return true
		end
		assert.is_false(termsFor(sender.id, enemy.id, api).canShare)
	end)
end)
