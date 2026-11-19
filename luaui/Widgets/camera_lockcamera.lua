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
local lockcameraLos = true -- togglelos

local transitionTime = 1.3 -- how long it takes the camera to move when tracking a player
local listTime = 14 -- how long back to look for recent broadcasters

-- advanced only while Update runs, which sleeps once no broadcast is recent: a paused clock cannot
-- bring an old broadcast back into the recent list
local totalTime = 0.0
local sec = 0.0
local lastBroadcasts = {}
local recentBroadcasters = {}
local hasRecentBroadcasts = false
local updateActive = true
local playerStateDirty = true

local desiredLosmodeChanged = 0.0
---@type 'los'|'normal'|nil
local desiredLosmode
local myLastCameraState
---@type integer?
local lockPlayerID
---@type integer?
local scheduledSpecFullView
---@type integer?
local myPlayerID
---@type boolean?
local mySpecStatus
---@type boolean?
local fullView

local spGetCameraState = Spring.GetCameraState
local spSetCameraState = Spring.SetCameraState
local spGetPlayerInfo = Spring.GetPlayerInfo
local spSendCommands = Spring.SendCommands
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMapDrawMode = Spring.GetMapDrawMode
local spGetMyPlayerID = Spring.GetLocalPlayerID
local spGetGameFrame = Spring.GetGameFrame

local os_clock = os.clock
local math_pi = math.pi
local TWO_PI = 2 * math_pi

local function WakeUpdate()
	if not updateActive then
		updateActive = true
		sec = 1 -- refresh recentBroadcasters on the first frame back
		widgetHandler:UpdateCallIn("Update")
	end
end

local function SetDesiredLosmode(mode)
	desiredLosmode = mode
	desiredLosmodeChanged = os_clock()
	WakeUpdate()
end

local function RefreshLocalPlayerState()
	myPlayerID = spGetMyPlayerID()
	mySpecStatus, fullView = spGetSpectatingState()
	playerStateDirty = false
end

local function RefreshLocalPlayerStateIfDirty()
	if playerStateDirty then
		RefreshLocalPlayerState()
	end
end

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
		if myState.flipped == 0 then
			myRotation = math_pi
		end
	end
	if not targetRotation then
		targetRotation = 0
		if targetState.flipped == 0 then
			targetRotation = math_pi
		end
	end

	myState.ry = matchRotationRange(myRotation, targetRotation)
	myState.name = targetState.name
	myState.mode = targetState.mode
	spSetCameraState(myState)
	myLastCameraState = myLastCameraState or myState
end

local function UpdateRecentBroadcasters()
	-- players whose broadcast stopped are removed from both tables in CameraBroadcastEvent
	local anyRecent = false
	for playerID, info in pairs(lastBroadcasts) do
		local age = totalTime - info[1]
		if age <= listTime then
			recentBroadcasters[playerID] = age
			anyRecent = true
		else
			recentBroadcasters[playerID] = nil
		end
	end
	hasRecentBroadcasts = anyRecent
end

local function LockCamera(playerID)
	RefreshLocalPlayerState()

	local isSpec, teamID
	if playerID then
		_, _, isSpec, teamID = spGetPlayerInfo(playerID, false)
	end
	if playerID and playerID ~= myPlayerID and playerID ~= lockPlayerID and teamID then
		if lockcameraHideEnemies and not isSpec then
			spSendCommands("specteam " .. teamID)
			-- this is needed else the minimap/world doesn't update properly
			scheduledSpecFullView = fullView and 2 or 1
			spSendCommands("specfullview")
			WakeUpdate()
		elseif lockcameraHideEnemies and isSpec then
			if not fullView then
				spSendCommands("specfullview")
			end
			SetDesiredLosmode("normal")
		end
		lockPlayerID = playerID
		if not isSpec and lockcameraLos and mySpecStatus then
			SetDesiredLosmode("los")
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
		if lockcameraHideEnemies and lockPlayerID and not isSpec and not fullView then
			spSendCommands("specfullview")
		end
		lockPlayerID = nil
		SetDesiredLosmode("normal")
	end
	UpdateRecentBroadcasters()

	return lockPlayerID
end

function widget:CameraBroadcastEvent(playerID, cameraState)
	-- if cameraState is empty then transmission has stopped
	if not cameraState then
		lastBroadcasts[playerID] = nil
		recentBroadcasters[playerID] = nil
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
	end
	hasRecentBroadcasts = true
	WakeUpdate()

	if playerID == lockPlayerID then
		spSetCameraState(cameraState, transitionTime)
	end
end

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
			local mapDrawMode = spGetMapDrawMode()
			if
				(desiredLosmode == "los" and mapDrawMode == "normal")
				or (desiredLosmode == "normal" and mapDrawMode == "los")
			then
				-- this is needed else the minimap/world doesn't update properly
				spSendCommands("togglelos")
			end
		elseif desiredLosmodeChanged + 2 < now then
			desiredLosmode = nil
		end
	end

	if scheduledSpecFullView ~= nil then
		-- this is needed else the minimap/world doesn't update properly
		spSendCommands("specfullview")
		scheduledSpecFullView = scheduledSpecFullView - 1
		if scheduledSpecFullView == 0 then
			scheduledSpecFullView = nil
		end
	end

	if not (hasRecentBroadcasts or desiredLosmode or scheduledSpecFullView) then
		updateActive = false
		widgetHandler:RemoveCallIn("Update")
	end
end

function widget:PlayerChanged(playerID)
	if lockPlayerID and playerID == myPlayerID and desiredLosmode then
		desiredLosmodeChanged = os_clock()
	end
	playerStateDirty = true
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
		RefreshLocalPlayerStateIfDirty()
		if lockPlayerID and not select(3, spGetPlayerInfo(lockPlayerID, false)) then
			if not lockcameraHideEnemies then
				if not fullView then
					spSendCommands("specfullview")
					if lockcameraLos and mySpecStatus then
						SetDesiredLosmode("normal")
						spSendCommands("togglelos")
					end
				end
			else
				if fullView then
					spSendCommands("specfullview")
					if lockcameraLos and mySpecStatus then
						SetDesiredLosmode("los")
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
		RefreshLocalPlayerStateIfDirty()
		if
			lockcameraHideEnemies
			and mySpecStatus
			and lockPlayerID
			and not select(3, spGetPlayerInfo(lockPlayerID, false))
		then
			if lockcameraLos and mySpecStatus then
				SetDesiredLosmode("los")
				spSendCommands("togglelos")
			elseif not lockcameraLos and spGetMapDrawMode() == "los" then
				SetDesiredLosmode("normal")
				spSendCommands("togglelos")
			end
		end
	end
	WG.lockcamera.SetLosMode = SetDesiredLosmode
	WG.lockcamera.GetPlayerCameraState = function(playerID)
		local info = lastBroadcasts[playerID]
		return info and info[2]
	end
	WG.lockcamera.recentBroadcasters = recentBroadcasters

	UpdateRecentBroadcasters()

	RefreshLocalPlayerState()
end

function widget:Shutdown()
	WG.lockcamera = nil
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
			RefreshLocalPlayerStateIfDirty()
			lockPlayerID = data.lockPlayerID
			if lockPlayerID and not select(3, spGetPlayerInfo(lockPlayerID, false)) then
				if not lockcameraHideEnemies then
					if not fullView then
						spSendCommands("specfullview")
						if lockcameraLos and mySpecStatus and spGetMapDrawMode() == "los" then
							SetDesiredLosmode("normal")
						end
					end
				else
					if fullView then
						spSendCommands("specfullview")
						if lockcameraLos and mySpecStatus then
							SetDesiredLosmode("los")
						end
					end
				end
			end
		end
	end
end
