function widget:GetInfo()
  return {
    name      = "Logo adjuster",
    desc      = "Changes taskbar logo",
    author    = "Floris",
    date      = "June 2021",
    layer     = 0,
    enabled   = true,
  }
end

local doNotify = true
local doBlink = true

local imagePlain = "bitmaps/logo.png"
local imageBattle = "bitmaps/logo_battle.png"
local imageBattleNotif = "bitmaps/logo_battlenotif.png"
local imageBattleNotif2 = "bitmaps/logo_battlenotif2.png"
local imageBattlePaused = "bitmaps/logo_battlepaused.png"
local imageBattlePausedNotif = "bitmaps/logo_battlepausednotif.png"
local imageBattlePausedNotif2 = "bitmaps/logo_battlepausednotif2.png"

local previousGameFrame = Spring.GetGameFrame()
local paused = false
local notif = false
local blink = false
local sec = 0

local mouseOffscreen = select(6, Spring.GetMouseState())
local prevMouseOffscreen = mouseOffscreen

function widget:Initialize()
    Spring.SetWMIcon(imageBattle)
	WG.logo = {}
	WG.logo.mention = function()
		if mouseOffscreen then
			notif = true
		end
	end
end

function widget:Shutdown()
    Spring.SetWMIcon(imagePlain)
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
					Spring.SetWMIcon(imageBattlePaused)
					paused = true

				end
			else
				if gameFrame ~= previousGameFrame then
					Spring.SetWMIcon(imageBattle)
					paused = false
				end
			end
		end
		previousGameFrame = gameFrame

		if doNotify then
			local prevMouseOffscreen = mouseOffscreen
			mouseOffscreen = select(6, Spring.GetMouseState())

			if not mouseOffscreen then
				if prevMouseOffscreen then
					notif = false
					Spring.SetWMIcon(paused and imageBattlePaused or imageBattle)
				end
			else
				blink = not blink
				if mouseOffscreen and notif then
					if paused then
						Spring.SetWMIcon((doBlink and blink) and imageBattlePausedNotif2 or imageBattlePausedNotif)
					else
						Spring.SetWMIcon((doBlink and blink) and imageBattleNotif2 or imageBattleNotif)
					end
				end
			end
		end
	end
end
