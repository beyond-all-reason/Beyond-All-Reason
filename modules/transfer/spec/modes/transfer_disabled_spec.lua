---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local TransferEnums = VFS.Include("modules/context/enums.lua")
local H = Builders.Mode

local ModeEnums = VFS.Include("modules/context/mode_enums.lua")

local noSharingMode = VFS.Include("modules/transfer/modes/disabled.lua")

local sender = Builders.Team:new():Human()
local receiver = Builders.Team:new():Human()
local spring = Builders.Spring
	.new()
	:WithTeam(sender)
	:WithTeam(receiver)
	:WithAlliance(sender.id, receiver.id, true)
	:WithTeamRulesParam(receiver.id, "numActivePlayers", 1)
	:WithTeamRulesParam(sender.id, "numActivePlayers", 1)

describe("Transfer Disabled mode #policy", function()
	describe("resource policy", function()
		it("should deny metal sharing", function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local metalResult =
				H.buildModeResult(spring, noSharingMode, sender, receiver, TransferEnums.ResourceType.METAL)

			assert.equal(false, metalResult.canShare)
		end)

		it("should deny energy sharing", function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local energyResult =
				H.buildModeResult(spring, noSharingMode, sender, receiver, TransferEnums.ResourceType.ENERGY)

			assert.equal(false, energyResult.canShare)
		end)
	end)

	describe("transfer action", function()
		it("should fail metal transfer with zero sent and received", function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local result =
				H.buildModeTransfer(spring, noSharingMode, sender, receiver, TransferEnums.ResourceType.METAL, 100)

			assert.equal(false, result.success)
			assert.equal(0, result.sent)
			assert.equal(0, result.received)
		end)

		it("should fail energy transfer with zero sent and received", function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local result =
				H.buildModeTransfer(spring, noSharingMode, sender, receiver, TransferEnums.ResourceType.ENERGY, 100)

			assert.equal(false, result.success)
			assert.equal(0, result.sent)
			assert.equal(0, result.received)
		end)
	end)

	describe("policy bundle", function()
		it("serializes to the exact modOptions the literal preset declared", function()
			assert.same({
				[ModeEnums.ModOptions.UnitSharingMode] = { value = ModeEnums.UnitFilterCategory.None, locked = true },
				[ModeEnums.ModOptions.ResourceSharingEnabled] = { value = false, locked = true },
				[ModeEnums.ModOptions.TaxResourceSharingAmount] = { value = 0.30, locked = false, ui = "hidden" },
				[ModeEnums.ModOptions.AlliedAssistMode] = { value = ModeEnums.AlliedAssistMode.Disabled, locked = true },
				[ModeEnums.ModOptions.AlliedUnitReclaimMode] = {
					value = ModeEnums.AlliedUnitReclaimMode.Disabled,
					locked = true,
				},
				[ModeEnums.ModOptions.TakeMode] = { value = ModeEnums.TakeMode.Disabled, locked = false },
			}, noSharingMode.modOptions)
		end)

		it("DSL chain builds the same ModeConfig as the explicit table form", function()
			local Bundle = VFS.Include("modules/transfer/policy_bundle.lua")
			local policies = {
				{ "unit.deny" },
				{ "resource.deny" },
				{ "resource.tax", rate = 0.30, locked = false, ui = "hidden" },
				{ "assist.deny" },
				{ "reclaim.deny" },
				{ "take.deny", locked = false },
			}
			local explicit = {
				key = ModeEnums.Modes.Disabled,
				category = ModeEnums.ModeCategories.Transfer,
				name = "Disabled",
				desc = "No sharing of any kind: no resources, no units, no assisting or reclaiming an ally, no /take. Most sharing options are locked.",
				allowRanked = true,
				policies = policies,
				modOptions = Bundle.toModOptions(policies),
			}
			for field, expected in pairs(explicit) do
				assert.same(expected, noSharingMode[field], field)
			end
		end)
	end)
end)
