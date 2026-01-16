local function sharingTaxIsEnabled()
	return  Spring.GetModOptions().tax_resource_sharing_amount > 0 or Spring.GetModOptions().easytax or false
end

-- currently unused. left separately in case easytax or other anti-coop solutions wish for separate reclaim tax
local function reclaimTaxIsEnabled()
	return false
end

local function sharingTaxRatio()
	-- strictly speaking it is not a percentage from 0% to 100%, but a 0.0 to 1.0 float
	local sharingTax = tonumber(Spring.GetModOptions().tax_resource_sharing_amount) or 0
	if Spring.GetModOptions().easytax then
		sharingTax = 0.3 -- 30% tax for easytax modoption
	end
	return sharingTax
end

local function reclaimTaxRatio()
	-- strictly speaking it is not a percentage from 0% to 100%, but a 0.0 to 1.0 float
	-- deliberately set to zero-tax as currently no anti-coop solutions wish for a reclaim tax
	local reclaimTax = 0
	return reclaimTax
end

local taxFunctions = {
	sharingTaxIsEnabled = sharingTaxIsEnabled,
	sharingTaxRatio = sharingTaxRatio,
	reclaimTaxIsEnabled = reclaimTaxIsEnabled,
	reclaimTaxRatio = reclaimTaxRatio
}
return taxFunctions