local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "Logo adjuster",
    desc      = "Changes taskbar icon",
    author    = "Floris",
    date      = "June 2021",
	license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true,
  }
end


-- Localized functions for performance

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMouseState = Spring.GetMouseState

local doNotify = true
local doBlink = true

local imgPrefix = 'bitmaps/logo'
local imagePlain2 = "2.png"
local imageBattle = ".png"
local imageBattleNotif = "_notif.png"
local imageBattleNotif2 = "_notif2.png"
local imageBattlePaused = "_paused.png"
local imageBattlePausedNotif = "_pausednotif.png"
local imageBattlePausedNotif2 = "_pausednotif2.png"
local imageBattleGameover = "_gameover.png"

local previousGameFrame = spGetGameFrame()
local paused = false
local notif = false
local blink = false
local sec = 0
local initialized = false
local gameover = false

local faction = '_a'
if UnitDefs[Spring.GetTeamRulesParam(spGetMyTeamID(), 'startUnit')].name == 'corcom' then
	faction = '_c'
end

local mouseOffscreen = select(6, spGetMouseState())
local prevMouseOffscreen = mouseOffscreen

function widget:Initialize()
	if Platform.osName == "Windows 7" then widgetHandler.RemoveWidget() end	-- changing the taskbar icon causes a few secs of freezing there
	WG.logo = {}
	WG.logo.mention = function()
		if mouseOffscreen then
			notif = true
		end
	end
end

function widget:GameStart()
	local prevFaction = faction
	if UnitDefs[Spring.GetTeamRulesParam(spGetMyTeamID(), 'startUnit')].name == 'corcom' then
		faction = '_c'
	else
		faction = '_a'
	end
	if prevFaction ~= faction then
		Spring.SetWMIcon(imgPrefix..faction..imageBattle, true)
	end
end


function widget:Shutdown()
    Spring.SetWMIcon(imgPrefix..imagePlain2, true)
end

function widget:GameOver()
	gameover = true
	Spring.SetWMIcon(imgPrefix..faction..imageBattleGameover, true)
end

function widget:Update(dt)
	if gameover then return end

	if not initialized then		-- this prevents icon being changed when still on loadscreen instead of doing it in widget:initialized
		initialized = true
		Spring.SetWMIcon(imgPrefix..faction..imageBattle, true)
	end
	sec = sec + dt
	if sec > 1.25 then
		sec = 0
		local gameFrame = spGetGameFrame()
		if gameFrame > 0 then

			local _, gameSpeed, isPaused = Spring.GetGameSpeed()
			local newPaused = false
			if gameFrame == previousGameFrame or gameSpeed == 0 then	-- when host (admin) paused its just gamespeed 0
				newPaused = true
			end

			if newPaused then
				if not paused then
					Spring.SetWMIcon(imgPrefix..faction..imageBattlePaused, true)
					paused = true
				end
			else
				if paused then
					Spring.SetWMIcon(imgPrefix..faction..imageBattle, true)
					paused = false
				end
			end
		else
			local prevFaction = faction
			if UnitDefs[Spring.GetTeamRulesParam(spGetMyTeamID(), 'startUnit')].name == 'corcom' then
				faction = '_c'
			else
				faction = '_a'
			end
			if prevFaction ~= faction then
				Spring.SetWMIcon(imgPrefix..faction..imageBattle, true)
			end
		end
		previousGameFrame = gameFrame

		if doNotify then
			local prevMouseOffscreen = mouseOffscreen
			mouseOffscreen = select(6, spGetMouseState())

			if not mouseOffscreen then
				if prevMouseOffscreen then
					notif = false
					Spring.SetWMIcon(imgPrefix..faction..(paused and imageBattlePaused or imageBattle), true)
				end
			else
				blink = not blink
				if mouseOffscreen and notif then
					if paused then
						Spring.SetWMIcon(imgPrefix..faction..((doBlink and blink) and imageBattlePausedNotif2 or imageBattlePausedNotif), true)
					else
						Spring.SetWMIcon(imgPrefix..faction..((doBlink and blink) and imageBattleNotif2 or imageBattleNotif), true)
					end
				end
			end
		end
	end
end
