
local gadget = gadget

function gadget:GetInfo()
    return {
        name      = "mod_reclaim_policy",
        desc      = "Reclaim policy for allied units and wrecks",
        author    = "TeamTransfer System",
        date      = "2024",
        license   = "GNU GPL, v2 or later", 
        layer     = 3,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local reclaimPolicy = Spring.GetModOptions().reclaim_policy or "enabled"

if reclaimPolicy == "enabled" then
    return false
end

function gadget:Initialize()
    Spring.Log("TeamTransfer", LOG.INFO, "Reclaim policy: " .. reclaimPolicy)
end
