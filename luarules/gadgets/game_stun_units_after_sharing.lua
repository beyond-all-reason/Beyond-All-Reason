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
-- Thanks to  Chronopolize, Hobo Joe, Chronographer,  Seth dGamre, and sprunk for providing suggestions

if not gadgetHandler:IsSyncedCode() then
	return false
end

--return early if not enabled
if (Spring.GetModOption().stun_unit_after_sharing == "off" or stun_units_after_transfer_duration_seconds <= 0) then 
    return true
end

local spGetUnitHealth = Spring.GetUnitHealth
local spSetUnitHealth = Spring.SetUnitHealth
local currentGameFrame = Spring.GetGameFrame()

local transferedStunnedList = {}

function gadget:AllowUnitTransfer(unitID, _, _, _, _)
    Spring.Echo("stun_unit_after_sharing: " .. tostring(Spring.GetModOptions().stun_unit_after_sharing))
    Spring.Echo("stun_units_after_transfer_duration_seconds: " .. tostring(Spring.GetModOptions().stun_units_after_transfer_duration_seconds))
    -- allow the unit to transfer, but stun the unit as the transfer happens
	local inputStunSeconds = Spring.GetModOptions().stun_units_after_transfer_duration_seconds
    -- that is, we're going to store the unit id with the future game frame that the unit will become available
    local gameFrameThatUnitWillBeAvailable = currentGameFrame + (inputStunSeconds * Game.gameSpeed);

    return true
end
