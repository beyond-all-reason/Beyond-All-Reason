local quickStartAmountConfig = {
	small = 800,
	normal = 1200,
	large = 2400,
}

function skip()
	local modOptions = Spring.GetModOptions() or {}
	return modOptions.quick_start ~= "enabled"
end

function test()
	local modOptions = Spring.GetModOptions() or {}
	local override = tonumber(modOptions.override_quick_start_resources) or 0
	local amount = modOptions.quick_start_amount
	if amount == nil or amount == "default" then
		amount = "normal"
	end

	local expectedBudget = override > 0 and override or quickStartAmountConfig[amount]
	assert(expectedBudget ~= nil, "Unexpected quick_start_amount value: " .. tostring(amount))

	local budgetParam = Spring.GetGameRulesParam("quickStartBudgetBase")

	assert(
		budgetParam == expectedBudget,
		string.format(
			"quickStartBudgetBase mismatch: got %s, expected %s (override=%s amount=%s)",
			tostring(budgetParam),
			tostring(expectedBudget),
			tostring(override),
			tostring(amount)
		)
	)
end