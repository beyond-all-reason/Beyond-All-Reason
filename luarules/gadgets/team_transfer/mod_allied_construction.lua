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


function gadget:Initialize()
    Spring.Log("TeamTransfer", LOG.INFO, "Allied construction policy: " .. alliedConstructionPolicy)
    
    if alliedConstructionPolicy == "disabled" then
        Spring.Log("TeamTransfer", LOG.INFO, "All allied construction assistance blocked")
    elseif alliedConstructionPolicy == "economic_only" then
        Spring.Log("TeamTransfer", LOG.INFO, "Allied construction limited to economic buildings only")
    end
end
