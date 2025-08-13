local gadget = gadget

function gadget:GetInfo()
    return {
        name      = "Reclaim Income Handler",
        desc      = "Handles reclaim income processing and taxation",
        author    = "TeamTransfer System",
        date      = "2024",
        license   = "GNU GPL, v2 or later",
        layer     = -1,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local ReclaimIncome = VFS.Include("luarules/modules/command_pipeline.lua")

function gadget:RecvLuaMsg(msg, playerID)
    if msg:sub(1, 19) == "SyncedActionFallback:" then
        local actionName = msg:sub(20)
        if actionName == "ProcessReclaimIncome" then
            local reclaimingTeam = Spring.GetGameRulesParam("ReclaimIncomeData_reclaimingTeam")
            local sourceTeam = Spring.GetGameRulesParam("ReclaimIncomeData_sourceTeam")
            local resourceType = Spring.GetGameRulesParam("ReclaimIncomeData_resourceType")
            local amount = Spring.GetGameRulesParam("ReclaimIncomeData_amount")
            local sourceUnitDefID = Spring.GetGameRulesParam("ReclaimIncomeData_sourceUnitDefID")
            local sourceFeatureDefID = Spring.GetGameRulesParam("ReclaimIncomeData_sourceFeatureDefID")
            
            local result = ReclaimIncome.ProcessReclaimIncome(reclaimingTeam, sourceTeam, resourceType, amount, sourceUnitDefID, sourceFeatureDefID)
            
            Spring.SetGameRulesParam("ReclaimIncomeResult_finalAmount", result.finalAmount)
            Spring.SetGameRulesParam("ReclaimIncomeResult_taxAmount", result.taxAmount)
            Spring.SetGameRulesParam("ReclaimIncomeResult_blocked", result.blocked and 1 or 0)
            
            return true
        end
    end
    return false
end

function gadget:Initialize()
    GG.ReclaimIncome = ReclaimIncome
    
    Spring.Log("ReclaimIncome", LOG.INFO, "Reclaim income handler initialized")
end
