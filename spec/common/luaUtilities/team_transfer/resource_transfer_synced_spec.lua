---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local ResourceTransfer = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_synced.lua")
local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")

local sender = Builders.Team:new():Human()
local receiver = Builders.Team:new():Human()

local function buildResourceResult(spring, taxRate, metalThreshold, energyThreshold, sender, receiver, resourceType)
  local resultFactory = ResourceTransfer.BuildResultFactory(taxRate, metalThreshold, energyThreshold)
  local ctx = ContextFactoryModule.create(spring:Build()).policy(sender.id, receiver.id)
  return resultFactory(ctx, resourceType)
end

local spring = Builders.Spring.new()
  :WithTeam(sender)
  :WithTeam(receiver)
  :WithAlliance(sender.id, receiver.id, true)
  -- currently set by cmd_idle_players.lua, which I am trying REALLY hard not to refactor right now
  :WithTeamRulesParam(receiver.id, "numActivePlayers", 1)
  :WithTeamRulesParam(sender.id, "numActivePlayers", 1)

describe(SharedEnums.ModOptions.TaxResourceSharingAmount .. " #policy", function()
  local taxRate = 0.5

  describe("simple taxation", function()
    ---@type ResourcePolicyResult
    local metalResult
    ---@type ResourcePolicyResult
    local energyResult

    before_each(function()
      sender:WithEnergy(500):WithMetal(500)
      receiver:WithEnergy(0):WithMetal(0)

      spring:WithModOption(SharedEnums.ModOptions.TaxResourceSharingAmount, taxRate)

      metalResult = buildResourceResult(spring, taxRate, 0, 0, sender, receiver, SharedEnums.ResourceType.METAL)
      energyResult = buildResourceResult(spring, taxRate, 0, 0, sender, receiver, SharedEnums.ResourceType.ENERGY)
    end)

    it("should ALLOW sharing of both METAL and ENERGY", function()
      assert.equal(metalResult.canShare, true)
      assert.equal(energyResult.canShare, true)
    end)

    it("should cap amount sendable (in receivable units) and account for tax overhead", function()
      assert.equal(250, metalResult.amountSendable)
      assert.equal(250, energyResult.amountSendable)
    end)

    it("should cap the amount receivable by the receivers storage capacity", function()
      assert.equal(1000, metalResult.amountReceivable)
      assert.equal(1000, energyResult.amountReceivable)
    end)

    it("should expose the tax rate", function()
      assert.equal(taxRate, metalResult.taxRate)
      assert.equal(taxRate, energyResult.taxRate)
    end)

    it("should not have a remaining tax free allowance", function()
      assert.equal(metalResult.remainingTaxFreeAllowance, 0)
    end)
  end)

  describe("when receiver is full", function()
    ---@type ResourcePolicyResult
    local metalResult
    ---@type ResourcePolicyResult
    local energyResult

    before_each(function()
      sender:WithEnergy(500):WithMetal(500)
      receiver:WithEnergy(1000):WithMetal(1000)

      metalResult = buildResourceResult(spring, taxRate, 0, 0, sender, receiver, SharedEnums.ResourceType.METAL)
      energyResult = buildResourceResult(spring, taxRate, 0, 0, sender, receiver, SharedEnums.ResourceType.ENERGY)
    end)

    it("should NOT allow sharing when receiver is full", function()
      assert.equal(metalResult.canShare, false)
      assert.equal(energyResult.canShare, false)
    end)

    it("should set amount sendable to 0", function()
      assert.equal(0, metalResult.amountSendable)
      assert.equal(0, energyResult.amountSendable)
    end)
  end)

  describe("when a receiver has more metal capacity than the threshold", function()
    it("should have an untaxed portion that is the threshold", function()
      sender:WithMetal(1000)
      receiver:WithMetal(980)
      local metalResult = buildResourceResult(spring, taxRate, 0, 0, sender, receiver, SharedEnums.ResourceType.METAL)
      assert.equal(metalResult.amountSendable, 20)
    end)
  end)

  describe("when a sender has less metal than the receiver has capacity", function()
    ---@type ResourcePolicyResult
    local metalResult
    local metalThreshold = 1000

    before_each(function()
      spring:WithModOption(SharedEnums.ModOptions.TaxResourceSharingAmount, taxRate)

      sender:WithMetal(1000)
      receiver:WithMetalStorage(5000)

      metalResult = buildResourceResult(spring, taxRate, metalThreshold, 0, sender, receiver, SharedEnums.ResourceType.METAL)
    end)

    it("should be entirely tax free", function()
      assert.equal(1000, metalResult.untaxedPortion)
    end)
  end)

  describe("rate = 0.7, receiver capacity 300, sender 1000", function()
    ---@type ResourcePolicyResult
    local energyResult
    local testTaxRate = 0.7

    before_each(function()
      spring:WithModOption(SharedEnums.ModOptions.TaxResourceSharingAmount, testTaxRate)
      sender:WithEnergy(1000)
      receiver:WithEnergyStorage(1000):WithEnergy(700)

      energyResult = buildResourceResult(spring, testTaxRate, 0, 0, sender, receiver, SharedEnums.ResourceType.ENERGY)
    end)

    it("should have amountReceivable set to receiver capacity and amountSendable == 300", function()
      assert.equal(300, energyResult.amountReceivable)
      assert.equal(300, energyResult.amountSendable)
    end)
  end)

  describe("sender 1000, rate = 0.7, receiver capacity 300, threshold 0, cumulative sent 0", function()
    ---@type ResourcePolicyResult
    local energyResult
    local testTaxRate = 0.7

    before_each(function()
      spring:WithModOption(SharedEnums.ModOptions.TaxResourceSharingAmount, testTaxRate)
      sender:WithEnergy(1000)
      receiver:WithEnergyStorage(1000):WithEnergy(700)

      energyResult = buildResourceResult(spring, testTaxRate, 0, 0, sender, receiver, SharedEnums.ResourceType.ENERGY)
    end)

    it("should enable sharing", function()
      assert.equal(true, energyResult.canShare)
    end)

    it("should have a receivable amount set to the receiver's capacity and amountSendable == 300", function()
      assert.equal(300, energyResult.amountReceivable)
      assert.equal(300, energyResult.amountSendable)
    end)
  end)

  describe("when taxation is disabled", function()
    ---@type ResourcePolicyResult
    local metalResult
    ---@type ResourcePolicyResult
    local energyResult

    before_each(function()
      spring:WithModOption(SharedEnums.ModOptions.TaxResourceSharingAmount, 0)
      receiver:WithEnergyStorage(1000):WithEnergy(0)
      receiver:WithMetalStorage(1000):WithMetal(0)
    end)

    it("should not tax metal transfers", function()
      sender:WithMetal(100)
      metalResult = buildResourceResult(spring, 0, 0, 0, sender, receiver, SharedEnums.ResourceType.METAL)
      assert.equal(1000, metalResult.amountReceivable)
      assert.equal(100, metalResult.amountSendable)

      sender:WithMetal(500)
      metalResult = buildResourceResult(spring, 0, 0, 0, sender, receiver, SharedEnums.ResourceType.METAL)
      assert.equal(1000, metalResult.amountReceivable)
      assert.equal(500, metalResult.amountSendable)
    end)

    it("should not tax energy transfers", function()
      sender:WithEnergy(100)
      energyResult = buildResourceResult(spring, 0, 0, 0, sender, receiver, SharedEnums.ResourceType.ENERGY)
      assert.equal(1000, energyResult.amountReceivable)
      assert.equal(100, energyResult.amountSendable)

      sender:WithEnergy(500)
      energyResult = buildResourceResult(spring, 0, 0, 0, sender, receiver, SharedEnums.ResourceType.ENERGY)
      assert.equal(1000, energyResult.amountReceivable)
      assert.equal(500, energyResult.amountSendable)
    end)
  end)
end)

describe("ResourceTransfer #action", function()
  local sender = Builders.Team:new():Human()
  local receiver = Builders.Team:new():Human()
  local spring = Builders.Spring.new()
      :WithTeam(sender)
      :WithTeam(receiver)
      :Build()

  describe("basic resource transfer", function()
    it("should transfer metal without tax when untaxed portion covers full amount", function()
      ---@type ResourceTransferContext
      local ctx = {
        senderTeamId = sender.id,
        receiverTeamId = receiver.id,
        transferCategory = SharedEnums.TransferCategory.MetalTransfer,
        resourceType = SharedEnums.ResourceType.METAL,
        desiredAmount = 100,
        resultSoFar = {},
        isCheatingEnabled = false,
        springRepo = spring,
        areAlliedTeams = true,
        sender = {
          metal = {
            current = 1000,
            storage = 1000,
            pull = 0,
            income = 0,
            expense = 0,
            shareSlider = 0,
            sent = 0,
            received = 0,
          },
          energy = {
            current = 1000,
            storage = 1000,
            pull = 0,
            income = 0,
            expense = 0,
            shareSlider = 0,
            sent = 0,
            received = 0,
          },
        },
        receiver = {
          metal = {
            current = 500,
            storage = 1000,
            pull = 0,
            income = 0,
            expense = 0,
            shareSlider = 0,
            sent = 0,
            received = 0,
          },
          energy = {
            current = 500,
            storage = 1000,
            pull = 0,
            income = 0,
            expense = 0,
            shareSlider = 0,
            sent = 0,
            received = 0,
          },
        },
        policyResult = {
          canShare = true,
          resourceType = SharedEnums.ResourceType.METAL,
          amountSendable = 500,
          amountReceivable = 500,
          untaxedPortion = 150,         -- More than desired amount
          taxRate = 0.3,
          taxedPortion = 0,
          remainingTaxFreeAllowance = 0,
          resourceShareThreshold = 0,
          cumulativeSent = 0,
          senderTeamId = sender.id,
          receiverTeamId = receiver.id,
        },
      }

      local result = ResourceTransfer.ResourceTransfer(ctx)

      assert.is_true(result.success)
      assert.equal(100, result.sent)
      assert.equal(100, result.received)
    end)

    it("should apply tax when desired amount exceeds untaxed portion", function()
      ---@type ResourceTransferContext
      local ctx = {
        senderTeamId = sender.id,
        receiverTeamId = receiver.id,
        transferCategory = SharedEnums.TransferCategory.MetalTransfer,
        resourceType = SharedEnums.ResourceType.METAL,
        desiredAmount = 200,
        resultSoFar = {},
        isCheatingEnabled = false,
        springRepo = spring,
        areAlliedTeams = true,
        sender = {
          metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
          energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
        },
        receiver = {
          metal = { current = 500, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
          energy = { current = 500, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
        },
        policyResult = {
          canShare = true,
          resourceType = SharedEnums.ResourceType.METAL,
          amountSendable = 500,
          amountReceivable = 500,
          untaxedPortion = 100,         -- Less than desired amount
          taxRate = 0.3,
          taxedPortion = 100,
          remainingTaxFreeAllowance = 0,
          resourceShareThreshold = 0,
          cumulativeSent = 0,
          senderTeamId = sender.id,
          receiverTeamId = receiver.id,
        },
      }

      local result = ResourceTransfer.ResourceTransfer(ctx)

      assert.is_true(result.success)
      -- Untaxed: 100, Taxed: 100
      -- Sender pays: 100 + (100 / 0.7) = 100 + 142.86 = 242.86
      -- Receiver gets: 100 + 100 = 200 (taxed portion is sent as 142.86, receiver gets 100)
      assert.is_near(242.86, result.sent, 0.1)
      assert.is_near(200, result.received, 0.1)
    end)

    it("should handle 100% tax rate", function()
      ---@type ResourceTransferContext
      local ctx = {
        senderTeamId = sender.id,
        receiverTeamId = receiver.id,
        transferCategory = SharedEnums.TransferCategory.MetalTransfer,
        resourceType = SharedEnums.ResourceType.METAL,
        desiredAmount = 200,
        resultSoFar = {},
        isCheatingEnabled = false,
        springRepo = spring,
        areAlliedTeams = true,
        sender = {
          metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
          energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
        },
        receiver = {
          metal = { current = 500, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
          energy = { current = 500, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
        },
        policyResult = {
          canShare = true,
          resourceType = SharedEnums.ResourceType.METAL,
          amountSendable = 500,
          amountReceivable = 500,
          untaxedPortion = 100,
          taxRate = 1.0,         -- 100% tax
          taxedPortion = 100,
          remainingTaxFreeAllowance = 0,
          resourceShareThreshold = 0,
          cumulativeSent = 0,
          senderTeamId = sender.id,
          receiverTeamId = receiver.id,
        },
      }

      local result = ResourceTransfer.ResourceTransfer(ctx)

      assert.is_true(result.success)
      -- Untaxed: 100, Taxed: 100
      -- Sender pays: 100 (tax rate of 1 means sender pays full amount)
      -- Receiver gets:  0 = 100 (tax rate of 1 means no taxed portion reaches receiver)
      assert.equal(100, result.sent)
      assert.equal(100, result.received)
    end)

    it("should limit transfer to amountSendable", function()
      --- @type ResourceTransferContext
      local ctx = {
        desiredAmount = 300,        -- Limited to amountSendable
        transferCategory = SharedEnums.TransferCategory.MetalTransfer,
        resultSoFar = {},
        isCheatingEnabled = false,
        senderTeamId = sender.id,
        receiverTeamId = receiver.id,
        resourceType = SharedEnums.ResourceType.METAL,
        policyResult = {
          canShare = true,
          resourceType = SharedEnums.ResourceType.METAL,
          amountSendable = 300,         -- Limit
          amountReceivable = 9999,
          untaxedPortion = 100,
          taxRate = 0.2,
          taxedPortion = 200,
          remainingTaxFreeAllowance = 0,
          resourceShareThreshold = 0,
          cumulativeSent = 0,
          senderTeamId = sender.id,
          receiverTeamId = receiver.id,
        },
        springRepo = spring,
        areAlliedTeams = true,
        sender = {
          metal = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
          energy = { current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
        },
        receiver = {
          metal = { current = 500, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
          energy = { current = 500, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
        },
      }

      local result = ResourceTransfer.ResourceTransfer(ctx)

      assert.is_true(result.success)
      assert.is_near(350, result.sent, 0.1)
      assert.is_near(300, result.received, 0.1)
    end)
  end)

  describe("CalculateSenderTaxedAmount helper", function()
    it("caps by amountSendable and amountReceivable and computes sender cost", function()
      local policyResult = {
        resourceType = SharedEnums.ResourceType.ENERGY,
        amountSendable = 820,       -- A=400, S=1000, r=0.3 => 400 + 600*0.7
        amountReceivable = 1000,
        untaxedPortion = 400,
        taxRate = 0.3
      }

      local desired = 820
      local desiredCapped = math.min(desired, policyResult.amountSendable, policyResult.amountReceivable)
      local received, sent = ResourceShared.CalculateSenderTaxedAmount(policyResult, desiredCapped)
      -- cost = 400 + 420/0.7 = 1000
      assert.is_near(1000, sent, 0.01)
      assert.equal(820, received)
    end)

    it("caps desired by amountReceivable when it is lower", function()
      local policyResult = {
        resourceType = SharedEnums.ResourceType.ENERGY,
        amountSendable = 500,
        amountReceivable = 300,
        untaxedPortion = 0,
        taxRate = 0.7
      }
      local desiredCapped = math.min(999, policyResult.amountSendable, policyResult.amountReceivable)
      local received, sent = ResourceShared.CalculateSenderTaxedAmount(policyResult, desiredCapped)
      assert.equal(300, received)
      assert.is_near(1000, sent, 0.01)     -- 300/(1-0.7)
    end)
  end)
end)
