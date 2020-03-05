
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

local fontfile = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 25
local fontfileOutlineSize = 6
local fontfileOutlineStrength = 1.4
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)

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

function widget:Shutdown()
    gl.DeleteFont(font)
end

function widget:ViewResize(n_vsx,n_vsy)
    vsx,vsy = Spring.GetViewGeometry()
    widgetScale = (0.5 + (vsx*vsy / 5700000))
    local fontScale = widgetScale/2
    font = gl.LoadFont(fontfile, 52*fontScale, 17*fontScale, 1.5)
end

local gameStarterd = false
function widget:GameFrame(n)
    if n == 1 then
        gameStarted = true
    end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then return end
    local timeLeft = armageddonTime - Spring.GetGameSeconds()
    if timeLeft <= 300 and gameStarted then
        local vsx, vsy = gl.GetViewSizes()
        font:Begin()
        if timeLeft <= 0 then
            font:Print('\255\255\1\1ARMAGEDDON', 0.5 * vsx, 0.25 * vsy, 20, 'cvo')
        elseif timeLeft <= 60 then
            font:Print(string.format('\255\255\1\1Armageddon imminent... %i:%02i', timeLeft / 60, timeLeft % 60), 0.5 * vsx, 0.25 * vsy, 20, 'cvo')
        else
            font:Print(string.format('\255\255\255\1Armageddon approaches... %i:%02i', timeLeft / 60, timeLeft % 60), 0.5 * vsx, 0.25 * vsy, 20, 'cvo')
        end
        font:End()
    end
end

function widget:GameOver()
	widgetHandler:RemoveWidget(self)
end
