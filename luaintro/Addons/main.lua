
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
local tips = {"Tip #1:\n\nHave trouble finding metal spots?\nPress F4 to switch to the metal map.",
"Tip #2: \n\nYou can tweak graphic preferences in options - in top right corner of the screen.\nWhen your FPS drops, switch to a lower graphic preset.",
"Tip #3: \n\nRadars are cheap, make them in early game to effectively counter early strikes.",
"Tip #4: \n\nCommanders rule the early stages of the battle, with their Dgun manual weapon they can decimate every unit with one blow.\nPress D to quckly initiate aiming.",
"Tip #5: \n\nSpread your buildings to prevent chained-explosions.\nPress ALT+Z and ALT+X to set automatic spacing.",
"Tip #6: \n\nIt is effective to move your units in spread formations.\nDrag your mouse while initiating a move order to draw multiple waypoints.",
"Tip #7: \n\nT2 factories are expensive, reclaim T1 lab for metal to fund it",
"Tip #8: \n\nAir strikes or airdrops may come anytime in the game, always have at least one anti-air unit in your base.",
"Tip #9: \n\nBA interface enables you to put labels on the map for other players to see.\n~(tilde)+doubleclick places a label with text.\n~(tilde)+middle mouse button puts an empty label.\n~(tilde)+mouse drag draws lines over the map. Use this for conducting coordinated team strategies and penises.",
"Tip #10: \n\nExpanding your territory essential in gaining economic advantage over your opponent. Always try to reach for as many metal spots and geo vents as you can.",
"Tip #11: \n\nAlways watch out for your Commander.\nTo quickly select and center camera on your Commander press CRTL+C."}
-- Random unit descriptions we can show
local unit_descs = {"armatlas.dds The Atlas is an airborne transportation unit. It can pick up all T1 land based units and T2, with exception of heavy ones, like Fatboy or Goliath. Use it for unexpected unit drops bypassing your enemy's defense line, but don't forget to scout first for any anti-air units. Drop your commander into their bases to Dgun all structures and humiliate your opponents. Can be used for transporting nano towers too, which enables you to move your buildpower where you currently need it.",
"armca.dds A Construction Aircraft is able to build basic T1 structures like the ones made by the Commander. Moreover it can build some more advanced land and air defense towers, advanced solar generators and most importantly the T2 Aircraft Plant. Due to their speed, the highest amongst constructors, it may be used for quick expansions and reclaiming in areas far from your base. It can also access the whole map, as it doesn't care about any natural obstacles. It has a very low HP, so keep away from enemy's anti air units. Due to little build power you may want to use multiple air cons at once. Each Construction Aircraft increases the player's energy and metal storage capacity by 25.",
"armfig.dds The Freedom Fighter is a fast moving fighter jet that is designed for eliminating air units. It is the most effective form of T1 air defense that can access all parts of the map to get rid of any air threats. In large packs, it is also able to destroy weak land-based structures, like nano towers. Always put your fighters on patrol in front of your base, so they attack any aircraft moving in the vicinity. Send fighters with your bombing runs to disable opponent's fighter wall before your bombers come to deliver the final blow.",
"armkam.dds The Banshee is a light gunship that can deal damage to land based units. It has very weak armor, that can be shattered by T1 anti air with ease, so always send them in packs and scout before striking. It is a weapon of surprise, try to keep it away from your foe's radars before attacking. If you succeed to put your gunships into an unguarded base, or over hostile Commander it will have no chance to survive. An effective attacking order is: nano towers -> AA towers,units -> eco and labs.",
"armpeep.dds The Peeper is a cheap and fast moving air scout, that is not armed with any weapons, but a huge line of sight. It is used to gain intelligence on what your enemy is planning, and where he keeps his most important units. Information is the most valuable asset on the battlefield, knowing your opponent's plans you can prepare your counter strikes early, making his moves inefficient. In lategame a constant stream of scouts helps your artillery units, improving their aim.",
"armthund.dds The Thunder is a bomber, designed for destroying buildings. A little bit weaker than its CORE counterpart - Shadow. It drops bombs over the target and makes a flyby to reload its ammunition. It can strike every 9 seconds. Always scout first and combine with fighters to eliminate enemy's airwall before  bombing. Click A for attack and drag your RMB to execute a carpet bombing, or use area attack command to strike targets within a circle." }

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

local loadedFontSize = 70
local font = gl.LoadFont("FreeSansBold.otf", 70, 22, 1.15)

function DrawRectRound(px,py,sx,sy,cs)

	--local csx = cs
	--local csy = cs
	--if sx-px < (cs*2) then
	--	csx = (sx-px)/2
	--	if csx < 0 then csx = 0 end
	--end
	--if sy-py < (cs*2) then
	--	csy = (sy-py)/2
	--	if csy < 0 then csy = 0 end
	--end
	--cs = math.min(cs, csy)

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
	RectRound(0.2-paddingW,0.25+paddingH,0.8+paddingW,0.7-paddingH,0.007)

	-- Text
	gl.PushMatrix()
	gl.Scale(1/vsx,1/vsy,1)
	-- In this format, there can be an optional image before the tip/description.
	-- Any image ends in .dss, so if such a text piece is found, we extract that and show it as an image.
	local i, j = string.find(random_tip_or_desc, ".dds")
	local text_to_show = random_tip_or_desc
	local image_text = nil
	local fontSize = barTextSize * 0.67

	if i ~= nil then
		image_text = string.sub(random_tip_or_desc, 0, j)
		text_to_show = string.sub(random_tip_or_desc, j+2)
		gl.Texture(":n:unitpics/" .. image_text)
		gl.Color(1.0,1.0,1.0,0.8)
		-- From X position, from Y position, to X position, to Y position
		gl.TexRect(vsx * 0.21, vsy*0.67, vsx*0.27, vsy*0.6)
		-- text, X position, Y position, text size.

		local maxWidth = (0.585 * vsx) * (loadedFontSize/fontSize)
		local text_to_show, numLines = font:WrapText(text_to_show, maxWidth)
		font:Print(text_to_show, vsx * 0.21, vsy * 0.675, fontSize, "oa")
	else
		local maxWidth = (0.585 * vsx) * (loadedFontSize/fontSize)
		local text_to_show, numLines = font:WrapText(text_to_show, maxWidth)
		font:Print(text_to_show, vsx * 0.21, vsy * 0.675, fontSize, "oa")
	end

	gl.PopMatrix()
end


function addon.MousePress(...)
	--Spring.Echo(...)
end


function addon.Shutdown()
	gl.DeleteFont(font)
end
