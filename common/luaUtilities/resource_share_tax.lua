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

return Tax


