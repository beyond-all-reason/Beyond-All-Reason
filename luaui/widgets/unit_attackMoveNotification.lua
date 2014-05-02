function widget:GetInfo()
    return {
        name = "Attack and Move Notification",
        desc = "v0.31 Notifes when a unit is attacked or a move command failed",
        author = "knorke & very_bad_soldier",
        date = "Dec , 2011",
        license = "GPLv2",
        layer = 1,
        enabled = true
    }
end
----------------------------------------------------------------------------
local alarmInterval                 = 15        --seconds
local commanderAlarmInterval		= 10
----------------------------------------------------------------------------                
local spGetLocalTeamID              = Spring.GetLocalTeamID
local spPlaySoundFile               = Spring.PlaySoundFile
local spEcho                        = Spring.Echo
local spGetTimer                    = Spring.GetTimer
local spDiffTimers                  = Spring.DiffTimers
local spIsUnitInView                = Spring.IsUnitInView
local spGetUnitPosition             = Spring.GetUnitPosition
local spSetLastMessagePosition      = Spring.SetLastMessagePosition
local spGetSpectatingState   		= Spring.GetSpectatingState
local random                        = math.random
----------------------------------------------------------------------------
local lastAlarmTime                 = nil
local lastCommanderAlarmTime        = nil
local localTeamID                   = nil
----------------------------------------------------------------------------
local armcomID=UnitDefNames["armcom"].id
local corcomID=UnitDefNames["corcom"].id


function widget:Initialize()
    setTeamId()    
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
	if (unitDefID==corcomID or unitDefID==armcomID) then --commander under attack must always be played! (10 sec retrigger alert though)
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
        if ( string.find(soundFile, "%.") == nil ) then
            soundFile = soundFile .. ".wav" --append .wav if no extension is found
        end
            
        spPlaySoundFile( "sounds/" .. soundFile, udef.sounds.underattack[id].volume, nil, "ui" )
    end
        
    if (x and y and z) then spSetLastMessagePosition(x,y,z) end
end

function widget:UnitMoveFailed(unitID, unitDefID, unitTeam)
    local udef = UnitDefs[unitDefID]
    spEcho( udef.humanName  .. ": Can't reach destination!" )
end 

function setTeamId()
    localTeamID = spGetLocalTeamID()    
end

--changing teams, rejoin, becoming spec etc
function widget:PlayerChanged(playerID)
    setTeamId()
	CheckSpecState()
end


function CheckSpecState()
	if ( spGetSpectatingState() == true ) then
		widgetHandler:RemoveWidget()
		return false
	end
	
	return true	
end