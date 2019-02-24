function widget:GetInfo()
    return {
        name = "Attack and Move Notification",
        desc = "v0.31 Notifes when a unit is attacked or a move command failed",
        author = "knorke & very_bad_soldier",
        date = "Dec , 2011",
        license = "GPLv2",
        layer = 0,
        enabled = true
    }
end
----------------------------------------------------------------------------
local alarmInterval                 = 15        --seconds
----------------------------------------------------------------------------                
local spGetLocalTeamID              = Spring.GetLocalTeamID
local spPlaySoundFile               = Spring.PlaySoundFile
local spEcho                        = Spring.Echo
local spGetTimer                    = Spring.GetTimer
local spDiffTimers                  = Spring.DiffTimers
local spIsUnitInView                = Spring.IsUnitInView
local spGetUnitPosition             = Spring.GetUnitPosition
local spSetLastMessagePosition      = Spring.SetLastMessagePosition
local random                        = math.random
----------------------------------------------------------------------------
local lastAlarmTime                 = nil
local lastCommanderAlarmTime        = nil
local localTeamID                   = nil
----------------------------------------------------------------------------

local commanders = {}
for unitDefID,defs in pairs(UnitDefs) do
    if defs and defs.customParams and defs.customParams.iscommander then
        commanders[defs.id] = true
    end
end


function widget:PlayerChanged(playerID)
    if Spring.GetSpectatingState() then
        widgetHandler:RemoveWidget(self)
    end
    localTeamID = spGetLocalTeamID()
end

function widget:GameStart()
    widget:PlayerChanged()
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        widget:PlayerChanged()
    end
    localTeamID = spGetLocalTeamID()
    lastAlarmTime = spGetTimer()
	lastCommanderAlarmTime =  spGetTimer()
    math.randomseed( os.time() )
end

function widget:UnitDamaged (unitID, unitDefID, unitTeam, damage, paralyzer)
    if ( localTeamID ~= unitTeam )then
		return
	end
	--Spring.Echo(corcomID, unitID)
	local now = spGetTimer()
    if (commanders[unitDefID]) then --commander under attack must always be played! (10 sec retrigger alert though)
		--Spring.Echo("Commander under attack!")
		if ( spDiffTimers( now, lastCommanderAlarmTime ) < alarmInterval ) then
			return
		end
		lastCommanderAlarmTime=now
	else
		if (spIsUnitInView(unitID)) then
			return --ignore other teams and units in view
		end
		if ( spDiffTimers( now, lastAlarmTime ) < alarmInterval ) then
			return
		end
	end
    lastAlarmTime = now
    
    local udef = UnitDefs[unitDefID]
    local x,y,z = spGetUnitPosition(unitID)

    spEcho("-> " .. udef.humanName  .." is being attacked!") --print notification
    
    if ( udef.sounds.underattack and (#udef.sounds.underattack > 0) ) then
        id = random(1, #udef.sounds.underattack) --pick a sound from the table by random --(id 138, name warning2, volume 1)
            
        soundFile = udef.sounds.underattack[id].name
        --if not udef.decoyfor or (udef.decoyfor ~= 'armcom' and udef.decoyfor ~= 'corcom') then
            spPlaySoundFile( soundFile, udef.sounds.underattack[id].volume, nil, "sfx" )
        --end
    end
        
    if (x and y and z) then spSetLastMessagePosition(x,y,z) end
end

function widget:UnitMoveFailed(unitID, unitDefID, unitTeam)
    local udef = UnitDefs[unitDefID]
    spEcho( udef.humanName  .. ": Can't reach destination!" )
end