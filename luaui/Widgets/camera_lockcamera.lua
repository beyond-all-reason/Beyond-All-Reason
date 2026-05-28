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

local lockcameraHideEnemies = true -- specfullview
local lockcameraLos = true         -- togglelos

local transitionTime = 1.3         -- how long it takes the camera to move when tracking a player
local listTime = 14                -- how long back to look for recent broadcasters

local totalTime = 0
local lastBroadcasts = {}
local recentBroadcasters = {}
local newBroadcaster = false

local desiredLosmodeChanged = 0
local desiredLosmode, myLastCameraState

local spGetCameraState = Spring.GetCameraState
local spSetCameraState = Spring.SetCameraState
local spGetPlayerInfo = Spring.GetPlayerInfo
local spSendCommands = Spring.SendCommands
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMapDrawMode = Spring.GetMapDrawMode
local spGetMyPlayerID = Spring.GetMyPlayerID
local spGetLocalAllyTeamID = Spring.GetLocalAllyTeamID
local spGetLocalTeamID = Spring.GetLocalTeamID
local spGetTeamInfo = Spring.GetTeamInfo
local spGetGameFrame = Spring.GetGameFrame

local os_clock = os.clock
local math_pi = math.pi
local TWO_PI = 2 * math_pi

local function matchRotationRange(current_rotation, target_rotation)
	local difference = current_rotation - target_rotation
	local shortest_path = (difference + math_pi) % TWO_PI - math_pi
	return target_rotation + shortest_path
end

local function matchRotation(targetState)
	local myState = spGetCameraState()
	local targetRotation = targetState.ry
	local myRotation = myState.ry

	if not myRotation then
		myRotation = 0
		if myState.flipped == 0 then myRotation = math_pi end
	end
	if not targetRotation then
		targetRotation = 0
		if targetState.flipped == 0 then targetRotation = math_pi end
	end

	myState.ry = matchRotationRange(myRotation, targetRotation)
	myState.name = targetState.name
	myState.mode = targetState.mode
	spSetCameraState(myState)
	myLastCameraState = myLastCameraState or myState
end


local function UpdateRecentBroadcasters()
	for k in pairs(recentBroadcasters) do
		recentBroadcasters[k] = nil
	end
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
		_, _, isSpec, teamID = spGetPlayerInfo(playerID, false)
	end
	if playerID and playerID ~= myPlayerID and playerID ~= lockPlayerID and teamID then
		if lockcameraHideEnemies and not isSpec then
			spSendCommands("specteam " .. teamID)
			if not fullView then
				scheduledSpecFullView = 1 -- this is needed else the minimap/world doesnt update properly
				spSendCommands("specfullview")
			else
				scheduledSpecFullView = 2 -- this is needed else the minimap/world doesnt update properly
				spSendCommands("specfullview")
			end
			if not isSpec and lockcameraLos and mySpecStatus then
				desiredLosmode = 'los'
				desiredLosmodeChanged = os_clock()
			end
		elseif lockcameraHideEnemies and isSpec then
			if not fullView then
				spSendCommands("specfullview")
			end
			desiredLosmode = 'normal'
			desiredLosmodeChanged = os_clock()
		end
		lockPlayerID = playerID
		if not isSpec and lockcameraLos and mySpecStatus then
			desiredLosmode = 'los'
			desiredLosmodeChanged = os_clock()
		end
		myLastCameraState = myLastCameraState or spGetCameraState()
		local info = lastBroadcasts[lockPlayerID]
		if info then
			matchRotation(info[2])
			spSetCameraState(info[2], transitionTime)
		end
	else
		-- cancel camera tracking and restore own last known state
		if myLastCameraState then
			matchRotation(myLastCameraState)
			spSetCameraState(myLastCameraState, transitionTime)
			myLastCameraState = nil
		end
		-- restore fullview if needed
		if lockcameraHideEnemies and lockPlayerID and not isSpec then
			if not fullView then
				spSendCommands("specfullview")
			end
			if lockcameraLos and mySpecStatus then
				desiredLosmode = 'normal'
				desiredLosmodeChanged = os_clock()
			end
		end
		lockPlayerID = nil
		desiredLosmode = 'normal'
		desiredLosmodeChanged = os_clock()
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

	local entry = lastBroadcasts[playerID]
	if entry then
		entry[1] = totalTime
		entry[2] = cameraState
	else
		lastBroadcasts[playerID] = { totalTime, cameraState }
		if not newBroadcaster then
			newBroadcaster = true
		end
	end

	if playerID == lockPlayerID then
		spSetCameraState(cameraState, transitionTime)
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

	if desiredLosmode then
		local now = os_clock()
		if desiredLosmodeChanged + 0.9 > now then
			if (desiredLosmode == "los" and spGetMapDrawMode() == "normal") or (desiredLosmode == "normal" and spGetMapDrawMode() == "los") then
				-- this is needed else the minimap/world doesnt update properly
				spSendCommands("togglelos")
			end
		elseif desiredLosmodeChanged + 2 < now then
			desiredLosmode = nil
		end
	end

	if scheduledSpecFullView ~= nil then
		-- this is needed else the minimap/world doesnt update properly
		spSendCommands("specfullview")
		scheduledSpecFullView = scheduledSpecFullView - 1
		if scheduledSpecFullView == 0 then
			scheduledSpecFullView = nil
		end
	end
end

function widget:PlayerChanged(playerID)
	if lockPlayerID and playerID == myPlayerID and desiredLosmode then
		desiredLosmodeChanged = os_clock()
	end
	myPlayerID = spGetMyPlayerID()
	myAllyTeamID = spGetLocalAllyTeamID()
	myTeamID = spGetLocalTeamID()
	myTeamPlayerID = select(2, spGetTeamInfo(myTeamID))
	mySpecStatus, fullView = spGetSpectatingState()
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
		if lockPlayerID and not select(3, spGetPlayerInfo(lockPlayerID)) then
			if not lockcameraHideEnemies then
				if not fullView then
					spSendCommands("specfullview")
					if lockcameraLos and mySpecStatus then
						desiredLosmode = 'normal'
						desiredLosmodeChanged = os_clock()
						spSendCommands("togglelos")
					end
				end
			else
				if fullView then
					spSendCommands("specfullview")
					if lockcameraLos and mySpecStatus then
						desiredLosmode = 'los'
						desiredLosmodeChanged = os_clock()
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
		if lockcameraHideEnemies and mySpecStatus and lockPlayerID and not select(3, spGetPlayerInfo(lockPlayerID)) then
			if lockcameraLos and mySpecStatus then
				desiredLosmode = 'los'
				desiredLosmodeChanged = os_clock()
				spSendCommands("togglelos")
			elseif not lockcameraLos and spGetMapDrawMode() == "los" then
				desiredLosmode = 'normal'
				desiredLosmodeChanged = os_clock()
				spSendCommands("togglelos")
			end
		end
	end
	WG.lockcamera.SetLosMode = function(value)
		desiredLosmode = value
		desiredLosmodeChanged = os_clock()
	end
	WG.lockcamera.GetPlayerCameraState = function(playerID)
		if lastBroadcasts[playerID] then
			return lastBroadcasts[playerID][2]
		end
		return nil
	end

	widgetHandler:RegisterGlobal('CameraBroadcastEvent', CameraBroadcastEvent)

	UpdateRecentBroadcasters()

	widget:PlayerChanged(spGetMyPlayerID())
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

function widget:GetConfigData() -- save
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

	if spGetGameFrame() > 0 then
		if data.lockPlayerID ~= nil then
			lockPlayerID = data.lockPlayerID
			if lockPlayerID and not select(3, spGetPlayerInfo(lockPlayerID), false) then
				if not lockcameraHideEnemies then
					if not fullView then
						spSendCommands("specfullview")
						if lockcameraLos and mySpecStatus and spGetMapDrawMode() == "los" then
							desiredLosmode = 'normal'
							desiredLosmodeChanged = os_clock()
						end
					end
				else
					if fullView then
						spSendCommands("specfullview")
						if lockcameraLos and mySpecStatus then
							desiredLosmode = 'los'
							desiredLosmodeChanged = os_clock()
						end
					end
				end
			end
		end
	end
end
