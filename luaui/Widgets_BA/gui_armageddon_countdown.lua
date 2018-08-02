
function widget:GetInfo()
	return {
		name      = 'Armageddon Countdown',
		desc      = '',
		author    = 'Niobium',
		date      = 'May 2011',
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

----------------------------------------------------------------
-- Load?
----------------------------------------------------------------
local armageddonTime = 60 * (tonumber((Spring.GetModOptions() or {}).armageddontime) or 0)
if armageddonTime <= 0 then
    return false
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

local gameStarterd = false
function widget:GameFrame(n)
    if n == 1 then
        gameStarted = true
    end
end

function widget:DrawScreen()
    local timeLeft = math.max(0, armageddonTime - Spring.GetGameSeconds())
    if timeLeft <= 300 and gameStarted then
        local vsx, vsy = gl.GetViewSizes()
        if timeLeft <= 0 then
            gl.Text('\255\255\1\1ARMAGEDDON', 0.5 * vsx, 0.25 * vsy, 20, 'cvo')
        elseif timeLeft <= 60 then
            gl.Text(string.format('\255\255\1\1Armageddon imminent... %i:%02i', timeLeft / 60, timeLeft % 60), 0.5 * vsx, 0.25 * vsy, 20, 'cvo')
        else
            gl.Text(string.format('\255\255\255\1Armageddon approaches... %i:%02i', timeLeft / 60, timeLeft % 60), 0.5 * vsx, 0.25 * vsy, 20, 'cvo')
        end
    end
end

function widget:GameOver()
	widgetHandler:RemoveWidget(self)
end
