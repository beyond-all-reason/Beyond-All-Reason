---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local TransferEnums = VFS.Include("common/luaUtilities/team_transfer/transfer_enums.lua")
local H = Builders.Mode

local noSharingMode = VFS.Include("modes/sharing/disabled.lua")

local sender = Builders.Team:new():Human()
local receiver = Builders.Team:new():Human()
local spring = Builders.Spring.new()
  :WithTeam(sender)
  :WithTeam(receiver)
  :WithAlliance(sender.id, receiver.id, true)
  :WithTeamRulesParam(receiver.id, "numActivePlayers", 1)
  :WithTeamRulesParam(sender.id, "numActivePlayers", 1)

describe("Sharing Disabled mode #policy", function()
  describe("resource policy", function()
    it("should deny metal sharing", function()
      sender:WithMetal(500):WithEnergy(500)
      receiver:WithMetal(0):WithEnergy(0)
      receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

      local metalResult = H.buildModeResult(spring, noSharingMode, sender, receiver, TransferEnums.ResourceType.METAL)

      assert.equal(false, metalResult.canShare)
    end)

    it("should deny energy sharing", function()
      sender:WithMetal(500):WithEnergy(500)
      receiver:WithMetal(0):WithEnergy(0)
      receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

      local energyResult = H.buildModeResult(spring, noSharingMode, sender, receiver, TransferEnums.ResourceType.ENERGY)

      assert.equal(false, energyResult.canShare)
    end)
  end)

  describe("transfer action", function()
    it("should fail metal transfer with zero sent and received", function()
      sender:WithMetal(500):WithEnergy(500)
      receiver:WithMetal(0):WithEnergy(0)
      receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

      local result = H.buildModeTransfer(
        spring, noSharingMode, sender, receiver, TransferEnums.ResourceType.METAL, 100)

      assert.equal(false, result.success)
      assert.equal(0, result.sent)
      assert.equal(0, result.received)
    end)

    it("should fail energy transfer with zero sent and received", function()
      sender:WithMetal(500):WithEnergy(500)
      receiver:WithMetal(0):WithEnergy(0)
      receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

      local result = H.buildModeTransfer(
        spring, noSharingMode, sender, receiver, TransferEnums.ResourceType.ENERGY, 100)

      assert.equal(false, result.success)
      assert.equal(0, result.sent)
      assert.equal(0, result.received)
    end)
  end)
end)
