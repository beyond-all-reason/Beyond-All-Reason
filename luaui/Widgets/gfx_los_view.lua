local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "LOS View",
		desc = "Turns LOS view on when playing and off when becomming spectator.",
		author = "Bluestone",
		date = "",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spGetGameFrame = SpringShared.GetGameFrame
local spGetSpectatingState = SpringUnsynced.GetSpectatingState

local myPlayerID = SpringUnsynced.GetLocalPlayerID()
local lastMapDrawMode = SpringUnsynced.GetMapDrawMode()

local function TurnOnLOS()
	if SpringUnsynced.GetMapDrawMode() ~= "los" then
		SpringUnsynced.SendCommands("togglelos")
	end
end

local function TurnOffLOS()
	if SpringUnsynced.GetMapDrawMode() == "los" then
		SpringUnsynced.SendCommands("togglelos")
	end
end

function widget:Initialize()
	if spGetGameFrame() > 0 and lastMapDrawMode == "los" then
		TurnOnLOS()
	else
		TurnOffLOS()
	end
end

local gamestarted = false
function widget:GameFrame(frame) -- somehow widget:GameStart() didnt work
	if frame == 1 and not gamestarted then
		gamestarted = true
		myPlayerID = SpringUnsynced.GetLocalPlayerID()
		if spGetSpectatingState() then
			TurnOffLOS()
		else
			TurnOnLOS()
		end
	end
end

function widget:Shutdown()
	TurnOffLOS()
end

function widget:PlayerChanged(playerID)
	if spGetGameFrame() > 0 then
		if playerID == myPlayerID then
			if spGetSpectatingState() then
				TurnOffLOS()
			else
				TurnOnLOS()
			end
		end
	end
end

function widget:GetConfigData() --save config
	return { lastMapDrawMode = SpringUnsynced.GetMapDrawMode() }
end

function widget:SetConfigData(data) --load config
	if data.lastMapDrawMode then
		lastMapDrawMode = data.lastMapDrawMode
	end
end
