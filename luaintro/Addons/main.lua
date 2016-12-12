
if addon.InGetInfo then
	return {
		name    = "Main",
		desc    = "displays a simplae loadbar",
		author  = "jK",
		date    = "2012,2013",
		license = "GPL2",
		layer   = 0,
		depend  = {"LoadProgress"},
		enabled = true,
	}
end

------------------------------------------

local lastLoadMessage = ""

function addon.LoadProgress(message, replaceLastLine)
	lastLoadMessage = message
end

------------------------------------------

local font = gl.LoadFont("FreeSansBold.otf", 70, 22, 1.15)

function RectRound(px,py,sx,sy,cs)
	--local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.floor(sx),math.floor(sy),math.floor(cs)
	
	gl.Rect(px+cs, py, sx-cs, sy)
	gl.Rect(sx-cs, py+cs, sx, sy-cs)
	gl.Rect(px+cs, py+cs, px, sy-cs)
	
	gl.Texture(":n:luaui/Images/bgcorner.png")
	gl.TexRect(px, py+cs, px+cs, py)		-- top left
	gl.TexRect(sx, py+cs, sx-cs, py)		-- top right
	gl.TexRect(px, sy-cs, px+cs, sy)		-- bottom left
	gl.TexRect(sx, sy-cs, sx-cs, sy)		-- bottom right
	gl.Texture(false)
end

function addon.DrawLoadScreen()
	local loadProgress = SG.GetLoadProgress()

	local vsx, vsy = gl.GetViewSizes()
	
	-- draw progressbar
	local hbw = 3.5/vsx
	local vbw = 3.5/vsy
	local hsw = 0.2
	local vsw = 0.2
	
	--bar bg
	local paddingW = 0.004 * (vsy/vsx)
	local paddingH = 0.004
	gl.Color(0,0,0,0.85)
	RectRound(0.2-paddingW,0.1-paddingH,0.8+paddingW,0.15+paddingH,0.0044)
	
	local loadvalue = 0.2 + math.max(0, loadProgress-0.01) * 0.6
	gl.Color(1-(loadProgress/3),loadProgress,0,0.23)
	RectRound(0.2,0.1,loadvalue,0.15,0.0033)
	
	local glowSize = 0.07
	gl.Color(1-(loadProgress/3)+0.1,loadProgress+0.1,0+0.1,0.07)
	gl.Texture(":n:luaui/Images/barglow-center.dds")
	gl.TexRect(0.2,	0.1-glowSize,	loadvalue,	0.15+glowSize)
	
	gl.Texture(":n:luaui/Images/barglow-edge.dds")
	gl.TexRect(0.2-(glowSize*1.33), 0.1-glowSize, 0.2, 0.15+glowSize)
	
	gl.TexRect(loadvalue+(glowSize*1.33), 0.1-glowSize, loadvalue, 0.15+glowSize)
	
	-- progressbar text
	gl.PushMatrix()
	gl.Scale(1/vsx,1/vsy,1)
		local barTextSize = vsy * 0.026

		--font:Print(lastLoadMessage, vsx * 0.5, vsy * 0.3, 50, "sc")
		--font:Print(Game.gameName, vsx * 0.5, vsy * 0.95, vsy * 0.07, "sca")
		font:Print(lastLoadMessage, vsx * 0.209, vsy * 0.133, barTextSize * 0.64, "oa")
		if loadProgress>0 then
			font:Print(("%.0f%%"):format(loadProgress * 100), vsx * 0.5, vsy * 0.1175, barTextSize, "oc")
		else
			font:Print("Loading...", vsx * 0.5, vsy * 0.165, barTextSize, "oc")
		end

	gl.PopMatrix()
end


function addon.MousePress(...)
	--Spring.Echo(...)
end


function addon.Shutdown()
	gl.DeleteFont(font)
end
