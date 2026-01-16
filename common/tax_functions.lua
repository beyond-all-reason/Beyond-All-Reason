local taxFunctions = {}

function taxModoptionIsEnabled()
	return  Spring.GetModOptions().tax_resource_sharing_amount > 0 or Spring.GetModOptions().easytax or false
end

function taxModoptionRatio()
	-- strictly speaking it is not a percentage from 0% to 100%, but a 0.0 to 1.0 float
	local sharingTax = tonumber(Spring.GetModOptions().tax_resource_sharing_amount) or 0
	if Spring.GetModOptions().easytax then
		sharingTax = 0.3 -- 30% tax for easytax modoption
	end
	return sharingTax
end

return taxFunctions