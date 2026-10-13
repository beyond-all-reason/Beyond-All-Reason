local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mission Client Actions",
		desc = "Carries out the Mission API's camera actions on this client",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local spGetMyTeamID = Spring.GetMyTeamID
local spGetSpectatingState = Spring.GetSpectatingState

-- Sent by luarules/mission_api/client_actions.lua as { kind, teamID, params }; each kind maps
-- onto one WG service, which may be missing when its widget is off.
local SERVICES = {
	play = "cinematicCamera",
	follow = "cinematicCamera",
	orbit = "cinematicCamera",
	shake = "cinematicCamera",
	save = "cinematicCamera",
	restore = "cinematicCamera",
	stop = "cinematicCamera",
}

local HANDLERS = {
	play = function(camera, params)
		camera.Play(params)
	end,
	follow = function(camera, params)
		camera.Follow(params)
	end,
	orbit = function(camera, params)
		camera.Orbit(params)
	end,
	shake = function(camera, params)
		camera.Shake(params)
	end,
	save = function(camera, params)
		camera.Save(params.slot)
	end,
	restore = function(camera, params)
		camera.Restore(params.slot, params.duration, params.easing)
	end,
	stop = function(camera)
		camera.Stop()
	end,
}

local function onClientAction(command)
	if command.teamID ~= nil and (spGetSpectatingState() or spGetMyTeamID() ~= command.teamID) then
		return
	end
	local service = WG[SERVICES[command.kind]]
	local handler = HANDLERS[command.kind]
	if service and handler then
		handler(service, command.params)
	end
end

function widget:Initialize()
	widgetHandler:RegisterGlobal("MissionClientAction", onClientAction)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("MissionClientAction")
end
