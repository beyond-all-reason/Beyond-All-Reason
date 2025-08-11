local gadget = gadget ---@type Gadget
function gadget:GetInfo()
    return {
        name    = 'Stun shared units',
        desc    = 'Stun units when they are shared to another team.',
        author  = 'NortySpock',
        date    = 'August 2025',
        license = 'GNU GPL, v2 or later',
        layer   = 3,  -- the "Disable Unit Sharing" gadget has higher priority
        enabled = true
    }
end

-- Notes: Used paralyzeDamage because it was already there and easy to use. 
-- This could be expanded to instead use its own equivalent so as to allow for different UI representation of the unit-transfer mechanic

-- Thanks to  Chronopolize, Hobo Joe, Chronographer,  Seth dGamre, and sprunk for providing suggestions

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- return early if not enabled
-- if (Spring.GetModOption().stun_unit_after_sharing == "off" or stun_units_after_transfer_duration_seconds <= 0) then 
--     return true
-- end

local spGetUnitHealth = Spring.GetUnitHealth
local spSetUnitHealth = Spring.SetUnitHealth



function gadget:AllowUnitTransfer(unitID, _, _, _, _)
    Spring.Echo("stun_unit_after_sharing: " .. tostring(Spring.GetModOptions().stun_unit_after_sharing))
    Spring.Echo("stun_units_after_transfer_duration_seconds: " .. tostring(Spring.GetModOptions().stun_units_after_transfer_duration_seconds))
    -- allow the unit to transfer, but stun the unit as the transfer happens
	local inputStunSeconds = Spring.GetModOptions().stun_units_after_transfer_duration_seconds
    local health, maxHealth, paralyzeDamage, captureProgress = spGetUnitHealth(unitID)
	local transferParalyzeDamage = maxHealth * (1 + (inputStunSeconds / Game.paralyzeDeclineRate))

    --if the unit is already paralyzed more than the transfer stun, take the greater of the two
	local updatedParalyzeDamage = math.max(paralyzeDamage, transferParalyzeDamage)

	spSetUnitHealth(unitID, {paralyze = updatedParalyzeDamage})
    return true
end
