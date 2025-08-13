local ReclaimIncome = {}

local state = {
    incomeValidators = {},
    incomeTransformPolicies = {},
    incomeListeners = {},
}

ReclaimIncome.RegisterIncomeValidator = function(name, validatorFunc)
    state.incomeValidators[name] = validatorFunc
end

ReclaimIncome.RegisterIncomeTransformPolicy = function(name, priority, transformFunc)
    state.incomeTransformPolicies[name] = {
        priority = priority,
        transform = transformFunc
    }
    
    local sorted = {}
    for policyName, policy in pairs(state.incomeTransformPolicies) do
        table.insert(sorted, {name = policyName, priority = policy.priority, transform = policy.transform})
    end
    table.sort(sorted, function(a, b) return a.priority < b.priority end)
    state.incomeTransformPolicies._sorted = sorted
    
    Spring.Log("ReclaimIncome", LOG.INFO, "Registered income transform policy: " .. name .. " (priority: " .. priority .. ")")
end

ReclaimIncome.RegisterIncomeListener = function(name, listenerFunc)
    state.incomeListeners[name] = listenerFunc
end

ReclaimIncome.ProcessReclaimIncome = function(reclaimingTeam, sourceTeam, resourceType, amount, sourceUnitDefID, sourceFeatureDefID)
    local income = {
        reclaimingTeam = reclaimingTeam,
        sourceTeam = sourceTeam,
        resourceType = resourceType,
        amount = amount,
        sourceUnitDefID = sourceUnitDefID,
        sourceFeatureDefID = sourceFeatureDefID,
        blocked = false,
        finalAmount = amount,
        taxAmount = 0,
    }
    
    for name, validator in pairs(state.incomeValidators) do
        if not validator(income) then
            income.blocked = true
            income.blockedBy = name
            break
        end
    end
    
    local sortedPolicies = state.incomeTransformPolicies._sorted or {}
    for _, policy in ipairs(sortedPolicies) do
        if income.blocked then break end
        
        income = policy.transform(income)
        
        if income.blocked then
            Spring.Log("ReclaimIncome", LOG.INFO, "Income blocked by policy: " .. policy.name)
            break
        end
    end
    
    for _, listener in pairs(state.incomeListeners) do
        listener(income)
    end
    
    return income
end

return ReclaimIncome
