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

local imagePlain = "bitmaps/logo.png"
local imageBattle = "bitmaps/logo_battle.png"
local imageBattlePaused = "bitmaps/logo_battlepaused.png"

local previousGameFrame = Spring.GetGameFrame()
local paused = false
local sec = 0

function widget:Initialize()
    Spring.SetWMIcon(imageBattle)
end

function widget:Shutdown()
    Spring.SetWMIcon(imagePlain)
end

-- possibly display gameover/trophy icon when being the winner?
function widget:GameOver()

end

function widget:Update(dt)
	sec = sec + dt
	if sec > 0.5 then
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
	end
end
