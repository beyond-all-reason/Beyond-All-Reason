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
-- thanks to Damgam for writing No RushMode, from which I borrowed heavily



if not gadgetHandler:IsSyncedCode() then
	return false
end


function gadget:Initialize()
    --TODO remove 
	Spring.Echo("stun unit gadget initialized")
end

--return early if not enabled 
-- TODO possibly should actually do gadget-removal if not enabled...
if (Spring.GetModOptions().stun_unit_after_sharing == "off" or tonumber(Spring.GetModOptions().stun_units_after_transfer_duration_seconds) <= 0) then 
    return true
end


-- TODO place affected units in the below list, removing units after their stun expires
-- in theory we can use this list in the widget to show some sort of stun-bar / transfer bar over the unit.
-- TODO see if luaui/Widgets/gui_healthbars_gl4.lua has modes that align with expiryFrame or seconds-until-complete
-- e.g. "-- bit 3: use timeleft style display 
local DEBUG = true
local stunned_unit_release_frame = {} -- key unitID, value is the future gameFrame that the unit will be released

-- intercepts unit transfer and forces the injection of a wait command for a certain time
function gadget:AllowUnitTransfer(unitID, _, _, _, wasCaptured)
    -- early return captured units as they are not affected
    if (wasCaptured) then 
      return true
    end

    local currentGameFrame = Spring.GetGameFrame()
    -- separates internal name from global modoption namespace
    local stun_unit_after_sharing  = Spring.GetModOptions().stun_unit_after_sharing
    local stun_units_after_transfer_duration_seconds = Spring.GetModOptions().stun_units_after_transfer_duration_seconds


    --TODO rip through the list and remove entries that are in the past (simple garbage collect)

    Spring.Echo("sharing debug: " .. tostring(DEBUG))

    if DEBUG then
        Spring.Echo("stun_unit_after_sharing: " .. tostring(stun_unit_after_sharing))
        Spring.Echo("stun_units_after_transfer_duration_seconds: " .. tostring(stun_units_after_transfer_duration_seconds))
    end
    -- allow the unit to transfer, but stun the unit as the transfer happens
	local inputStunSeconds = math.floor(tonumber(stun_units_after_transfer_duration_seconds))
    local gameFrameThatUnitWillBeAvailable = currentGameFrame + (inputStunSeconds * Game.gameSpeed);
    if DEBUG then
        Spring.Echo("stun_frame: " .. tostring(currentGameFrame) .. " available at:" .. tostring(gameFrameThatUnitWillBeAvailable))
    end

    -- TODO switch to a mode that won't clear the queue 
    Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0) 
    stunned_unit_release_frame[unitID] = gameFrameThatUnitWillBeAvailable
 

    return true
end
