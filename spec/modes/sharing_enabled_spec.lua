---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local TransferEnums = VFS.Include("common/luaUtilities/team_transfer/transfer_enums.lua")
local H = Builders.Mode

local enabledMode = VFS.Include("modes/sharing/enabled.lua")

local sender = Builders.Team:new():Human()
local receiver = Builders.Team:new():Human()
local spring = Builders.Spring.new()
  :WithTeam(sender)
  :WithTeam(receiver)
  :WithAlliance(sender.id, receiver.id, true)
  :WithTeamRulesParam(receiver.id, "numActivePlayers", 1)
  :WithTeamRulesParam(sender.id, "numActivePlayers", 1)

describe("Sharing Enabled mode #policy", function()
  describe("with default settings (zero tax, zero thresholds)", function()
    ---@type ResourcePolicyResult
    local metalResult
    ---@type ResourcePolicyResult
    local energyResult

    before_each(function()
      sender:WithMetal(500):WithEnergy(500)
      receiver:WithMetal(0):WithEnergy(0)
      receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

      metalResult = H.buildModeResult(spring, enabledMode, sender, receiver, TransferEnums.ResourceType.METAL)
      energyResult = H.buildModeResult(spring, enabledMode, sender, receiver, TransferEnums.ResourceType.ENERGY)
    end)

    it("should ALLOW sharing of both resources", function()
      assert.equal(true, metalResult.canShare)
      assert.equal(true, energyResult.canShare)
    end)

    it("should have zero tax rate", function()
      assert.equal(0, metalResult.taxRate)
      assert.equal(0, energyResult.taxRate)
    end)

    it("should have sendable equal to full sender budget (no tax overhead)", function()
      assert.equal(500, metalResult.amountSendable)
      assert.equal(500, energyResult.amountSendable)
    end)

    it("should have receivable equal to full receiver capacity", function()
      assert.equal(1000, metalResult.amountReceivable)
      assert.equal(1000, energyResult.amountReceivable)
    end)
  end)

  describe("when receiver is full", function()
    it("should NOT allow sharing", function()
      sender:WithMetal(500):WithEnergy(500)
      receiver:WithMetal(1000):WithEnergy(1000)
      receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

      local metalResult = H.buildModeResult(spring, enabledMode, sender, receiver, TransferEnums.ResourceType.METAL)
      local energyResult = H.buildModeResult(spring, enabledMode, sender, receiver, TransferEnums.ResourceType.ENERGY)

      assert.equal(false, metalResult.canShare)
      assert.equal(false, energyResult.canShare)
    end)
  end)

  describe("transfer action (untaxed)", function()
    it("should transfer with sent == received (no tax deducted)", function()
      sender:WithMetal(500):WithEnergy(500)
      receiver:WithMetal(0):WithEnergy(0)
      receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

      local result = H.buildModeTransfer(
        spring, enabledMode, sender, receiver, TransferEnums.ResourceType.METAL, 200)

      assert.is_true(result.success)
      assert.equal(200, result.received)
      assert.equal(200, result.sent)
    end)

    it("should transfer energy with sent == received", function()
      sender:WithMetal(500):WithEnergy(500)
      receiver:WithMetal(0):WithEnergy(0)
      receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

      local result = H.buildModeTransfer(
        spring, enabledMode, sender, receiver, TransferEnums.ResourceType.ENERGY, 300)

      assert.is_true(result.success)
      assert.equal(300, result.received)
      assert.equal(300, result.sent)
    end)

    it("should not transfer when receiver is full", function()
      sender:WithMetal(500):WithEnergy(500)
      receiver:WithMetal(1000):WithEnergy(1000)
      receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

      local result = H.buildModeTransfer(
        spring, enabledMode, sender, receiver, TransferEnums.ResourceType.METAL, 100)

      assert.equal(false, result.success)
      assert.equal(0, result.sent)
      assert.equal(0, result.received)
    end)
  end)
end)
