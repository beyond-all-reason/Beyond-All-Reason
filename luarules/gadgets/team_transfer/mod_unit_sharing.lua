-- Mod Option: Unit Sharing Policy
-- Enabled (Default) - All unit transfers allowed
-- T2 Constructor Sharing Only - Only advanced builders shareable  
-- Disabled - No unit sharing allowed

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "mod_unit_sharing_policy",
        desc      = "Unit sharing restrictions based on mod options",
        author    = "Rimilel", 
        date      = "April 2024",
        license   = "GNU GPL, v2 or later",
        layer     = 1,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

-- Mod Options (read at gadget load time)
local unitSharingPolicy = Spring.GetModOptions().unit_sharing_policy or "enabled"
local isUnitSharingDisabled = Spring.GetModOptions().disable_unit_sharing == "true"

-- Early exit if unit sharing completely disabled
if isUnitSharingDisabled or unitSharingPolicy == "disabled" then
    function gadget:Initialize()
        GG.TeamTransfer.RegisterUnitValidator("UnitSharing_Disabled", function(unitID, unitDefID, oldTeam, newTeam, reason)
            -- Block all unit transfers
            return false
        end)
        Spring.Log("TeamTransfer", LOG.INFO, "Unit sharing: DISABLED")
    end
    return
end

-- Unit categorization helpers
local function IsT2Constructor(unitDefID)
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return false end
    
    -- Check if it's a builder and T2+ tech level
    if unitDef.isBuilder and unitDef.buildOptions then
        -- Simple heuristic: T2+ constructors typically have higher build power
        return unitDef.buildPower and unitDef.buildPower > 100
    end
    return false
end

-- Unit sharing validation function
local function ValidateUnitSharingPolicy(unitID, unitDefID, oldTeam, newTeam, reason)
    if unitSharingPolicy == "enabled" then
        return true -- Allow all transfers
    elseif unitSharingPolicy == "t2_constructor_only" then
        return IsT2Constructor(unitDefID)
    elseif unitSharingPolicy == "disabled" then
        return false -- Block all transfers
    end
    
    -- Default: allow transfer
    return true
end

-- Implementation: Register validator with TeamTransfer system
function gadget:Initialize()
    GG.TeamTransfer.RegisterUnitValidator("UnitSharing_Policy", ValidateUnitSharingPolicy)
    
    Spring.Log("TeamTransfer", LOG.INFO, "Unit sharing policy: " .. (unitSharingPolicy or "enabled"))
end
