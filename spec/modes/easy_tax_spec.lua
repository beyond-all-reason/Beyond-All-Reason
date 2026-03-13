---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local TransferEnums = VFS.Include("common/luaUtilities/team_transfer/transfer_enums.lua")
local H = Builders.Mode

local easyTaxMode = VFS.Include("modes/sharing/easy_tax.lua")

local sender = Builders.Team:new():Human()
local receiver = Builders.Team:new():Human()
local spring = Builders.Spring.new()
  :WithTeam(sender)
  :WithTeam(receiver)
  :WithAlliance(sender.id, receiver.id, true)
  :WithTeamRulesParam(receiver.id, "numActivePlayers", 1)
  :WithTeamRulesParam(sender.id, "numActivePlayers", 1)

describe("Easy Tax mode #policy", function()
  describe("with default settings (30% tax, zero thresholds)", function()
    ---@type ResourcePolicyResult
    local metalResult
    ---@type ResourcePolicyResult
    local energyResult

    before_each(function()
      sender:WithMetal(500):WithEnergy(500)
      receiver:WithMetal(0):WithEnergy(0)
      receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

      metalResult = H.buildModeResult(spring, easyTaxMode, sender, receiver, TransferEnums.ResourceType.METAL)
      energyResult = H.buildModeResult(spring, easyTaxMode, sender, receiver, TransferEnums.ResourceType.ENERGY)
    end)

    it("should ALLOW sharing of both resources", function()
      assert.equal(true, metalResult.canShare)
      assert.equal(true, energyResult.canShare)
    end)

    it("should apply 30% tax rate", function()
      assert.equal(0.30, metalResult.taxRate)
      assert.equal(0.30, energyResult.taxRate)
    end)

    it("should have zero tax-free allowance", function()
      assert.equal(0, metalResult.remainingTaxFreeAllowance)
      assert.equal(0, energyResult.remainingTaxFreeAllowance)
    end)

    it("should compute sendable amount with 30% tax overhead", function()
      -- sender=500, threshold=0, rate=0.30: 500 * 0.70 = 350
      assert.equal(350, metalResult.amountSendable)
      assert.equal(350, energyResult.amountSendable)
    end)
  end)

  describe("when receiver is full", function()
    ---@type ResourcePolicyResult
    local metalResult
    ---@type ResourcePolicyResult
    local energyResult

    before_each(function()
      sender:WithMetal(500):WithEnergy(500)
      receiver:WithMetal(1000):WithEnergy(1000)
      receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

      metalResult = H.buildModeResult(spring, easyTaxMode, sender, receiver, TransferEnums.ResourceType.METAL)
      energyResult = H.buildModeResult(spring, easyTaxMode, sender, receiver, TransferEnums.ResourceType.ENERGY)
    end)

    it("should NOT allow sharing", function()
      assert.equal(false, metalResult.canShare)
      assert.equal(false, energyResult.canShare)
    end)

    it("should set amount sendable to 0", function()
      assert.equal(0, metalResult.amountSendable)
      assert.equal(0, energyResult.amountSendable)
    end)
  end)

  describe("when sender is empty", function()
    it("should NOT allow sharing", function()
      sender:WithMetal(0):WithEnergy(0)
      receiver:WithMetal(0):WithEnergy(0)
      receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

      local metalResult = H.buildModeResult(spring, easyTaxMode, sender, receiver, TransferEnums.ResourceType.METAL)
      local energyResult = H.buildModeResult(spring, easyTaxMode, sender, receiver, TransferEnums.ResourceType.ENERGY)

      assert.equal(false, metalResult.canShare)
      assert.equal(false, energyResult.canShare)
    end)
  end)

  describe("when sender has less than desired", function()
    it("should cap sendable amount to sender budget after tax", function()
      sender:WithMetal(50):WithEnergy(500)
      receiver:WithMetal(0):WithEnergy(0)
      receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

      local policy = H.snapshotResult(
        H.buildModeResult(spring, easyTaxMode, sender, receiver, TransferEnums.ResourceType.METAL))

      assert.equal(true, policy.canShare)
      -- sender=50, threshold=0, rate=0.30: 50 * 0.70 = 35
      assert.equal(35, policy.amountSendable)
    end)
  end)

  describe("transfer action with 30% tax", function()
    it("should deduct more from sender than receiver gets", function()
      sender:WithMetal(500):WithEnergy(500)
      receiver:WithMetal(0):WithEnergy(0)
      receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

      local result = H.buildModeTransfer(
        spring, easyTaxMode, sender, receiver, TransferEnums.ResourceType.METAL, 100)

      assert.is_true(result.success)
      assert.equal(100, result.received)
      assert.is_true(result.sent > result.received)
    end)

    it("should transfer energy with tax overhead", function()
      sender:WithMetal(500):WithEnergy(500)
      receiver:WithMetal(0):WithEnergy(0)
      receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

      local result = H.buildModeTransfer(
        spring, easyTaxMode, sender, receiver, TransferEnums.ResourceType.ENERGY, 200)

      assert.is_true(result.success)
      assert.equal(200, result.received)
      -- 30% tax: sender pays 200 / 0.7 ≈ 285.71
      assert.is_near(285.71, result.sent, 0.1)
    end)

    it("should not transfer when receiver is full", function()
      sender:WithMetal(500):WithEnergy(500)
      receiver:WithMetal(1000):WithEnergy(1000)
      receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

      local result = H.buildModeTransfer(
        spring, easyTaxMode, sender, receiver, TransferEnums.ResourceType.METAL, 100)

      assert.equal(false, result.success)
      assert.equal(0, result.sent)
      assert.equal(0, result.received)
    end)
  end)
end)
