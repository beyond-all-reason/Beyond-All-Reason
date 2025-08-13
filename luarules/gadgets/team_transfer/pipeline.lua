-- Transform pipeline system for team transfers

local Pipeline = {}

-- State for transform policies
local state = {
    unitTransformPolicies = {},
    resourceTransformPolicies = {},
}

-- Register resource transform policy
Pipeline.RegisterResourceTransformPolicy = function(name, priority, transformFunc)
    state.resourceTransformPolicies[name] = {
        priority = priority,
        transform = transformFunc
    }
    
    local sorted = {}
    for policyName, policy in pairs(state.resourceTransformPolicies) do
        table.insert(sorted, {name = policyName, priority = policy.priority, transform = policy.transform})
    end
    table.sort(sorted, function(a, b) return a.priority < b.priority end)
    state.resourceTransformPolicies._sorted = sorted
    
    Spring.Log("TeamTransfer", LOG.INFO, "Registered resource transform policy: " .. name .. " (priority: " .. priority .. ")")
end

-- Register unit transform policy
Pipeline.RegisterUnitTransformPolicy = function(name, priority, transformFunc)
    state.unitTransformPolicies[name] = {
        priority = priority,
        transform = transformFunc
    }
    
    local sorted = {}
    for policyName, policy in pairs(state.unitTransformPolicies) do
        table.insert(sorted, {name = policyName, priority = policy.priority, transform = policy.transform})
    end
    table.sort(sorted, function(a, b) return a.priority < b.priority end)
    state.unitTransformPolicies._sorted = sorted
    
    Spring.Log("TeamTransfer", LOG.INFO, "Registered unit transform policy: " .. name .. " (priority: " .. priority .. ")")
end

-- Run resource transform pipeline
Pipeline.RunResourceTransformPipeline = function(transfer)
    local sortedPolicies = state.resourceTransformPolicies._sorted or {}
    
    for _, policy in ipairs(sortedPolicies) do
        if transfer.blocked then break end
        
        local originalTransfer = {}
        for k, v in pairs(transfer) do originalTransfer[k] = v end
        
        transfer = policy.transform(transfer)
        
        if transfer.blocked and not originalTransfer.blocked then
            Spring.Log("TeamTransfer", LOG.INFO, "Transfer blocked by policy: " .. policy.name)
        elseif transfer.finalAmount and transfer.finalAmount ~= originalTransfer.finalAmount then
            Spring.Log("TeamTransfer", LOG.DEBUG, 
                string.format("Policy %s modified amount: %.1f -> %.1f", 
                    policy.name, originalTransfer.finalAmount or originalTransfer.amount, transfer.finalAmount))
        end
    end
    
    return transfer
end

-- Run unit transform pipeline
Pipeline.RunUnitTransformPipeline = function(transfer)
    local sortedPolicies = state.unitTransformPolicies._sorted or {}
    
    for _, policy in ipairs(sortedPolicies) do
        if transfer.blocked then break end
        
        transfer = policy.transform(transfer)
        
        if transfer.blocked then
            Spring.Log("TeamTransfer", LOG.INFO, "Unit transfer blocked by policy: " .. policy.name)
            break
        end
    end
    
    return transfer
end

return Pipeline
