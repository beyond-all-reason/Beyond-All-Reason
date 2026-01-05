---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local UnitTransfer = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_synced.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")

local Units = {
	AdvancedConstructor = "coracv",
	Pawn = "armpw",
	Fusion = "armfus",
    Constructor = "corcv",
}

---@class UnitSharingTestConfig
---@field mode string The sharing mode to test
---@field canShareUnits boolean Expected canShareUnits result
---@field testUnits table<string, boolean> Map of unit names to expected outcomes

local testConfigs = {
	[SharedEnums.UnitSharingMode.Disabled] = {
		mode = SharedEnums.UnitSharingMode.Disabled,
		canShareUnits = false,
		testUnits = {
			[Units.AdvancedConstructor] = false,
			[Units.Fusion] = false,
        }
	},
	[SharedEnums.UnitSharingMode.Enabled] = {
		mode = SharedEnums.UnitSharingMode.Enabled, 
		canShareUnits = true,
		testUnits = {
			[Units.AdvancedConstructor] = true,
			[Units.Fusion] = true,
        }
	},
	[SharedEnums.UnitSharingMode.CombatUnits] = {
		mode = SharedEnums.UnitSharingMode.CombatUnits,
		canShareUnits = true,
		testUnits = {
            [Units.Pawn] = true,
			[Units.Constructor] = false,
			[Units.AdvancedConstructor] = false,
			[Units.Fusion] = false,
        }
	},
	[SharedEnums.UnitSharingMode.Economic] = {
		mode = SharedEnums.UnitSharingMode.Economic,
		canShareUnits = true,
		testUnits = {
			[Units.Constructor] = true,
			[Units.AdvancedConstructor] = true,
			[Units.Fusion] = false,
			[Units.Pawn] = false,
		}
	},
	[SharedEnums.UnitSharingMode.EconomicPlusBuildings] = {
		mode = SharedEnums.UnitSharingMode.EconomicPlusBuildings,
		canShareUnits = true,
		testUnits = {
			[Units.AdvancedConstructor] = true,
			[Units.Constructor] = true,
			[Units.Fusion] = true,
			[Units.Pawn] = false,
		}
	},
	[SharedEnums.UnitSharingMode.T2Cons] = {
		mode = SharedEnums.UnitSharingMode.T2Cons,
		canShareUnits = true,
		testUnits = {
			[Units.AdvancedConstructor] = true,
			[Units.Constructor] = false,
            [Units.Fusion] = false,
			[Units.Pawn] = false,
		}
	}
}

describe(SharedEnums.ModOptions.UnitSharingMode .. " #policy", function()
    local sender = Builders.Team:new():Human()
    local receiver = Builders.Team:new():Human()

    local spring = Builders.Spring.new()
        :WithTeam(sender)
        :WithTeam(receiver)
        :WithAlliance(sender.id, receiver.id, true)

    -- Data-driven test execution
    for modeKey, config in pairs(testConfigs) do
        describe("WHEN unit sharing mode is set to " .. config.mode, function()
            spring:WithModOption(SharedEnums.ModOptions.UnitSharingMode, config.mode)
            local result
            local unitIds = {}
            local api

            before_each(function()
                unitIds = {}
                sender.units = {}
                -- Build units required for this config so ValidateUnits can resolve unitDefs
                for unitDefName, _ in pairs(config.testUnits) do
                    sender:WithUnit(unitDefName, function(id) unitIds[unitDefName] = id end)
                end
                spring:WithRealUnitDefs()
                api = spring:Build()
                local defsByKey = {}
                local defs = api.GetUnitDefs()
                for key, def in pairs(defs or {}) do
                    if def then
                        defsByKey[key] = def
                        if def.id then defsByKey[def.id] = def end
                        if def.name then defsByKey[def.name] = def end
                    end
                end
                _G.UnitDefs = defsByKey
                local ctx = ContextFactoryModule.create(api).policy(sender.id, receiver.id)
                result = UnitTransfer.GetPolicy(ctx)
            end)

            after_each(function()
                _G.UnitDefs = nil
            end)

            it("should have correct sharing permissions", function()
                assert.equal(config.canShareUnits, result.canShare)
            end)

            -- Generate tests for each unit - validation
            for unitDefName, shouldAllow in pairs(config.testUnits) do
                it("should " .. (shouldAllow and "allow" or "not allow") .. " validating transfer of " .. unitDefName, function()
                    local unitId = unitIds[unitDefName]
                    assert.is_not_nil(unitId)
                    local validation = UnitTransfer.ValidateUnits(result, { unitId }, api, _G.UnitDefs)
                    if not config.canShareUnits then
                        -- Disabled mode short-circuits validation
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
                end)
            end
        end)
    end
end)

describe("UnitTransfer #action", function()
    local sender = Builders.Team:new():Human()
    local receiver = Builders.Team:new():Human()
    local spring = Builders.Spring.new()
        :WithTeam(sender)
        :WithTeam(receiver)
        :Build()

    describe("when unit sharing is allowed", function()
        local unitIds
        local result
        local spring

        before_each(function()
            unitIds = {}
            sender:WithUnit("armpw", function(unitId) table.insert(unitIds, unitId) end)
            sender:WithUnit("armck", function(unitId) table.insert(unitIds, unitId) end)

            -- Rebuild spring repo after adding units
            spring = Builders.Spring.new()
                :WithTeam(sender)
                :WithTeam(receiver)
                :Build()
        end)

        it("should successfully transfer all units when sharing is allowed", function()
            ---@type UnitTransferContext
            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                transferCategory = SharedEnums.TransferCategory.UnitTransfer,
                unitIds = unitIds,
                given = false,
                resultSoFar = {},
                springRepo = spring,
                areAlliedTeams = true,
                isCheatingEnabled = false,
                sender = {
                    metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                    energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                },
                receiver = {
                    metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                    energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                },
                validationResult = {
                    status = SharedEnums.UnitValidationOutcome.Success,
                    validUnitIds = unitIds,
                    validUnitCount = #unitIds,
                    validUnitNames = {},
                    invalidUnitIds = {},
                    invalidUnitCount = 0,
                    invalidUnitNames = {},
                },
                policyResult = {
                    canShare = true,
                    sharingMode = SharedEnums.UnitSharingMode.Enabled,
                    senderTeamId = sender.id,
                    receiverTeamId = receiver.id,
                },
            }

            local transferSpy = spy.on(spring, "TransferUnit")
            result = UnitTransfer.UnitTransfer(ctx)

            assert.equal(SharedEnums.UnitValidationOutcome.Success, result.outcome)
            assert.equal(#unitIds, result.validationResult.validUnitCount)
            assert.equal(0, result.validationResult.invalidUnitCount)
            assert.spy(transferSpy).was.called(#unitIds)
            assert.spy(transferSpy).was.called_with(unitIds[1], receiver.id, false)
        end)

        it("should handle mixed success/failure scenarios", function()
            -- Add an invalid unit ID to test partial failure
            local mixedUnitIds = {unitIds[1], 9999, unitIds[2]}  -- 9999 is invalid

            ---@type UnitTransferContext
            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                transferCategory = SharedEnums.TransferCategory.UnitTransfer,
                unitIds = mixedUnitIds,
                given = false,
                resultSoFar = {},
                springRepo = spring,
                areAlliedTeams = true,
                isCheatingEnabled = false,
                sender = {
                    metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                    energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                },
                receiver = {
                    metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                    energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                },
                validationResult = {
                    status = SharedEnums.UnitValidationOutcome.PartialSuccess,
                    validUnitIds = { mixedUnitIds[1], mixedUnitIds[3] },
                    validUnitCount = 2,
                    validUnitNames = {},
                    invalidUnitIds = { mixedUnitIds[2] },
                    invalidUnitCount = 1,
                    invalidUnitNames = {},
                },
                policyResult = {
                    canShare = true,
                    sharingMode = SharedEnums.UnitSharingMode.Enabled,
                    senderTeamId = sender.id,
                    receiverTeamId = receiver.id,
                },
            }

            result = UnitTransfer.UnitTransfer(ctx)

            assert.equal(SharedEnums.UnitValidationOutcome.PartialSuccess, result.outcome)
            assert.equal(2, result.validationResult.validUnitCount)
            assert.equal(1, result.validationResult.invalidUnitCount)
            assert.equal(9999, result.validationResult.invalidUnitIds[1])
        end)

        it("should set given parameter correctly", function()
            ---@type UnitTransferContext
            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                transferCategory = SharedEnums.TransferCategory.UnitTransfer,
                unitIds = {unitIds[1]},
                given = true,  -- Test given parameter
                resultSoFar = {},
                springRepo = spring,
                areAlliedTeams = true,
                isCheatingEnabled = false,
                sender = {
                    metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                    energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                },
                receiver = {
                    metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                    energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                },
                validationResult = {
                    status = SharedEnums.UnitValidationOutcome.Success,
                    validUnitIds = { unitIds[1] },
                    validUnitCount = 1,
                    validUnitNames = {},
                    invalidUnitIds = {},
                    invalidUnitCount = 0,
                    invalidUnitNames = {},
                },
                policyResult = {
                    canShare = true,
                    sharingMode = SharedEnums.UnitSharingMode.Enabled,
                    senderTeamId = sender.id,
                    receiverTeamId = receiver.id,
                },
            }

            result = UnitTransfer.UnitTransfer(ctx)

            assert.equal(SharedEnums.UnitValidationOutcome.Success, result.outcome)
            assert.equal(1, result.validationResult.validUnitCount)
            assert.equal(0, result.validationResult.invalidUnitCount)
        end)
    end)

    describe("when unit sharing is not allowed", function()
        local unitIds
        local result
        local spring

        before_each(function()
            unitIds = {}
            sender:WithUnit("armpw", function(unitId) table.insert(unitIds, unitId) end)
            sender:WithUnit("armck", function(unitId) table.insert(unitIds, unitId) end)

            -- Rebuild spring repo after adding units
            spring = Builders.Spring.new()
                :WithTeam(sender)
                :WithTeam(receiver)
                :Build()
        end)

        it("should fail to transfer any units when sharing is disabled", function()
            ---@type UnitTransferContext
            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                transferCategory = SharedEnums.TransferCategory.UnitTransfer,
                unitIds = unitIds,
                given = false,
                resultSoFar = {},
                springRepo = spring,
                areAlliedTeams = true,
                isCheatingEnabled = false,
                sender = {
                    metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                    energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                },
                receiver = {
                    metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                    energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                },
                validationResult = {
                    status = SharedEnums.UnitValidationOutcome.Success,
                    validUnitIds = unitIds,
                    validUnitCount = #unitIds,
                    validUnitNames = {},
                    invalidUnitIds = {},
                    invalidUnitCount = 0,
                    invalidUnitNames = {},
                },
                policyResult = {
                    canShare = false,
                    sharingMode = SharedEnums.UnitSharingMode.Disabled,
                    senderTeamId = sender.id,
                    receiverTeamId = receiver.id,
                },
            }

            result = UnitTransfer.UnitTransfer(ctx)

            assert.equal(SharedEnums.UnitValidationOutcome.Success, result.validationResult.status)
            -- When sharing is disabled, outcome should be Failure and no transfers
            assert.equal(SharedEnums.UnitValidationOutcome.Failure, result.outcome)
            assert.equal(#unitIds, result.validationResult.validUnitCount)
        end)

        it("should include policy result in response", function()
            local policyResult = {
                canShare = false,
                sharingMode = SharedEnums.UnitSharingMode.Disabled,
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
            }

            ---@type UnitTransferContext
            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                transferCategory = SharedEnums.TransferCategory.UnitTransfer,
                unitIds = unitIds,
                given = false,
                resultSoFar = {},
                springRepo = spring,
                areAlliedTeams = true,
                isCheatingEnabled = false,
                sender = {
                    metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                    energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                },
                receiver = {
                    metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                    energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                },
                validationResult = {
                    status = SharedEnums.UnitValidationOutcome.Success,
                    validUnitIds = unitIds,
                    validUnitCount = #unitIds,
                    validUnitNames = {},
                    invalidUnitIds = {},
                    invalidUnitCount = 0,
                    invalidUnitNames = {},
                },
                policyResult = policyResult,
            }

            result = UnitTransfer.UnitTransfer(ctx)

            assert.equal(policyResult, result.policyResult)
        end)
    end)

    describe("edge cases", function()
        it("should handle empty unit list", function()
            ---@type UnitTransferContext
            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                transferCategory = SharedEnums.TransferCategory.UnitTransfer,
                unitIds = {},
                resultSoFar = {},
                springRepo = spring,
                areAlliedTeams = true,
                isCheatingEnabled = false,
                sender = {
                    metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                    energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                },
                receiver = {
                    metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                    energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                },
                validationResult = {
                    status = SharedEnums.UnitValidationOutcome.Failure,
                    validUnitIds = {},
                    validUnitCount = 0,
                    validUnitNames = {},
                    invalidUnitIds = {},
                    invalidUnitCount = 0,
                    invalidUnitNames = {},
                },
                given = false,
                policyResult = {
                    canShare = true,
                    sharingMode = SharedEnums.UnitSharingMode.Enabled,
                    senderTeamId = sender.id,
                    receiverTeamId = receiver.id,
                },
            }

            result = UnitTransfer.UnitTransfer(ctx)

            assert.equal(SharedEnums.UnitValidationOutcome.Failure, result.outcome)  -- No units to transfer
            assert.equal(0, result.validationResult.validUnitCount)
            assert.equal(0, result.validationResult.invalidUnitCount)
        end)

        it("should handle invalid unit IDs gracefully", function()
            ---@type UnitTransferContext
            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                transferCategory = SharedEnums.TransferCategory.UnitTransfer,
                unitIds = {-1, 0, 9999},  -- All invalid
                resultSoFar = {},
                springRepo = spring,
                areAlliedTeams = true,
                isCheatingEnabled = false,
                sender = {
                    metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                    energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                },
                receiver = {
                    metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                    energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
                },
                validationResult = {
                    status = SharedEnums.UnitValidationOutcome.Failure,
                    validUnitIds = {},
                    validUnitCount = 0,
                    validUnitNames = {},
                    invalidUnitIds = {-1, 0, 9999},
                    invalidUnitCount = 3,
                    invalidUnitNames = {},
                },
                given = false,
                policyResult = {
                    canShare = true,
                    sharingMode = SharedEnums.UnitSharingMode.Enabled,
                    senderTeamId = sender.id,
                    receiverTeamId = receiver.id,
                },
            }

            result = UnitTransfer.UnitTransfer(ctx)

            assert.equal(SharedEnums.UnitValidationOutcome.Failure, result.outcome)
            assert.equal(0, result.validationResult.validUnitCount)
            assert.equal(3, result.validationResult.invalidUnitCount)
        end)
    end)
end)
