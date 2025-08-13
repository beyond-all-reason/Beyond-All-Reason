-- Mod Option: Allied Construction Assist
-- Enabled (Default) - Full construction assistance and reclaim allowed
-- Economic Only - Only eco building help, reclaim restricted
-- Disabled - No allied construction or reclaim

local gadget = gadget

function gadget:GetInfo()
    return {
        name      = "mod_allied_assist",
        desc      = "Allied construction assistance and reclaim policy",
        author    = "TeamTransfer System",
        date      = "2024",
        license   = "GNU GPL, v2 or later", 
        layer     = 2,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local alliedAssistPolicy = Spring.GetModOptions().allied_construction_assist or "enabled"

if alliedAssistPolicy == "enabled" then
    return false
end

local function IsEconomicBuilding(unitDefID)
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return false end
    
    if unitDef.energyMake and unitDef.energyMake > 0 then return true end
    if unitDef.makesMetal and unitDef.makesMetal > 0 then return true end
    if unitDef.energyStorage and unitDef.energyStorage > 0 then return true end
    if unitDef.metalStorage and unitDef.metalStorage > 0 then return true end
    
    local categories = unitDef.category or ""
    if categories:find("ENERGY") or categories:find("METAL") or categories:find("STORAGE") then
        return true
    end
    
    return false
end

local function IsMilitaryBuilding(unitDefID)
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return false end
    
    if unitDef.weapons and #unitDef.weapons > 0 then return true end
    
    local categories = unitDef.category or ""
    if categories:find("WEAPON") or categories:find("DEFENSE") or categories:find("TURRET") then
        return true
    end
    
    return false
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
    if (cmdID == CMD.RECLAIM and #cmdParams >= 1) then
        local targetID = cmdParams[1]
        if targetID >= Game.maxUnits then
            return true
        end
        
        local targetTeam = Spring.GetUnitTeam(targetID)
        if unitTeam ~= targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam) then
            if alliedAssistPolicy == "disabled" then
                return false
            elseif alliedAssistPolicy == "economic_only" then
                return true
            end
        end
    elseif (cmdID == CMD.GUARD and #cmdParams >= 1) then
        local targetID = cmdParams[1]
        local targetTeam = Spring.GetUnitTeam(targetID)
        local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]

        if (unitTeam ~= targetTeam) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
            if alliedAssistPolicy == "disabled" then
                return false
            elseif alliedAssistPolicy == "economic_only" then
                if targetUnitDef and targetUnitDef.canReclaim then
                    return false
                end
            end
        end
    elseif cmdID == CMD.BUILD and #cmdParams >= 1 then
        local targetUnitDefID = -cmdParams[1]
        
        if alliedAssistPolicy == "disabled" then
            return false
        elseif alliedAssistPolicy == "economic_only" then
            if targetUnitDefID and IsMilitaryBuilding(targetUnitDefID) then
                return false
            end
        end
    end
    return true
end

function gadget:Initialize()
    gadgetHandler:RegisterAllowCommand(CMD.RECLAIM)
    gadgetHandler:RegisterAllowCommand(CMD.GUARD)
    gadgetHandler:RegisterAllowCommand(CMD.BUILD)
    
    Spring.Log("TeamTransfer", LOG.INFO, "Allied assist policy: " .. alliedAssistPolicy)
    
    if alliedAssistPolicy == "disabled" then
        Spring.Log("TeamTransfer", LOG.INFO, "All allied assistance (construction and reclaim) blocked")
    elseif alliedAssistPolicy == "economic_only" then
        Spring.Log("TeamTransfer", LOG.INFO, "Allied assistance limited to economic buildings, reclaim allowed")
    end
end
