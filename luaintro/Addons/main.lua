
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

-- Random tips we can show
local tips = {"Tip #294:\n\nHave trouble finding metal spots?\nPress F4 to switch to the metal map.",
"Tip #15: Some other tip."}
-- Random unit descriptions we can show
local unit_descs = {"armacv.dds ARM Amphibious Constructor\nDescription comes here after the image. Image must end to dds. Image must be in unitpics",
"armamb.dds Some other unit."}

-- Since math.random is not random and always the same, we save a counter to a file and use that.
filename = "LuaUI/Config/randomseed.data"
k = os.time() % 1500
if VFS.FileExists(filename) then
    local file = assert(io.open(filename,'r'), "Unable to load latest randomseed from "..filename)
    k = math.floor(tonumber(file:read())) % 1500
    file:close()
end
k = k + 1
local file = assert(io.open(filename,'w'), "Unable to save latest randomseed from "..filename)
    file:write(k)
    file:close()
file = nil

local random_tip_or_desc = unit_descs[((k/2) % #unit_descs) + 1]
if k%2 == 1 then
    random_tip_or_desc = tips[((math.ceil(k/2)) % #tips) + 1]
end

--local random_tip_or_desc = unit_descs[(math.random(rand, rand+#unit_descs)-rand) + 1]
--if rand%2 == 1 then
--	random_tip_or_desc = tips[(math.random(rand, rand+#tips)-rand) + 1]
--end

local font = gl.LoadFont("FreeSansBold.otf", 70, 22, 1.15)

function DrawRectRound(px,py,sx,sy,cs)

	local csx = cs
	local csy = cs
	if sx-px < (cs*2) then
		csx = (sx-px)/2
		if csx < 0 then csx = 0 end
	end
	if sy-py < (cs*2) then
		csy = (sy-py)/2
		if csy < 0 then csy = 0 end
	end
	cs = math.min(csx, csy)

	gl.TexCoord(0.8,0.8)
	gl.Vertex(px+cs, py, 0)
	gl.Vertex(sx-cs, py, 0)
	gl.Vertex(sx-cs, sy, 0)
	gl.Vertex(px+cs, sy, 0)

	gl.Vertex(px, py+cs, 0)
	gl.Vertex(px+cs, py+cs, 0)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)
	
	gl.Vertex(sx, py+cs, 0)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)
	
	local offset = 0.05		-- texture offset, because else gaps could show
	local o = offset
	
	-- top left
	--if py <= 0 or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, py+cs, 0)
	-- top right
	--if py <= 0 or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, py+cs, 0)
	-- bottom left
	--if sy >= vsy or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, sy-cs, 0)
	-- bottom right
	--if sy >= vsy or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, sy-cs, 0)
end

function RectRound(px,py,sx,sy,cs)
	--local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)
	
	gl.Texture(":n:luaui/Images/bgcorner.png")
	--gl.Texture(":n:luaui/Images/bgcorner.png")
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs)
	gl.Texture(false)
end

function gradienth(px,py,sx,sy, c1,c2)
	gl.Color(c1)
	gl.Vertex(sx, sy, 0)
	gl.Vertex(sx, py, 0)
	gl.Color(c2)
	gl.Vertex(px, py, 0)
	gl.Vertex(px, sy, 0)
end

function addon.DrawLoadScreen()
	local loadProgress = SG.GetLoadProgress()

	local vsx, vsy = gl.GetViewSizes()
	
	-- draw progressbar
	local hbw = 3.5/vsx
	local vbw = 3.5/vsy
	local hsw = 0.2
	local vsw = 0.2
	
	local loadvalue = 0.2 + (math.max(0, loadProgress) * 0.6)
	
	--bar bg
	local paddingH = 0.004
	local paddingW = paddingH * (vsy/vsx)
	gl.Color(0.06,0.06,0.06,0.8)
	RectRound(0.2-paddingW,0.1-paddingH,0.8+paddingW,0.15+paddingH,0.007)
	
	-- loadvalue
	gl.Color(0.4-(loadProgress/7),loadProgress*0.4,0,0.4)
	RectRound(0.2,0.1,loadvalue,0.15,0.0055)
	
	-- loadvalue gradient
	gl.Texture(false)
	gl.BeginEnd(GL.QUADS, gradienth, 0.2,0.1,loadvalue,0.15, {1-(loadProgress/3)+0.2,loadProgress+0.2,0+0.08,0.14}, {0,0,0,0.14})
	
	-- loadvalue inner glow
	gl.Color(1-(loadProgress/3.5)+0.15,loadProgress+0.15,0+0.05,0.085)
	gl.Texture(":n:luaui/Images/barglow-center.dds")
	gl.TexRect(0.2,0.1,loadvalue,0.15)
	
	-- loadvalue glow
	local glowSize = 0.045
	gl.Color(1-(loadProgress/3)+0.15,loadProgress+0.15,0+0.05,0.07)
	gl.Texture(":n:luaui/Images/barglow-center.dds")
	gl.TexRect(0.2,	0.1-glowSize,	loadvalue,	0.15+glowSize)
	
	gl.Texture(":n:luaui/Images/barglow-edge.dds")
	gl.TexRect(0.2-(glowSize*1.3), 0.1-glowSize, 0.2, 0.15+glowSize)
	gl.TexRect(loadvalue+(glowSize*1.3), 0.1-glowSize, loadvalue, 0.15+glowSize)

	-- progressbar text
	gl.PushMatrix()
	gl.Scale(1/vsx,1/vsy,1)
		local barTextSize = vsy * 0.026

		--font:Print(lastLoadMessage, vsx * 0.5, vsy * 0.3, 50, "sc")
		--font:Print(Game.gameName, vsx * 0.5, vsy * 0.95, vsy * 0.07, "sca")
		font:Print(lastLoadMessage, vsx * 0.21, vsy * 0.133, barTextSize * 0.67, "oa")
		if loadProgress>0 then
			font:Print(("%.0f%%"):format(loadProgress * 100), vsx * 0.5, vsy * 0.1175, barTextSize, "oc")
		else
			font:Print("Loading...", vsx * 0.5, vsy * 0.165, barTextSize, "oc")
		end

	gl.PopMatrix()

	-- Tip/unit description
	-- Background
	gl.Color(0.06,0.06,0.06,0.8)
	RectRound(0.2-paddingW,0.7-paddingH,0.8+paddingW,0.25+paddingH,0.007)

	-- Text
	gl.PushMatrix()
	gl.Scale(1/vsx,1/vsy,1)
	-- In this format, there can be an optional image before the tip/description.
	-- Any image ends in .dss, so if such a text piece is found, we extract that and show it as an image.
	local i, j = string.find(random_tip_or_desc, ".dds")
	local text_to_show = random_tip_or_desc
	local image_text = nil

	if i ~= nil then
		image_text = string.sub(random_tip_or_desc, 0, j)
		text_to_show = string.sub(random_tip_or_desc, j+2)
		gl.Texture(":n:unitpics/" .. image_text)
		gl.Color(1.0,1.0,1.0,0.8)
		-- From X position, from Y position, to X position, to Y position
		gl.TexRect(vsx * 0.21, vsy*0.67, vsx*0.27, vsy*0.6)
		-- text, X position, Y position, text size.
		font:Print(text_to_show, vsx * 0.21, vsy * 0.59, barTextSize * 0.67, "oa")
	else
		font:Print(text_to_show, vsx * 0.21, vsy * 0.68, barTextSize * 0.67, "oa")
	end

	gl.PopMatrix()
end


function addon.MousePress(...)
	--Spring.Echo(...)
end


function addon.Shutdown()
	gl.DeleteFont(font)
end
