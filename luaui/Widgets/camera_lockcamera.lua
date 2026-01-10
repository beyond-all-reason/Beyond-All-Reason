local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name = "Lockcamera",
        desc = "replays other players camera views",
        author = "",
        date = "February 2025",
        version = 42,
        license = "GNU GPL, v2 or later",
        layer = -10,
        enabled = true,
    }
end


local lockcameraHideEnemies = true            -- specfullview
local lockcameraLos = true                    -- togglelos

local transitionTime = 1.3 -- how long it takes the camera to move when tracking a player
local listTime = 14 -- how long back to look for recent broadcasters

local totalTime = 0
local lastBroadcasts = {}
local recentBroadcasters = {}
local newBroadcaster = false

local desiredLosmodeChanged = 0
local desiredLosmode, myLastCameraState


local function UpdateRecentBroadcasters()
    recentBroadcasters = {}
    for playerID, info in pairs(lastBroadcasts) do
        local prevTime = info[1]
        if totalTime - prevTime <= listTime or playerID == lockPlayerID then
            if totalTime - prevTime <= listTime then
                recentBroadcasters[playerID] = totalTime - prevTime
            end
        end
    end
	WG.lockcamera.recentBroadcasters = recentBroadcasters
end

local function LockCamera(playerID)
    local isSpec, teamID
    if playerID then
        _, _, isSpec, teamID = Spring.GetPlayerInfo(playerID, false)
    end
    if playerID and playerID ~= myPlayerID and playerID ~= lockPlayerID and teamID then
        if lockcameraHideEnemies and not isSpec then
            Spring.SendCommands("specteam " .. teamID)
            if not fullView then
                scheduledSpecFullView = 1 -- this is needed else the minimap/world doesnt update properly
                Spring.SendCommands("specfullview")
            else
                scheduledSpecFullView = 2 -- this is needed else the minimap/world doesnt update properly
                Spring.SendCommands("specfullview")
            end
            if not isSpec and lockcameraLos and mySpecStatus then
                desiredLosmode = 'los'
                desiredLosmodeChanged = os.clock()
            end
        elseif lockcameraHideEnemies and isSpec then
            if not fullView then
                Spring.SendCommands("specfullview")
            end
            desiredLosmode = 'normal'
            desiredLosmodeChanged = os.clock()
        end
        lockPlayerID = playerID
        if not isSpec and lockcameraLos and mySpecStatus then
            desiredLosmode = 'los'
            desiredLosmodeChanged = os.clock()
        end
        myLastCameraState = myLastCameraState or Spring.GetCameraState()
        local info = lastBroadcasts[lockPlayerID]
        if info then
           Spring.SetCameraState(info[2], transitionTime)
        end

    else

        -- cancel camera tracking and restore own last known state
        if myLastCameraState then
            Spring.SetCameraState(myLastCameraState, transitionTime)
            myLastCameraState = nil
        end
        -- restore fullview if needed
        if lockcameraHideEnemies and lockPlayerID and not isSpec then
            if not fullView then
                Spring.SendCommands("specfullview")
            end
            if lockcameraLos and mySpecStatus then
                desiredLosmode = 'normal'
                desiredLosmodeChanged = os.clock()
            end
        end
        lockPlayerID = nil
        desiredLosmode = 'normal'
        desiredLosmodeChanged = os.clock()
    end
    UpdateRecentBroadcasters()

	return lockPlayerID
end


function CameraBroadcastEvent(playerID, cameraState)
    -- if cameraState is empty then transmission has stopped
    if not cameraState then
        if lastBroadcasts[playerID] then
            lastBroadcasts[playerID] = nil
            newBroadcaster = true
        end
        if lockPlayerID == playerID then
            LockCamera()
        end
        return
    end

    if not lastBroadcasts[playerID] and not newBroadcaster then
        newBroadcaster = true
    end

    lastBroadcasts[playerID] = { totalTime, cameraState }

    if playerID == lockPlayerID then
        Spring.SetCameraState(cameraState, transitionTime)
    end
end

local sec = 0
function widget:Update(dt)
	sec = sec + dt
	if sec > 1 then
		sec = 0
		UpdateRecentBroadcasters()
	end
    
    totalTime = totalTime + dt
    
	if desiredLosmode and desiredLosmodeChanged + 0.9 > os.clock() then
		if (desiredLosmode == "los" and Spring.GetMapDrawMode() == "normal") or (desiredLosmode == "normal" and Spring.GetMapDrawMode() == "los") then
			-- this is needed else the minimap/world doesnt update properly
			Spring.SendCommands("togglelos")
		end
		if desiredLosmodeChanged + 2 < os.clock() then
			desiredLosmode = nil
		end
	end

	if scheduledSpecFullView ~= nil then
		-- this is needed else the minimap/world doesnt update properly
		Spring.SendCommands("specfullview")
		scheduledSpecFullView = scheduledSpecFullView - 1
		if scheduledSpecFullView == 0 then
			scheduledSpecFullView = nil
		end
	end
end

function widget:PlayerChanged(playerID)
    if lockPlayerID and playerID == myPlayerID and desiredLosmode then
        desiredLosmodeChanged = os.clock()
    end
    myPlayerID = Spring.GetMyPlayerID()
    myAllyTeamID = Spring.GetLocalAllyTeamID()
    myTeamID = Spring.GetLocalTeamID()
    myTeamPlayerID = select(2, Spring.GetTeamInfo(myTeamID))
    mySpecStatus, fullView = Spring.GetSpectatingState()
end

function widget:Initialize()
	WG.lockcamera = {}
	WG.lockcamera.GetPlayerID = function()
		return lockPlayerID
	end
	WG.lockcamera.SetPlayerID = function(playerID)
		LockCamera(playerID)
	end
	WG.lockcamera.GetHideEnemies = function()
		return lockcameraHideEnemies
	end
	WG.lockcamera.SetHideEnemies = function(value)
		lockcameraHideEnemies = value
		if lockPlayerID and not select(3, Spring.GetPlayerInfo(lockPlayerID)) then
			if not lockcameraHideEnemies then
				if not fullView then
					Spring.SendCommands("specfullview")
					if lockcameraLos and mySpecStatus then
						desiredLosmode = 'normal'
						desiredLosmodeChanged = os.clock()
						Spring.SendCommands("togglelos")
					end
				end
			else
				if fullView then
					Spring.SendCommands("specfullview")
					if lockcameraLos and mySpecStatus then
						desiredLosmode = 'los'
						desiredLosmodeChanged = os.clock()
					end
				end
			end
		end
	end
	WG.lockcamera.GetTransitionTime = function()
	    return transitionTime
	end
	WG.lockcamera.SetTransitionTime = function(value)
	    transitionTime = value
	end
	WG.lockcamera.GetLos = function()
	    return lockcameraLos
	end
	WG.lockcamera.SetLos = function(value)
		lockcameraLos = value
		if lockcameraHideEnemies and mySpecStatus and lockPlayerID and not select(3, Spring.GetPlayerInfo(lockPlayerID)) then
			if lockcameraLos and mySpecStatus then
				desiredLosmode = 'los'
				desiredLosmodeChanged = os.clock()
				Spring.SendCommands("togglelos")
			elseif not lockcameraLos and Spring.GetMapDrawMode() == "los" then
				desiredLosmode = 'normal'
				desiredLosmodeChanged = os.clock()
				Spring.SendCommands("togglelos")
			end
		end
	end
	WG.lockcamera.SetLosMode = function(value)
		desiredLosmode = value
		desiredLosmodeChanged = os.clock()
	end

	widgetHandler:RegisterGlobal('CameraBroadcastEvent', CameraBroadcastEvent)

	UpdateRecentBroadcasters()

    widget:PlayerChanged(Spring.GetMyPlayerID())
end

function widget:Shutdown()
	WG.lockcamera = nil
    widgetHandler:DeregisterGlobal('CameraBroadcastEvent')
end

function widget:GameOver()
    if lockPlayerID then
        LockCamera()
    end
end

function widget:GetConfigData()    -- save
	local settings = {
		transitionTime = transitionTime,
		lockcameraHideEnemies = lockcameraHideEnemies,
		lockcameraLos = lockcameraLos,
	}
	return settings
end

function widget:SetConfigData(data)
    if data.lockcameraHideEnemies ~= nil then
        lockcameraHideEnemies = data.lockcameraHideEnemies
    end

    if data.lockcameraLos ~= nil then
        lockcameraLos = data.lockcameraLos
    end

    if data.transitionTime ~= nil then
        transitionTime = data.transitionTime
    end

    if Spring.GetGameFrame() > 0 then
        if data.lockPlayerID ~= nil then
            lockPlayerID = data.lockPlayerID
            if lockPlayerID and not select(3, Spring.GetPlayerInfo(lockPlayerID), false) then
                if not lockcameraHideEnemies then
                    if not fullView then
                        Spring.SendCommands("specfullview")
                        if lockcameraLos and mySpecStatus and Spring.GetMapDrawMode() == "los" then
                            desiredLosmode = 'normal'
                            desiredLosmodeChanged = os.clock()
                        end
                    end
                else
                    if fullView then
                        Spring.SendCommands("specfullview")
                        if lockcameraLos and mySpecStatus then
                            desiredLosmode = 'los'
                            desiredLosmodeChanged = os.clock()
                        end
                    end
                end
            end
        end
    end
end
