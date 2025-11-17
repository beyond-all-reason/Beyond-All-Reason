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
-- thanks to Damgam for writing No RushMode, from which I borrowed wholesale

local CommandsToCatchMap = {                                -- CMDTYPES: ICON_MAP, ICON_AREA, ICON_UNIT_OR_MAP, ICON_UNIT_OR_AREA, ICON_UNIT_FEATURE_OR_AREA, ICON_BUILDING
	[CMD.MOVE] = true,
	[CMD.PATROL] = true,
	[CMD.FIGHT] = true,
	[CMD.ATTACK] = true,
	[CMD.AREA_ATTACK] = true,
	[CMD.REPAIR] = true,
	[CMD.LOAD_UNITS] = true,
	[CMD.UNLOAD_UNITS] = true,
	[CMD.UNLOAD_UNIT] = true,
	[CMD.RECLAIM] = true,
	[CMD.DGUN] = true,
	[CMD.RESTORE] = true,
	[CMD.RESURRECT] = true,
	[CMD.CAPTURE] = true,
	[34923] = true, -- Set Target
}

local CommandsToCatchUnit = { -- CMDTYPES: ICON_UNIT, ICON_UNIT_OR_MAP, ICON_UNIT_OR_AREA
	[CMD.ATTACK] = true,
	[CMD.GUARD] = true,
	[CMD.REPAIR] = true,
	[CMD.LOAD_UNITS] = true,
	[CMD.LOAD_ONTO] = true,
	[CMD.UNLOAD_UNITS] = true,
	[CMD.RECLAIM] = true,
	[CMD.DGUN] = true,
	[CMD.CAPTURE] = true,
	[34923] = true, -- Set Target
}

local CommandsToCatchFeature = { -- CMDTYPES: ICON_UNIT_FEATURE_OR_AREA
	[CMD.RECLAIM] = true,
	[CMD.RESURRECT] = true,
}

local CommandsToClearQueue = { -- CMDTYPES: ICON_UNIT_FEATURE_OR_AREA
	[CMD.STOP] = true
}


--return early if not enabled 
-- TODO possibly should actually do gadget-removal if not enabled...
if (Spring.GetModOptions().stun_unit_after_sharing == "off" or tonumber(Spring.GetModOptions().stun_units_after_transfer_duration_seconds) <= 0) then 
    return true
end


if not gadgetHandler:IsSyncedCode() then
	return false
end


function gadget:Initialize()
	Spring.Echo("stun unit gadget initialized")
    gadgetHandler:RegisterAllowCommand(CMD.BUILD)

		local registered = { [CMD.BUILD] = true }

		for _, commandList in ipairs { CommandsToCatchMap, CommandsToCatchUnit, CommandsToCatchFeature } do
			for command in pairs(commandList) do
				if not registered[command] then
					gadgetHandler:RegisterAllowCommand(command)
					registered[command] = true
				end
			end
		end
end	

-- TODO place affected units in the below list, removing units after their stun expires
-- in theory we can use this list in the widget to show some sort of stun-bar / transfer bar over the unit.
-- TODO see if luaui/Widgets/gui_healthbars_gl4.lua has modes that align with expiryFrame or seconds-until-complete
-- e.g. "-- bit 3: use timeleft style display 
local DEBUG = true
local stunnedUnitReleaseFrameTable = {} -- key unitID, value is the future gameFrame that the unit will be released
local stunGadgetEnabled = true
--(Spring.GetModOptions().stun_unit_after_sharing ~= "off" and tonumber(Spring.GetModOptions().stun_units_after_transfer_duration_seconds) > 0)

-- intercepts unit transfer and forces the injection of a wait command for a certain time
function gadget:AllowUnitTransfer(unitID, _, _, _, wasCaptured)    
    if (not stunGadgetEnabled) then 
        return true
    end 
    -- early return captured units as they are not affected
    if (wasCaptured) then 
      return true
    end

    local currentGameFrame = Spring.GetGameFrame()
    -- separates internal name from global modoption namespace
    local stun_unit_after_sharing  = Spring.GetModOptions().stun_unit_after_sharing
    local stun_units_after_transfer_duration_seconds_int = tonumber(Spring.GetModOptions().stun_units_after_transfer_duration_seconds) or 0


    --TODO rip through the list and remove entries that are in the past (simple garbage collect)

    Spring.Echo("sharing debug: " .. tostring(DEBUG))

    if DEBUG then
        Spring.Echo("stun_unit_after_sharing: " .. tostring(stun_unit_after_sharing))
        Spring.Echo("stun_units_after_transfer_duration_seconds: " .. tostring(stun_units_after_transfer_duration_seconds_int))
    end
    -- allow the unit to transfer, but stun the unit as the transfer happens
	local inputStunSeconds = math.floor(tonumber(stun_units_after_transfer_duration_seconds_int))
    local gameFrameThatUnitWillBeAvailable = currentGameFrame + (inputStunSeconds * Game.gameSpeed);
    if DEBUG then
        Spring.Echo("stun_frame: " .. tostring(currentGameFrame) .. " available at:" .. tostring(gameFrameThatUnitWillBeAvailable))
    end

    -- TODO switch to a mode that won't clear the queue 
    --Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)

    --Spring.GiveOrderToUnit(unitID, CMD.TIMEWAIT, {inputStunSeconds}, 0)


    if DEBUG then 
     local beforeQ = Spring.GetCommandQueue(unitID, -1)
     Spring.Echo("beforeQ:")
     Spring.Echo(beforeQ)
   end
    Spring.GiveOrderToUnit(unitID,
     CMD.INSERT,
     {0,CMD.TIMEWAIT,CMD.OPT_SHIFT,inputStunSeconds}
   );
   if DEBUG then 
     local newQueue = Spring.GetCommandQueue(unitID, -1)
     Spring.Echo("afterQ:")
     Spring.Echo(newQueue)
   end
    stunnedUnitReleaseFrameTable[unitID] = gameFrameThatUnitWillBeAvailable
 

    return true
end

-- TODO switch phrasing to "stun eco" vs "stun movement" vs "both" or something like that

-- if the unit is stunned due to sharing, no commands can be issued for some number of GameFrames
-- taken from luarules/gadgets/game_no_rush_mode.lua , so in theory this could be refactored to share some useful functions around command parameter handling
function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
    -- not entirely sure I understand how gadget enablement works, so for now we're just returning early if we suspect we might be off
    if (not stunGadgetEnabled) then 
        return true
    end
 

    if DEBUG then
        Spring.Echo("stun_share AllowCommand unitID: " .. tostring(unitID) .. "release_val:".. tostring(stunnedUnitReleaseFrameTable[unitID]) )
        Spring.Echo("niltbl? " .. tostring(stunnedUnitReleaseFrameTable[unitID]==nil) )
    end

    -- early return if unit is not in stunnedUnitReleaseFrameTable at all
    if stunnedUnitReleaseFrameTable[unitID] == nil then
        
        return true
    end

    local currentFrame = Spring.GetGameFrame()
    local releaseFrame = stunnedUnitReleaseFrameTable[unitID]

    if DEBUG then
        Spring.Echo("stun_share AllowCommand cur: " .. tostring(currentFrame) .. " release: " .. tostring(releaseFrame))
    end

    if currentFrame >= releaseFrame then 
        return true
    end

    local allowed = false

    local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(unitTeam)
    if cmdID == CMD.INSERT then
        -- CMD.INSERT wraps another command, so we need to extract it
        cmdID = cmdParams[2]
        -- Area commands have an extra radius parameter, so they shift by 4 instead of 3
        local paramCountToShift = #cmdParams - 3
        -- Shift the parameters to remove the CMD.INSERT wrapper and match normal command format
        for i = 1, paramCountToShift do
        cmdParams[i] = cmdParams[i + 3]
        end
        -- Clear any unused parameters after the shift
        for i = paramCountToShift + 1, #cmdParams do
        cmdParams[i] = nil
        end
    end
    if cmdID < 0 then
        if cmdParams[1] and cmdParams[2] and cmdParams[3] then
            allowed = false
        end
    elseif CommandsToCatchMap[cmdID] and #cmdParams >= 3 then
        allowed = false
    elseif CommandsToCatchUnit[cmdID] and #cmdParams == 1 then
        allowed = false
    elseif CommandsToCatchFeature[cmdID] and #cmdParams == 1 then
        allowed = false
    elseif CommandsToClearQueue[cmdID] then 
        allowed = false
    end

    return allowed
    
end