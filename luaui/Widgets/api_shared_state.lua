local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Shared State API",
		desc      = "Provides commonly-queried game state via WG to avoid redundant Spring API calls across widgets",
		author    = "BAR Team",
		date      = "2026",
		license   = "GNU GPL, v2 or later",
		layer     = -math.huge, -- load first so state is available to all widgets
		enabled   = true,
		handler   = true,
	}
end

-- Local references to Spring API calls
local spGetMyTeamID       = Spring.GetMyTeamID
local spGetMyAllyTeamID   = Spring.GetMyAllyTeamID
local spGetMyPlayerID     = Spring.GetMyPlayerID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetGameFrame      = Spring.GetGameFrame
local spIsGUIHidden       = Spring.IsGUIHidden
local spGetViewGeometry   = Spring.GetViewGeometry

local isReplay = Spring.IsReplay()

-- The shared state table
local state = {
	myTeamID       = spGetMyTeamID(),
	myAllyTeamID   = spGetMyAllyTeamID(),
	myPlayerID     = spGetMyPlayerID(),
	isSpec         = select(1, spGetSpectatingState()),
	isFullView     = select(2, spGetSpectatingState()),
	isReplay       = isReplay,
	gameFrame      = spGetGameFrame(),
	vsx            = 0,
	vsy            = 0,
	isGUIHidden    = false,
}

local function refreshPlayerState()
	state.myTeamID     = spGetMyTeamID()
	state.myAllyTeamID = spGetMyAllyTeamID()
	state.myPlayerID   = spGetMyPlayerID()
	local spec, fullView = spGetSpectatingState()
	state.isSpec     = spec
	state.isFullView = fullView
end

function widget:Initialize()
	local vsx, vsy = spGetViewGeometry()
	state.vsx = vsx
	state.vsy = vsy
	state.isGUIHidden = spIsGUIHidden()
	WG['sharedstate'] = state
end

function widget:Shutdown()
	WG['sharedstate'] = nil
end

function widget:PlayerChanged(playerID)
	refreshPlayerState()
end

function widget:ViewResize(vsx, vsy)
	state.vsx = vsx
	state.vsy = vsy
end

function widget:GameFrame(n)
	state.gameFrame = n
end

function widget:Update(dt)
	state.isGUIHidden = spIsGUIHidden()
end
