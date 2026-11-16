-- What the options widget does for the game whether its window is open or not: engine settings kept in
-- line, water, input grabbing, muting offscreen, carrying state over a restart. Knows of no window
-- and no settings list; the state here is what the settings read and change, and is saved with them.
Spring.SendCommands("resbar 0")

local hardware = VFS.Include("luaui/Include/options/hardware.lua")

local version = 1.5 -- used to toggle previously default enabled/disabled widgets to the newer default in widget:initialize()
local newerVersion = false -- configdata will set this true if it's a newer version

local firstlaunchsetupDone = false

local continuouslyClean = Spring.GetConfigInt("ContinuouslyClearMapmarks", 0) == 1

local vsx, vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local fontfileSize = 36
local fontfileOutlineSize = 7

local spGetGroundHeight = Spring.GetGroundHeight
local os_clock = os.clock

local isSinglePlayer = BAR.Utilities.Gametype.IsSinglePlayer()
local isReplay = Spring.IsReplay()

local waterDetected = false
if select(3, Spring.GetGroundExtremes()) < 0 then
	waterDetected = true
end
local heightmapChangeBuffer = {}
local heightmapChangeClock
local checkedForWaterAfterGamestart
local gameOver = false
local enabledGrabinput

local defaultMapSunPos = { gl.GetSun("pos") }
local defaultSunLighting = {
	groundAmbientColor = { gl.GetSun("ambient") },
	unitAmbientColor = { gl.GetSun("ambient", "unit") },
	groundDiffuseColor = { gl.GetSun("diffuse") },
	unitDiffuseColor = { gl.GetSun("diffuse", "unit") },
	groundSpecularColor = { gl.GetSun("specular") },
	unitSpecularColor = { gl.GetSun("specular", "unit") },
}

local defaultSkyAxisAngle = {
	gl.GetAtmosphere("skyAxisAngle"),
}

-- Correct some maps fog
if Game.mapName == "Nine_Metal_Islands_V1" then
	Spring.SetAtmosphere({ fogStart = 999990, fogEnd = 9999999 })
end
local defaultMapFog = {
	fogStart = gl.GetAtmosphere("fogStart"),
	fogEnd = gl.GetAtmosphere("fogEnd"),
	fogColor = { gl.GetAtmosphere("fogColor") },
}

local state = {
	cameraTransitionTime = 0.18,
	cameraPanTransitionTime = 0.03,
	useNetworkSmoothing = false,
	desiredWaterValue = 4,
	waterDetected = waterDetected,
	edgeMoveWidth = tonumber(Spring.GetConfigFloat("EdgeMoveWidth", 1) or 0.02),
	defaultMapSunPos = defaultMapSunPos,
	defaultSunLighting = defaultSunLighting,
	defaultSkyAxisAngle = defaultSkyAxisAngle,
	defaultMapFog = defaultMapFog,
	resettedTonemapDefault = false,
}

local upkeep = {
	hardware = hardware,
	state = state,
	isSinglePlayer = isSinglePlayer,
	-- the lobby overlay is open: its text boxes take the keyboard
	chobbyInterface = false --[[@as boolean]],
}

local startScript = VFS.LoadFile("_script.txt")
local rwsBuffer = nil -- reassembly buffer for restart-with-state chunks (save path)
local rwsRestoreData = nil -- serialised state to send to gadget after restart (restore path)
local RWS_MSG_CHUNK = 4000

local function getRestartWithStateScript()
	local startPosTypePattern = "([Ss][Tt][Aa][Rr][Tt][Pp][Oo][Ss][Tt][Yy][Pp][Ee]%s*=%s*)%d+(%s*;)"
	local script, replacements = startScript:gsub(startPosTypePattern, function(prefix, suffix)
		return prefix .. "0" .. suffix
	end, 1)
	if replacements == 0 then
		Spring.Echo("[Restart With State] Could not set fixed start-position mode; using the original start script.")
	end
	return script
end

if not startScript then
	local modoptions = ""
	for key, value in pairs(BAR.GetModOptionsCopy()) do
		local v = value
		if type(v) == "boolean" then
			v = (v and "1" or "0")
		end
		modoptions = modoptions .. key .. "=" .. v .. ";"
	end

	startScript = [[[game]
	{
		[allyteam1]
		{
			numallies=0;
		}
		[team1]
		{
			teamleader=0;
			allyteam=1;
		}
		[ai0]
		{
			shortname=Null AI;
			name=AI: Null AI;
			team=1;
			host=0;
		}
		[modoptions]
		{
			]] .. modoptions .. [[
		}
		[allyteam0]
		{
			numallies=0;
		}
		[team0]
		{
			teamleader=0;
			allyteam=0;
		}
		[player0]
		{
			team=0;
			name=]] .. select(1, Spring.GetPlayerInfo(Spring.GetLocalPlayerID())) .. [[;
		}
		mapname=]] .. Game.mapName .. [[;
		myplayername=]] .. select(1, Spring.GetPlayerInfo(Spring.GetLocalPlayerID())) .. [[;
		ishost=1;
		gametype=]] .. Game.gameName .. " " .. Game.gameVersion .. [[;
		nohelperais=0;
	}
	]]
end

upkeep.startScript = startScript

local function setEngineFont()
	local relativesize = 1
	--"fonts/FreeSansBold.otf"
	Spring.SetConfigInt("SmallFontSize", fontfileSize * fontfileScale * relativesize)
	Spring.SetConfigInt("SmallFontOutlineWidth", fontfileOutlineSize * fontfileScale * relativesize * 0.85)
	Spring.SetConfigInt("SmallFontOutlineWeight", 2)

	Spring.SetConfigInt("FontSize", fontfileSize * fontfileScale * relativesize)
	Spring.SetConfigInt("FontOutlineWidth", fontfileOutlineSize * fontfileScale * relativesize * 0.85)
	Spring.SetConfigInt("FontOutlineWeight", 2)

	Spring.SendCommands("font " .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf"))

	-- set spring engine default font cause it can't thee game archive fonts on launch
	Spring.SetConfigString("SmallFontFile", "FreeSansBold.otf")
	Spring.SetConfigString("FontFile", "FreeSansBold.otf")
end
setEngineFont()

local function adjustShadowQuality()
	local quality = Spring.GetConfigInt("ShadowQuality", 3)
	local shadowMapSize = 600 + math.min(10240, (vsy + vsx) * 0.37) * (quality * 0.5)
	Spring.SetConfigInt("Shadows", (quality == 0 and 0 or 1))
	Spring.SetConfigInt("ShadowMapSize", shadowMapSize)
	Spring.SendCommands("shadows " .. (quality == 0 and 0 or 1) .. " " .. shadowMapSize)
end
upkeep.adjustShadowQuality = adjustShadowQuality

function upkeep.viewResize()
	vsx, vsy = Spring.GetViewGeometry()

	local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
	if fontfileScale ~= newFontfileScale then
		fontfileScale = newFontfileScale
		setEngineFont()
	end

	adjustShadowQuality()
end

local function detectWater()
	local _, _, mapMinHeight, _ = Spring.GetGroundExtremes()
	if mapMinHeight <= -2 then
		state.waterDetected = true
		Spring.SendCommands("water " .. state.desiredWaterValue)
	end
end
upkeep.detectWater = detectWater

local function updateGrabinput()
	-- grabinput makes alt-tabbing harder, so loosen grip a bit when in lobby would be wise
	if Spring.GetConfigInt("grabinput", 1) == 1 and not gameOver then
		if upkeep.chobbyInterface then
			if enabledGrabinput then
				enabledGrabinput = false
				Spring.SendCommands("grabinput 0")
			end
		else
			if not enabledGrabinput then
				enabledGrabinput = true
				Spring.SendCommands("grabinput 1")
			end
		end
	else
		enabledGrabinput = false
		Spring.SendCommands("grabinput 0")
	end
end
upkeep.updateGrabinput = updateGrabinput

local sec2 = 0
local ambientplayerCheck = false
local muteFadeTime = 0.35
local isOffscreen = false
local isOffscreenTime
local prevOffscreenVolume
local apiUnitTrackerEnabledCount = 0
local cachedMuteOffscreen = Spring.GetConfigInt("muteOffscreen", 0) == 1
local offscreenCheckTimer = 0

local function resetUserVolume()
	if prevOffscreenVolume then
		Spring.SetConfigInt("snd_volmaster", prevOffscreenVolume)
		prevOffscreenVolume = nil
	end
end

-- runs from the start; update waits until the settings have been made
function upkeep.updateOffscreen(dt)
	local now = os_clock()

	-- throttle offscreen detection to ~4x/sec (unless actively fading)
	local checkOffscreen = isOffscreenTime ~= nil
	if not checkOffscreen then
		offscreenCheckTimer = offscreenCheckTimer + dt
		if offscreenCheckTimer > 0.25 then
			offscreenCheckTimer = 0
			checkOffscreen = true
		end
	end
	if checkOffscreen then
		local prevIsOffscreen = isOffscreen
		isOffscreen = select(6, Spring.GetMouseState())
		if isOffscreen and enabledGrabinput then
			enabledGrabinput = false
		end
		if cachedMuteOffscreen then
			if isOffscreen ~= prevIsOffscreen then
				local prevIsOffscreenTime = isOffscreenTime
				isOffscreenTime = now
				if isOffscreen and not prevIsOffscreenTime then
					prevOffscreenVolume = tonumber(Spring.GetConfigInt("snd_volmaster", 40) or 40)
				end
			end
			if isOffscreenTime then
				if isOffscreenTime + muteFadeTime > now then
					if isOffscreen then
						Spring.SetConfigInt(
							"snd_volmaster",
							prevOffscreenVolume * (1 - ((now - isOffscreenTime) / muteFadeTime))
						)
					else
						Spring.SetConfigInt(
							"snd_volmaster",
							prevOffscreenVolume * ((now - isOffscreenTime) / muteFadeTime)
						)
					end
				else
					isOffscreenTime = nil
					if isOffscreen then
						Spring.SetConfigInt("snd_volmaster", 0)
					else
						resetUserVolume()
					end
				end
			end
		end
	end
end

function upkeep.update(dt)
	local now = os_clock()

	-- disable ambient player widget, also doing this on initialize but hell... players somehow still have this enabled
	if not ambientplayerCheck then
		ambientplayerCheck = true
		if widgetHandler:IsWidgetKnown("Ambient Player") then
			widgetHandler:DisableWidget("Ambient Player")
		end
	end

	--if tonumber(Spring.GetConfigInt("CameraSmoothing", 0)) == 1 then
	--	Spring.SetCameraState(nil, 1)
	--else
	if WG.lockcamera and not WG.lockcamera.GetPlayerID() and WG.setcamera_bugfix == true then
		Spring.SetCameraState(nil, state.cameraTransitionTime)
	end
	--end

	-- check if there is water shown 	(we do this because basic water 0 saves perf when no water is rendered)
	if not state.waterDetected then
		-- in case of modoption waterlevel has been made to show water
		if not checkedForWaterAfterGamestart and Spring.GetGameFrame() <= 30 then
			detectWater()
			checkedForWaterAfterGamestart = true
		end
		if heightmapChangeClock and heightmapChangeClock + 1 < now then
			for k, coords in pairs(heightmapChangeBuffer) do
				local x = coords[1]
				local z = coords[2]
				while x <= coords[3] do
					z = coords[2]
					while z <= coords[4] do
						if spGetGroundHeight(x, z) <= 0 then
							state.waterDetected = true
							Spring.SendCommands("water " .. state.desiredWaterValue)
							break
						end
						z = z + 8
					end
					if state.waterDetected then
						break
					end
					x = x + 8
				end
			end
			heightmapChangeClock = nil
			heightmapChangeBuffer = {}
		end
	end

	sec2 = sec2 + dt
	if sec2 > 0.5 then
		sec2 = 0
		continuouslyClean = Spring.GetConfigInt("ContinuouslyClearMapmarks", 0) == 1
		cachedMuteOffscreen = Spring.GetConfigInt("muteOffscreen", 0) == 1

		-- make sure widget is enabled
		if
			apiUnitTrackerEnabledCount < 10
			and widgetHandler.orderList["API Unit Tracker DEVMODE GL4"]
			and widgetHandler.orderList["API Unit Tracker DEVMODE GL4"] < 0.5
		then
			apiUnitTrackerEnabledCount = apiUnitTrackerEnabledCount + 1
			widgetHandler:EnableWidget("API Unit Tracker DEVMODE GL4")
		end

		updateGrabinput()
	end
end

function upkeep.recvLuaMsg(msg, playerID)
	-- restart-with-state: receive serialised unit state from the gadget and write it to disk
	-- Every player's widgets receive these, and the gadget only sends them in single player.
	if msg:sub(1, 4) == "rws:" and (not isSinglePlayer or playerID ~= Spring.GetMyPlayerID()) then
		return true -- Fake and maybe malicious
	end
	if msg == "rws:begin" then
		rwsBuffer = {}
		return true
	end
	local rwsChunk = msg:match("^rws:chunk:(.*)")
	if rwsChunk then
		if rwsBuffer then
			rwsBuffer[#rwsBuffer + 1] = rwsChunk
		end
		return true
	end
	if msg == "rws:commit" then
		if not rwsBuffer then
			return true
		end
		local data = table.concat(rwsBuffer)
		rwsBuffer = nil
		Spring.CreateDir("LuaUI/Config")
		local f, err = io.open("LuaUI/Config/restart_state.lua", "w")
		if not f then
			Spring.Echo("[Restart With State] Could not write state file: " .. tostring(err))
			return true
		end
		f:write(data)
		f:close()
		Spring.Echo("[Restart With State] State saved (" .. tostring(#data) .. " bytes). Restarting...")
		Spring.Restart("", getRestartWithStateScript())
		return true
	end
	if msg == "rws:clear" then
		local f = io.open("LuaUI/Config/restart_state.lua", "w")
		if f then
			f:close()
		end
		return true
	end
	if msg:sub(1, 18) == "LobbyOverlayActive" then
		upkeep.chobbyInterface = (msg:sub(1, 19) == "LobbyOverlayActive1")
		updateGrabinput()
		if (isSinglePlayer or isReplay) and not upkeep.chobbyInterface then
			Spring.SetConfigInt("VSync", Spring.GetConfigInt("VSyncGame", -1) * Spring.GetConfigInt("VSyncFraction", 1))
		end
	end
end

function upkeep.mapDrawCmd()
	if continuouslyClean then
		return true
	end
end

function upkeep.unsyncedHeightMapUpdate(x1, z1, x2, z2)
	if not state.waterDetected and Spring.GetGameFrame() > 30 then
		if heightmapChangeClock == nil then
			heightmapChangeClock = os_clock()
		end
		heightmapChangeBuffer[#heightmapChangeBuffer + 1] = { x1 * 8, z1 * 8, x2 * 8, z2 * 8 }
	end
end

function upkeep.gameOver()
	gameOver = true
	updateGrabinput()
end

function upkeep.gameFrame(n)
	-- Send the saved restore state to the gadget on the very first frame.
	-- We wait until frame 1 so that all gadgets are fully initialised.
	if rwsRestoreData and n == 1 then
		local data = rwsRestoreData
		rwsRestoreData = nil
		Spring.SendLuaRulesMsg("rws_restore_begin")
		for i = 1, #data, RWS_MSG_CHUNK do
			Spring.SendLuaRulesMsg("rws_restore_chunk:" .. data:sub(i, i + RWS_MSG_CHUNK - 1))
		end
		Spring.SendLuaRulesMsg("rws_restore_commit")
	end
end

local function devmodeCmd(_, _, params)
	Spring.SendCommands("option devmode")
end

local function profileCmd(_, _, params)
	if widgetHandler:IsWidgetKnown("Widget Profiler") then
		widgetHandler:ToggleWidget("Widget Profiler")
	end
end

local function grapherCmd(_, _, params)
	if widgetHandler:IsWidgetKnown("Frame Grapher") then
		widgetHandler:ToggleWidget("Frame Grapher")
	end
end

function upkeep.initialize(widget)
	-- Restart-with-state restore: if a saved state file exists from a previous
	-- restart-with-state trigger, read it now (io is available in LuaUI) and
	-- schedule it to be forwarded to the gadget on the first game frame.
	local RWS_FILE = "LuaUI/Config/restart_state.lua"
	local f = io.open(RWS_FILE, "r")
	if f then
		local content = f:read("*all")
		f:close()
		if content and content ~= "" then
			rwsRestoreData = content
		end
		-- Clear the file immediately so we don't restore again on the next restart
		local fc = io.open(RWS_FILE, "w")
		if fc then
			fc:close()
		end
	end

	-- disable ambient player widget
	if widgetHandler:IsWidgetKnown("Ambient Player") then
		widgetHandler:DisableWidget("Ambient Player")
	end
	if widgetHandler:IsWidgetKnown("Fog Volumes Old GL4") then
		widgetHandler:DisableWidget("Fog Volumes Old GL4")
	end
	if widgetHandler.orderList.FlowUI and widgetHandler.orderList.FlowUI < 0.5 then
		widgetHandler:EnableWidget("FlowUI")
	end
	if widgetHandler.orderList.Language and widgetHandler.orderList.Language < 0.5 then
		widgetHandler:EnableWidget("Language")
	end

	if widgetHandler.orderList["Infolos API"] and widgetHandler.orderList["Infolos API"] < 0.5 then
		widgetHandler:EnableWidget("Infolos API")
	end

	if widgetHandler.orderList["Mex Snap"] and widgetHandler.orderList["Mex Snap"] < 0.5 then
		widgetHandler:EnableWidget("Mex Snap")
	end
	-- set nano particle rotation: rotValue, rotVelocity, rotAcceleration, rotValueRNG, rotVelocityRNG, rotAccelerationRNG (in degrees)
	Spring.SetNanoProjectileParams(-180, -50, -50, 360, 100, 100)

	-- just making sure (not while a widget that takes its place is on: GetInfo replaces)
	if widgetHandler.orderList["Pregame UI"] < 0.5 and not widgetHandler.replacedList["Pregame UI"] then
		widgetHandler:EnableWidget("Pregame UI")
	end
	if widgetHandler.orderList["Pregame Queue"] < 0.5 then
		widgetHandler:EnableWidget("Pregame Queue")
	end
	if widgetHandler.orderList["Screen Mode/Resolution Switcher"] < 0.5 then
		widgetHandler:EnableWidget("Screen Mode/Resolution Switcher")
	end

	-- enable GL4 unit rendering api's
	if widgetHandler.orderList["DrawUnitShape GL4"] < 0.5 then
		widgetHandler:EnableWidget("DrawUnitShape GL4")
	end
	if widgetHandler.orderList["HighlightUnit API GL4"] < 0.5 then
		widgetHandler:EnableWidget("HighlightUnit API GL4")
	end

	if newerVersion then
		if widgetHandler.orderList["Defense Range GL4"] < 0.5 then
			widgetHandler:EnableWidget("Defense Range GL4")
		end
	end

	updateGrabinput()
	upkeep.viewResize()

	--if tonumber(Spring.GetConfigInt("CameraSmoothing", 0)) == 1 then
	--	Spring.SendCommands("set CamFrameTimeCorrection 1")
	--	Spring.SendCommands("set SmoothTimeOffset 2")
	--else
	--	Spring.SendCommands("set CamFrameTimeCorrection 0")
	--	Spring.SendCommands("set SmoothTimeOffset 0")
	--end

	-- make sure new icon system is used
	if Spring.GetConfigInt("UnitIconsAsUI", 0) == 0 then
		Spring.SendCommands("iconsasui 1")
		Spring.SetConfigInt("UnitIconsAsUI", 1)
	end

	if firstlaunchsetupDone == false then
		firstlaunchsetupDone = true

		Spring.Echo("First time setup:  done")
		Spring.SetConfigFloat("snd_airAbsorption", 0.35)

		-- Set lower defaults for lower end/potato systems
		if hardware.gpuMem < 3300 then
			if Spring.GetConfigInt("MSAALevel", 2) > 2 then
				Spring.SetConfigInt("MSAALevel", 2)
			end
		end
		if hardware.isPotatoGpu then
			Spring.SendCommands("water 0")
			Spring.SetConfigInt("Water", 0)

			--Spring.SetConfigInt("AdvMapShading", 0)
			--Spring.SendCommands("advmapshading 0")
			Spring.SendCommands("Shadows 0 1024")
			Spring.SetConfigInt("Shadows", 0)
			Spring.GetConfigInt("ShadowQuality", 0)
			Spring.SetConfigInt("ShadowMapSize", 1024)
			Spring.SetConfigInt("Shadows", 0)
			Spring.SetConfigInt("MSAALevel", 0)
			Spring.SetConfigFloat("ui_opacity", 0.7) -- set to be more opaque cause guishader isn't available
		else
			Spring.SendCommands("water 4")
			Spring.SetConfigInt("Water", 4)
		end

		local minMaxparticles = 12000
		if tonumber(Spring.GetConfigInt("MaxParticles", 1) or 0) < minMaxparticles then
			Spring.SetConfigInt("MaxParticles", minMaxparticles)
			Spring.Echo("First time setup:  setting MaxParticles config value to " .. minMaxparticles)
		end

		Spring.SetConfigInt("CamMode", 3)
		Spring.SendCommands("viewspring")
	end

	Spring.SetConfigFloat("CamTimeFactor", 1)
	Spring.SetConfigString("InputTextGeo", "0.35 0.72 0.03 0.04") -- input chat position posX, posY, ?, ?

	if Spring.GetGameFrame() == 0 then
		-- set minimum particle amount
		if tonumber(Spring.GetConfigInt("MaxParticles", 1) or 10000) <= 10000 then
			Spring.SetConfigInt("MaxParticles", 10000)
		end

		if Spring.GetConfigInt("MaxSounds", 128) < 128 then
			Spring.SetConfigInt("MaxSounds", 128)
		end

		-- limit MSAA
		if Spring.GetConfigInt("MSAALevel", 0) > 8 then
			Spring.SetConfigInt("MSAALevel", 8)
		end
	end

	-- make sure vertical angle is proper (not horizontal view)
	if
		Spring.GetGameFrame() == 0
		and (Spring.GetConfigInt("CamMode", 2) == 2 or Spring.GetConfigInt("CamMode", 2) == 3)
	then
		local cameraState = Spring.GetCameraState()
		cameraState.rx = 2.6
		Spring.SetCameraState(cameraState, 0.1)
	end

	-- make sure fog-start is smaller than fog-end in case maps have configured it this way
	if gl.GetAtmosphere("fogEnd") <= gl.GetAtmosphere("fogStart") then
		Spring.SetAtmosphere({ fogEnd = gl.GetAtmosphere("fogStart") + 0.01 })
	end

	Spring.SendCommands("minimap unitsize " .. (Spring.GetConfigFloat("MinimapIconScale", 3.5))) -- spring won't remember what you set with '/minimap iconssize #'

	widgetHandler.actionHandler:AddAction(widget, "devmode", devmodeCmd, nil, "t")
	widgetHandler.actionHandler:AddAction(widget, "profile", profileCmd, nil, "t")
	widgetHandler.actionHandler:AddAction(widget, "grapher", grapherCmd, nil, "t")
end

function upkeep.shutdown(widget)
	resetUserVolume()
	Spring.SendCommands("grabinput 0")

	widgetHandler.actionHandler:RemoveAction(widget, "devmode")
	widgetHandler.actionHandler:RemoveAction(widget, "profile")
	widgetHandler.actionHandler:RemoveAction(widget, "grapher")
end

function upkeep.getConfigData()
	return {
		-- these could be re-implemented as custom springsetting configint/float
		cameraTransitionTime = state.cameraTransitionTime,
		cameraPanTransitionTime = state.cameraPanTransitionTime,
		useNetworkSmoothing = state.useNetworkSmoothing,
		desiredWaterValue = state.desiredWaterValue, -- configint water can't be used since we will set water 0 when no water is present

		firsttimesetupDone = firstlaunchsetupDone,
		waterDetected = state.waterDetected,

		-- to restore init defaults
		mapChecksum = Game.mapChecksum,
		defaultMapFog = state.defaultMapFog,
		defaultMapSunPos = state.defaultMapSunPos,
		defaultSkyAxisAngle = state.defaultSkyAxisAngle,
		defaultSunLighting = state.defaultSunLighting,
		resettedTonemapDefault = state.resettedTonemapDefault,
		version = version,
		edgeMoveWidth = state.edgeMoveWidth,
	}
end

function upkeep.setConfigData(data)
	if data.version ~= nil then
		if data.version < version then
			newerVersion = true
		end
	else
		newerVersion = true
	end
	if data.desiredWaterValue ~= nil then
		state.desiredWaterValue = data.desiredWaterValue
	end
	if data.firsttimesetupDone ~= nil then
		firstlaunchsetupDone = data.firsttimesetupDone
	end
	if data.resettedTonemapDefault ~= nil then
		state.resettedTonemapDefault = data.resettedTonemapDefault
	end
	if data.cameraTransitionTime ~= nil then
		state.cameraTransitionTime = data.cameraTransitionTime
	end
	if data.cameraPanTransitionTime ~= nil then
		state.cameraPanTransitionTime = data.cameraPanTransitionTime
	end
	if data.edgeMoveWidth then
		state.edgeMoveWidth = data.edgeMoveWidth
	end
	if data.mapChecksum and data.mapChecksum == Game.mapChecksum then
		if data.defaultMapSunPos ~= nil then
			state.defaultMapSunPos = data.defaultMapSunPos
		end
		if data.defaultSunLighting ~= nil then
			state.defaultSunLighting = data.defaultSunLighting
		end
		if data.defaultMapFog ~= nil then
			state.defaultMapFog = data.defaultMapFog
		end
		if data.defaultSkyAxisAngle ~= nil then
			state.defaultSkyAxisAngle = data.defaultSkyAxisAngle
		end
	end
	if data.useNetworkSmoothing then
		state.useNetworkSmoothing = data.useNetworkSmoothing
	end
	-- this setting moved to the springsetting WindowsPauseGame; carry a switched off one over
	if data.pauseGameWhenSingleplayer == false then
		Spring.SetConfigInt("WindowsPauseGame", 0)
	end
end

return upkeep
