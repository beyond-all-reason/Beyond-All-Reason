local versionNumber = "v3"

function widget:GetInfo()
	return {
		name = "LockCamera",
		desc = versionNumber .. " API:  Allows you to lock your camera to another player's camera.\n"
				.. "/luaui lockcamera_interval to set broadcast interval (minimum 0.25 s).",
		author = "Evil4Zerggin (made into API by Floris)",
		date = "19 april 2015",
		license = "GNU LGPL, v2.1 or later",
		layer = -5,
		enabled = true
	}
end


------------------------------------------------
--config
------------------------------------------------

local transitionTime = 2 --how long it takes the camera to move
local listTime = 15 --how long back to look for recent broadcasters

------------------------------------------------
--vars
------------------------------------------------

local myPlayerID = Spring.GetMyPlayerID()
local lockPlayerID

local lastBroadcasts = {}
local recentBroadcasters = {}
local newBroadcaster = false
local totalTime = 0

local myLastCameraState

------------------------------------------------
--speedups
------------------------------------------------

local GetCameraState = Spring.GetCameraState
local SetCameraState = Spring.SetCameraState
local GetCameraNames = Spring.GetCameraNames

------------------------------------------------
--update
------------------------------------------------

local function UpdateRecentBroadcasters()
	recentBroadcasters = {}
	local i = 1
	for playerID, info in pairs(lastBroadcasts) do
		lastTime = info[1]
		if (totalTime - lastTime <= listTime or playerID == lockPlayerID) then
			if (totalTime - lastTime <= listTime) then
				recentBroadcasters[playerID] = totalTime - lastTime
			end
			i = i + 1
		end
	end
end

local function LockCamera(playerID)
	if playerID and playerID ~= myPlayerID and playerID ~= lockPlayerID then
		lockPlayerID = playerID
		myLastCameraState = myLastCameraState or GetCameraState()
		local info = lastBroadcasts[lockPlayerID]
		if info then
			SetCameraState(info[2], transitionTime)
		end
	else
		if myLastCameraState then
			SetCameraState(myLastCameraState, transitionTime)
			myLastCameraState = nil
		end
		lockPlayerID = nil
	end
	UpdateRecentBroadcasters()
end


------------------------------------------------
--callins
------------------------------------------------

function widget:Update(dt)
	totalTime = totalTime + dt
end

function CameraBroadcastEvent(playerID,cameraState)
	
	--if cameraState is empty then transmission has stopped
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
	
	lastBroadcasts[playerID] = {totalTime, cameraState}
	
	if playerID == lockPlayerID then
		SetCameraState(cameraState, transitionTime)
	end
end



function widget:Initialize()
	widgetHandler:RegisterGlobal('CameraBroadcastEvent', CameraBroadcastEvent)
	UpdateRecentBroadcasters()
	
	WG['lockcamera_api'] = {}
	WG['lockcamera_api'].LockCamera = function(playerID)
		LockCamera(playerID)
	end
	WG['lockcamera_api'].GetLockedPlayer = function()
		return lockPlayerID
	end
	WG['lockcamera_api'].GetBroadcasters = function()
		UpdateRecentBroadcasters()
		return recentBroadcasters 
	end
end


function widget:Shutdown()
	widgetHandler:DeregisterGlobal('CameraBroadcastEvent')
end
