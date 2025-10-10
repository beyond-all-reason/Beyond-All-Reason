-- Shared helper for resource share tax calculations
-- Usable from both LuaRules (gadgets) and LuaUI (widgets)

local Tax = {}

local function sanitizeNumber(n, fallback)
	if type(n) ~= 'number' or n ~= n then -- NaN check
		return fallback or 0
	end
	return n
end

-- Calculates transfer breakdown given an intended transfer amount that already respects receiver caps
-- resourceName: 'metal' or 'energy'
-- amount: number (>= 0), already limited by receiver max share/storage rules
-- taxRate: 0..1 (fraction)
-- threshold: for metal only, total amount a sender can send tax-free cumulatively
-- cumulativeSent: current cumulative amount the sender already sent (for metal)
-- Returns table:
-- {
--   actualSent,         -- amount removed from sender
--   actualReceived,     -- amount added to receiver
--   untaxedPortion,     -- portion of amount not taxed (metal within remaining allowance)
--   taxablePortion,     -- portion of amount taxed
--   allowanceRemaining, -- metal allowance left before this transfer
--   newCumulative,      -- updated cumulative (metal only)
-- }
function Tax.computeTransfer(resourceName, amount, taxRate, threshold, cumulativeSent)
	resourceName = resourceName == 'm' and 'metal' or (resourceName == 'e' and 'energy' or resourceName)
	amount = sanitizeNumber(amount, 0)
	if amount < 0 then amount = 0 end
	taxRate = sanitizeNumber(taxRate, 0)
	if taxRate < 0 then taxRate = 0 end
	if taxRate > 1 then taxRate = 1 end
	threshold = sanitizeNumber(threshold, 0)
	cumulativeSent = sanitizeNumber(cumulativeSent, 0)

	local actualSent = 0
	local actualReceived = 0
	local untaxedPortion = 0
	local taxablePortion = 0
	local allowanceRemaining = 0
	local newCumulative = nil

	if resourceName == 'metal' and threshold > 0 then
		allowanceRemaining = math.max(0, threshold - cumulativeSent)
		untaxedPortion = math.min(amount, allowanceRemaining)
		taxablePortion = amount - untaxedPortion
		if taxablePortion > 0 then
			local taxedPortionReceived = taxablePortion * (1 - taxRate)
			local taxedPortionSent
			if taxRate == 1 then
				taxedPortionSent = taxablePortion
			else
				taxedPortionSent = taxablePortion / (1 - taxRate)
			end
			actualReceived = untaxedPortion + taxedPortionReceived
			actualSent = untaxedPortion + taxedPortionSent
		else
			actualReceived = untaxedPortion
			actualSent = untaxedPortion
		end
		newCumulative = cumulativeSent + actualSent
	else
		-- energy or metal without threshold
		actualReceived = amount * (1 - taxRate)
		if taxRate == 1 then
			actualSent = amount
		else
			actualSent = (1 - taxRate) > 0 and (actualReceived / (1 - taxRate)) or amount
		end
		untaxedPortion = 0
		taxablePortion = amount
		allowanceRemaining = 0
	end

	return {
		actualSent = actualSent,
		actualReceived = actualReceived,
		untaxedPortion = untaxedPortion,
		taxablePortion = taxablePortion,
		allowanceRemaining = allowanceRemaining,
		newCumulative = newCumulative,
	}
end

-- ResourceTransfer

---@class CalculateSenderTaxedAmountResult
---@field receivedAmount number
---@field sentAmountBeforeTax number

---@class ResourceTransferModule
---@field CalculateSenderTaxedAmount fun(policyResult: ResourcePolicyResult, desiredReceived: number): CalculateSenderTaxedAmountResult

local M = {}

--- Core helper: compute sender cost for a desired received amount under policyResult
---@param policyResult ResourcePolicyResult
---@param desiredReceived number
---@return CalculateSenderTaxedAmountResult
function M.CalculateSenderTaxedAmount(policyResult, desiredReceived)
    local maxReceivable = policyResult.amountReceivable
    local desired = math.min(desiredReceived, policyResult.amountSendable, maxReceivable)
    if desired <= 0 then
        return { sentAmount = 0, receivedAmount = 0 }
    end

    local untaxed = math.min(desired, policyResult.untaxedPortion)
    local taxed = desired - untaxed
    local r = policyResult.taxRate

    local received
    local sent
    if taxed > 0 then
        if r >= 1.0 then
            -- 100% tax means taxed portion cannot be sent (infinite cost)
            sent = untaxed
            received = untaxed  -- only untaxed portion reaches receiver
        else
            sent = untaxed + (taxed / (1 - r))
            received = desired  -- all desired amount reaches receiver
        end
    else
        sent = untaxed
        received = untaxed
    end

    return {
        sentAmount = sent,
        receivedAmount = received
    }
end

--- Execute a resource transfer using received-unit desiredAmount capped by policy limits
---@param ctx ResourceTransferContext
---@return ResourceTransferResult
local function ResourceTransfer(ctx)
    local policyResult = ctx.policyResult
    local desiredAmount = ctx.desiredAmount

    local amounts = M.CalculateSenderTaxedAmount(policyResult, desiredAmount)
    local actualSent = amounts.sentAmountBeforeTax
    local actualReceived = amounts.receivedAmount

    local springRepo = ctx.repositories.springRepo
    springRepo:AddTeamResource(ctx.senderTeamId, policyResult.resourceType, -actualSent)
    springRepo:AddTeamResource(ctx.receiverTeamId, policyResult.resourceType, actualReceived)

    ---@type ResourceTransferResult
    local result = {
        success = true,
        sent = actualSent,
        received = actualReceived,
        senderTeamId = ctx.senderTeamId,
        receiverTeamId = ctx.receiverTeamId,
        policyResult = policyResult
    }

    return result
end

-- Make module callable: M(ctx) → perform transfer
setmetatable(M, { __call = function(_, ctx) return ResourceTransfer(ctx) end })

return M


-- Tax Resource Sharing

-- local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local ModOptions = VFS.Include("luarules/gadgets/team_transfer/modoption_enums.lua")

local CUMULATIVE_METAL_PARAM = "metal_share_cumulative_sent"
local CUMULATIVE_ENERGY_PARAM = "energy_share_cumulative_sent"

local function getCumulativeParam(resourceType)
	if resourceType == SharedEnums.ResourceType.METAL then
		return CUMULATIVE_METAL_PARAM
	elseif resourceType == SharedEnums.ResourceType.ENERGY then
		return CUMULATIVE_ENERGY_PARAM
	end
end

local function getCumulativeSent(teamID, resourceType, springRepo)
	local param = getCumulativeParam(resourceType)
	return tonumber(springRepo:GetTeamRulesParam(teamID, param)) or 0
end

local buildResultFactory = function(taxRate, metalThreshold, energyThreshold)
	---@param resourceType ResourceType
	local function getThreshold(resourceType)
		if resourceType == SharedEnums.ResourceType.METAL then
			return metalThreshold
		elseif resourceType == SharedEnums.ResourceType.ENERGY then
			return energyThreshold
		end
	end

	---@param ctx PolicyContext
	---@param resourceType ResourceType
	---@return ResourcePolicyResult
	local function calcResourcePolicyResult(ctx, resourceType)
		local resource = {
			cumulativeSent = getCumulativeSent(ctx.senderTeamId, resourceType, ctx.repositories.springRepo) or 0,
			threshold = getThreshold(resourceType)
		}
		if resourceType == SharedEnums.ResourceType.METAL then
			resource.sender_current = ctx.sender.metal.current
			resource.sender_storage = ctx.sender.metal.storage
			resource.receiver_current = ctx.receiver.metal.current
			resource.receiver_storage = ctx.receiver.metal.storage
		elseif resourceType == SharedEnums.ResourceType.ENERGY then
			resource.sender_current = ctx.sender.energy.current
			resource.sender_storage = ctx.sender.energy.storage
			resource.receiver_current = ctx.receiver.energy.current
			resource.receiver_storage = ctx.receiver.energy.storage
		end

		local receiverCapacity = resource.receiver_storage - resource.receiver_current

		local amountSendable = receiverCapacity
		local amountReceivable = receiverCapacity

		-- Calculate tax-free allowance remaining (considering cumulative sent)
		local allowanceRemaining = math.max(0, resource.threshold - resource.cumulativeSent)

		-- Calculate portions for transfer logic
		local senderBudget = resource.sender_current
		local untaxedPortion = math.min(allowanceRemaining, receiverCapacity, senderBudget)
		local taxedPortion = math.max(0, receiverCapacity - untaxedPortion)

		---@type ResourcePolicyResult
		return {
			canShare = amountSendable > 0,
			amountSendable = amountSendable,
			amountReceivable = amountReceivable,
			taxedPortion = taxedPortion,
			untaxedPortion = untaxedPortion,
			taxRate = taxRate,
			resourceType = resourceType,
			remainingTaxFreeAllowance = allowanceRemaining
		}
	end
	return calcResourcePolicyResult
end

---@param builder DSL
local function buildPolicy(builder)
	local taxRate = tonumber(builder.mod_options[ModOptions.Options.TaxResourceSharingAmount]) or 0

	local metalThreshold = tonumber(builder.mod_options[ModOptions.Options.PlayerMetalSendThreshold]) or 0
	local energyThreshold = tonumber(builder.mod_options[ModOptions.Options.PlayerEnergySendThreshold]) or 0

	local calcResourcePolicyResult = buildResultFactory(taxRate, metalThreshold, energyThreshold)

	builder:Allied():MetalTransfers():Use(function(ctx)
		return calcResourcePolicyResult(ctx, SharedEnums.ResourceType.METAL)
	end)

	builder:Allied():EnergyTransfers():Use(function(ctx)
		return calcResourcePolicyResult(ctx, SharedEnums.ResourceType.ENERGY)
	end)

	builder:RegisterPostMetalTransfer(function(transferResult, springRepo)
		local cumMetal = getCumulativeParam(SharedEnums.ResourceType.METAL)
		local current = tonumber(springRepo:GetTeamRulesParam(transferResult.senderTeamId, cumMetal)) or 0
		springRepo:SetTeamRulesParam(transferResult.senderTeamId, cumMetal, current + transferResult.sent)
	end)

	builder:RegisterPostEnergyTransfer(function(transferResult, springRepo)
		local cumEnergy = getCumulativeParam(SharedEnums.ResourceType.ENERGY)
		local current = tonumber(springRepo:GetTeamRulesParam(transferResult.senderTeamId, cumEnergy)) or 0
		springRepo:SetTeamRulesParam(transferResult.senderTeamId, cumEnergy, current + transferResult.sent)
	end)
end

---@type PolicyModule
local module = {
    name = SharedEnums.Policies.TaxResourceSharing,
    func = buildPolicy,
    enabled = function(ctx)
        local modOptions = ctx.repositories.springRepo:GetModOptions()
        return modOptions[ModOptions.Options.TaxResourceSharingAmount] ~= nil
    end
}
return module

return Tax


