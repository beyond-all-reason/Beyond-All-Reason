-- Mod Option: Allied Construction Assist
-- Enabled (Default) - Full construction assistance
-- Economic Only - Only eco building help  
-- Disabled - No allied construction
-- TODO: Command validator for GUARD/BUILD commands

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "mod_allied_construction_assist",
        desc      = "Allied construction assistance policy",
        author    = "TBD",
        date      = "2024",
        license   = "GNU GPL, v2 or later", 
        layer     = 2,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

-- Mod Options (read at gadget load time)
local alliedConstructionPolicy = Spring.GetModOptions().allied_construction_assist or "enabled"

-- Early exit if fully enabled (no restrictions needed)
if alliedConstructionPolicy == "enabled" then
    return false
end

-- Building categorization helpers
local function IsEconomicBuilding(unitDefID)
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return false end
    
    -- Check for economic buildings (energy, metal, storage)
    if unitDef.energyMake and unitDef.energyMake > 0 then return true end
    if unitDef.makesMetal and unitDef.makesMetal > 0 then return true end
    if unitDef.energyStorage and unitDef.energyStorage > 0 then return true end
    if unitDef.metalStorage and unitDef.metalStorage > 0 then return true end
    
    -- Check category tags
    local categories = unitDef.category or ""
    if categories:find("ENERGY") or categories:find("METAL") or categories:find("STORAGE") then
        return true
    end
    
    return false
end

local function IsMilitaryBuilding(unitDefID)
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return false end
    
    -- Check for weapons or military categories  
    if unitDef.weapons and #unitDef.weapons > 0 then return true end
    
    local categories = unitDef.category or ""
    if categories:find("WEAPON") or categories:find("DEFENSE") or categories:find("TURRET") then
        return true
    end
    
    return false
end

-- Command validation function
function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
    -- Only check GUARD and BUILD commands to allied teams
    if cmdID ~= CMD.GUARD and cmdID ~= CMD.BUILD then
        return true
    end
    
    local targetTeam
    local targetUnitDefID
    
    if cmdID == CMD.GUARD and #cmdParams >= 1 then
        local targetID = cmdParams[1]
        if targetID >= Game.maxUnits then return true end
        
        targetTeam = Spring.GetUnitTeam(targetID)
        targetUnitDefID = Spring.GetUnitDefID(targetID)
    elseif cmdID == CMD.BUILD and #cmdParams >= 1 then
        targetUnitDefID = -cmdParams[1] -- Build commands have negative unit def IDs
        -- For build commands, we need to determine the target team differently
        -- This is more complex and might need additional context
        return true -- TODO: Implement proper build command team detection
    else
        return true
    end
    
    -- Only restrict commands to allied teams (not same team)
    if not targetTeam or unitTeam == targetTeam or not Spring.AreTeamsAllied(unitTeam, targetTeam) then
        return true
    end
    
    -- Apply policy restrictions
    if alliedConstructionPolicy == "disabled" then
        return false
    elseif alliedConstructionPolicy == "economic_only" then
        -- Allow economic buildings, block military
        if targetUnitDefID and IsMilitaryBuilding(targetUnitDefID) then
            return false
        end
    end
    
    return true
end

-- Implementation: Log policy status
function gadget:Initialize()
    Spring.Log("TeamTransfer", LOG.INFO, "Allied construction policy: " .. alliedConstructionPolicy)
    
    if alliedConstructionPolicy == "disabled" then
        Spring.Log("TeamTransfer", LOG.INFO, "All allied construction assistance blocked")
    elseif alliedConstructionPolicy == "economic_only" then
        Spring.Log("TeamTransfer", LOG.INFO, "Allied construction limited to economic buildings only")
    end
end
