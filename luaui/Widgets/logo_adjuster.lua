function widget:GetInfo()
  return {
    name      = "Logo adjuster",
    desc      = "Changes taskbar icon",
    author    = "Floris",
    date      = "June 2021",
    layer     = 0,
    enabled   = true,
  }
end

local doNotify = true
local doBlink = true

local imgPrefix = 'bitmaps/logo'
local imagePlain = ".png"
local imageBattle = ".png"
local imageBattleNotif = "_notif.png"
local imageBattleNotif2 = "_notif2.png"
local imageBattlePaused = "_paused.png"
local imageBattlePausedNotif = "_pausednotif.png"
local imageBattlePausedNotif2 = "_pausednotif2.png"

local previousGameFrame = Spring.GetGameFrame()
local paused = false
local notif = false
local blink = false
local sec = 0

local faction = '_a'
if UnitDefs[Spring.GetTeamRulesParam(Spring.GetMyTeamID(), 'startUnit')].name == 'corcom' then
	faction = '_c'
end

local mouseOffscreen = select(6, Spring.GetMouseState())
local prevMouseOffscreen = mouseOffscreen

function widget:Initialize()
    Spring.SetWMIcon(imgPrefix..faction..imageBattle)
	WG.logo = {}
	WG.logo.mention = function()
		if mouseOffscreen then
			notif = true
		end
	end
end

function widget:Shutdown()
    Spring.SetWMIcon(imgPrefix..imagePlain)
end

-- possibly display gameover/trophy icon when being the winner?
function widget:GameOver()

end

function widget:Update(dt)
	sec = sec + dt
	if sec > 0.75 then
		sec = 0
		local now = os.clock()
		local gameFrame = Spring.GetGameFrame()
		if gameFrame > 0 then
			if not paused then
				if gameFrame == previousGameFrame then
					Spring.SetWMIcon(imgPrefix..faction..imageBattlePaused)
					paused = true

				end
			else
				if gameFrame ~= previousGameFrame then
					Spring.SetWMIcon(imgPrefix..faction..imageBattle)
					paused = false
				end
			end
		else
			local prevFaction = faction
			if UnitDefs[Spring.GetTeamRulesParam(Spring.GetMyTeamID(), 'startUnit')].name == 'corcom' then
				faction = '_c'
			else
				faction = '_a'
			end
			if prevFaction ~= faction then
				Spring.SetWMIcon(imgPrefix..faction..imageBattle)
			end
		end
		previousGameFrame = gameFrame

		if doNotify then
			local prevMouseOffscreen = mouseOffscreen
			mouseOffscreen = select(6, Spring.GetMouseState())

			if not mouseOffscreen then
				if prevMouseOffscreen then
					notif = false
					Spring.SetWMIcon(imgPrefix..faction..(paused and imageBattlePaused or imageBattle))
				end
			else
				blink = not blink
				if mouseOffscreen and notif then
					if paused then
						Spring.SetWMIcon(imgPrefix..faction..((doBlink and blink) and imageBattlePausedNotif2 or imageBattlePausedNotif))
					else
						Spring.SetWMIcon(imgPrefix..faction..((doBlink and blink) and imageBattleNotif2 or imageBattleNotif))
					end
				end
			end
		end
	end
end
