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

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local currentGameFrame = Spring.GetGameFrame()

-- TODO place affected units in this list, removing units after their stun expires
-- in theory we can use this list in the widget to show some sort of stun-bar / transfer bar over the unit.
-- TODO see if luaui/Widgets/gui_healthbars_gl4.lua has modes that align with expiryFrame or seconds-until-complete
-- e.g. "-- bit 3: use timeleft style display 

local transferedStunnedList = {}

function gadget:AllowUnitTransfer(unitID, _, _, _, wasCaptured)
    -- early return captured units as they are not affected
    if (wasCaptured) then 
      return true
    end

    Spring.Echo("stun_unit_after_sharing: " .. tostring(Spring.GetModOptions().stun_unit_after_sharing))
    Spring.Echo("stun_units_after_transfer_duration_seconds: " .. tostring(Spring.GetModOptions().stun_units_after_transfer_duration_seconds))
    -- allow the unit to transfer, but stun the unit as the transfer happens
	local inputStunSeconds = math.floor(tonumber(Spring.GetModOptions().stun_units_after_transfer_duration_seconds))
    local gameFrameThatUnitWillBeAvailable = currentGameFrame + (inputStunSeconds * Game.gameSpeed);
    spGiveOrderToUnit(unitID, CMD.TIMEWAIT, {}, inputStunSeconds)

    return true
end
