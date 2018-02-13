
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
local tips = {
	"Have trouble finding metal spots?\nPress F4 to switch to the metal map.",
	"Queue-up multiple consecutive unit actions by holding SHIFT.",
	"Tweak graphic preferences in options (top right corner of the screen).\nWhen your FPS drops, switch to a lower graphic preset.",
	"Radars are cheap, make them early in the game to effectively counter initial strikes.",
	"To see detailed info about each unit in-game switch on \"Extensive unit info\"",
	"In general, vehicles are a good choice for flat and open battlefields. Kbots are better on hills.",
	"If your economy is based on wind generators, always build an E storage to have a reserve, when the wind speed drops.",
	"Commanders have a manual Dgun weapon, which can decimate every unit with one blow.\nPress D to quickly initiate aiming.",
	"Spread out buildings to prevent chain-explosions.\nPress ALT+Z and ALT+X to adjust auto-spacing.",
	"It is effective to move your units in spread formations.\nDrag your mouse while initiating a move order to draw multiple waypoints.",
	"T2 factories are expensive, reclaim T1 lab for metal to fund it",
	"Air strikes and airdrops may come anytime in the game, always have at least one anti-air unit in your base.",
	"With ~(tilde)+doubleclick you can place a label with text on the map.\n~(tilde)+middle mouse button for an empty label.\n~(tilde)+mouse drag to draw lines",
	"Always check your Com-counter (next to resource bars). If you have the last Commander you better hide it quick!",
	"Expanding territory is essential in gaining economic advantage.\nTry to reach for as many metal spots and geothermal vents as you can.",
	"Think in advance about reclaiming metal from wrecks piling up at the front.",
	"When your excessing energy... build metal makers to convert the excess to metal.",
	"Select all units of the same type by pressing CTRL+Z.",
	"To quickly select and center camera on your Commander: press CRTL+C.",
	"Think ahead and include anti-air and support units in your army.",
	"Mastering hotkeys is the key to proficiency in BA.\nUse Z,X,C to quickly cycle between most frequently built structures.",
	"Howto share resources to teammates:\n - Double-click tank icon next to the player's name to share units\n - Click-drag metal/energy bar next to player's name to share resources.\n - Press H to share an exact amount",
	"It is efficient to support your lab with constructors increasing its build-power.\nRight click on the factory with a constructor selected to guard (assist) with it",
	"Remember to separate your highly explosive buildings, like metal makers from the rest of your base.",
	"Most long-ranged units are very vulnerable in close-combat. Always keep a good distance from your targets.",
	"Keep all your builders busy.\nPress CTRL+B to select and center camera on your idle con.",
	"The best way to prevent air strikes is building fighters and putting them on PATROL in front of your base.",
	"Use jammers to hide your units from enemy radars and hinder artillery strikes.",
	"Cloaking your Commander drains 100E stationary and 1000E when walking (every second)",
	"Combine CLOAK with radar jamming to make your units fully stealthy.",
	"Long-ranged units need scouting for accurate aiming.\nGenerate a constant stream of quick/cheap units for better vision.",
	"You can assign units to groups by pressing CTRL+[num].\nSelect the group using numbers (1-9).",
	"When performing a bombing run fly your fighters first to eliminate enemy's fighter-wall. Use FIGHT or PATROL command for that.",
	"You can disable enemy's anti-nukes using EMP missiles (built by ARM T2 cons).",
	"Don't build too much stuff around your Moho-geothermal powerplants or everything will go boom!",
	"It is effective to build long range anti-air on extended front line to slowly dismantle enemy's fighter-wall.",
	"Commander's Dgun can be used for insta-killing T3 units. Don't forget to CLOAK it.\nFor quickly cloaking press C.",
	"If you are certain of loosing some unit on enemy front, self-d it to prevent him from getting the metal. \nPress CTRL+D to initiate the countdown.",
	"Mines are the super-cheap and quick to build. Remember to make them away from enemy's line of sight.",
}

-- Random unit descriptions we can show
local unit_descs = {
	"armck.dds Construction Kbot is able to build basic T1 structures like the ones made by the Commander and advanced land and air defense towers, advanced solars and most importantly the T2 Kbot lab. It is slightly slower and weaker than vehicle constructor, but it can climb steeper hills, so it is effective in expansion on mountainous terrain.",
	"armflea.dds Fleas are supercheap and fast to build Kbots used for scouting and damaging the early eco structures of enemies. It is faster than all Kbots and most vehicles but any close confrontation will be lethal to it. Evade laser towers and destroy metal extractors to slow down your foe’s expansion!",
	"armham.dds Hammer is a plasma Kbot that can deal a sizeable damage with relatively low cost of building. It has slightly higher HP than rocket Kbots, hence it can be used in big numbers to destroy T1 defensive structures. Combine with resurrection Kbots (Rectors), for an effective front push. Useful for defending mountain tops.",
	"armjeth.dds Jethro is a cheap amphibious mobile anti-air (AA) Kbot, that can easily take down light aircrafts. Always send a few with your army to protect it from EMP drones/gunships. It has no land-to-land weapons.",
	"armpw.dds Peewee is a basic infantry Kbot. Being very cheap to build and having high top speeds can be useful for scouting and taking down unguarded metal extractors and eco. In late T1 warfare Peewees can be used for ambushing Commanders and speedy skirmishing.",
	"armrectr.dds Rector is a resurrection Kbot which can turn wrecks into brand new army members or reclaim them to get back your metal! It is fast and cheap to build, therefore it works great for reclaiming trees, rocks etc. Good for repairing damaged units too.",
	"armrock.dds Rocko is a light rocket Kbot used mainly to push the frontline towards opponent's base. It can outrange light laser turrets. Not effective against mobile units, watch out for A.K./Peewees!",
	"armwar.dds Warrior is a durable Kbot armed with a rapid firing double laser. It has a relatively high HP for T1 and can easily take down multiple light assault units. Always combine with resurrection Kbots for healing and resurrecting fallen ones.",
	"corak.dds A.K. is a light infantry Kbot which is cheap and quick to build. Proves useful for scouting and taking down unguarded structures like metal extractors and early eco. It is armed with light, but precise laser with a little longer range than PeeWee, so with  little microing skills you can outrange them eaisily.",
	"corcrash.dds Crasher is a cheap amphibious mobile anti-air (AA) Kbot, that can easily take down light aircrafts. Always send a few with your army to protect it from EMP drones/gunships. It has no land-to-land weapons.",
	"corstorm.dds Storm is a light rocket Kbot used to push the frontline towards opponent's base. It can outrange light laser turrets. Hopeless against fast mobile units. Slower, but stronger than ARM counterparts.",
	"cornecro.dds Necro is a resurrection Kbot which can turn wrecks into brand new army members or reclaim them to get back your metal! It is fast and cheap to build, therefore it works great for reclaiming trees, rocks etc. Good for repairing damaged units too.",
	"corthud.dds Thud is a plasma Kbot that can deal a sizeable damage with relatively low cost of building. It has a shorter range than rocket Kbots. Combine with resurrection Kbots (Necros), for healing and resurrecting fallen ones, to quickly push the frontline. Useful for defending mountain tops.",
	"armfav.dds Jeffies are supercheap and fast to build vehicles used for scouting and damaging the early eco structures. It is the fastest moving unit in the whole game but due to light armor any close confrontation will be lethal to it. Evade laser towers and destroy metal extractors to slow down your foe's expansion.",
	"armflash.dds Flash is a light, fast moving tank with close combat rapid fire weapon. It is slightly more powerful and faster than Peewee and A.K. on flat terrain. Being very cheap to build and having high top speeds can be useful for scouting and taking down unguarded metal extractors and eco.",
	"armart.dds Shellshocker is an artillery vehicle used to take down T1 defenses, esp. High Laser Turrets. It can outrange all T1 defense towers. Always keep them protected by Stumpies/Flashes, or your own defensive structures. Don't forget to have targets in your radar's range or scouted.",
	"armbeaver.dds Beaver is an amphibious construction vehicle, which can travel on land and underwater equally well allowing easy expansion between islands, under rivers and across seas. Its build menu includes some water based units like underwater metal extractors, tidal generators and most importantly the amphibious complex.",
	"armcv.dds",
	"armjanus.dds",
	"armmlv.dds",
	"armpincer.dds",
	"armsam.dds",
	"armstump.dds",
	"armatlas.dds Atlas is an airborne transportation unit. It can pick up all T1 land based units and T2, with exception of heavy ones, like Fatboy or Goliath. Use it for unexpected unit drops bypassing your enemy's defense line. Can be used for transporting nano towers too.",
	"armca.dds Construction Aircraft is able to build basic T1 structures like the ones made by the Commander plus advanced land and air defense towers, advanced solar generators and most importantly the T2 Aircraft Plant. Due to its speed it may be used for quick expansion and reclaiming in areas far from your base. Due to little build power you may want to use multiple air cons at once.",
	"armfig.dds Freedom Fighter is a fast moving fighter jet that is designed for eliminating air units. It is the most effective form of T1 air defense. Always put your fighters on patrol in front of your base, so they attack any hostile aircraft moving in the vicinity. Send fighters with your bombing runs to disable opponent's fighter wall.",
	"armkam.dds Banshee is a light gunship that can deal damage to land based units. It has very weak armor, that can be quickly shattered by T1 anti-air, so always send them in packs and scout before striking. It is a weapon of surprise, try to keep it away from your foe's radars. An effective attacking order is: nano towers -> AA towers and units -> eco and labs.",
	"armpeep.dds Peeper is a cheap and fast moving air scout, that is not armed with any weapons, but a huge line of sight. It is used to gain intelligence on what your enemy is planning, and where he keeps his most important units. In late-game a constant stream of scouts helps your artillery units, improving their aim.",
	"armthund.dds Thunder is a bomber, designed mainly for destroying buildings. A little bit weaker than its CORE counterpart - Shadow. It can strike every 9 seconds. Always scout first and combine with fighters to eliminate enemy's airwall before  bombing. Click A for attack and drag your RMB to execute a carpet bombing",
}

local quotes = {
	{"The two most powerful warriors are patience and time.", "Leo Tolstoy"},
	{"Know thy self, know thy enemy. A thousand battles, a thousand victories.", "Sun Tzu"},
	{"People never lie so much as after a hunt, during a war or before an election.", "Otto von Bismarck"},
	{"The best weapon against an enemy is another enemy.", "frederich Nietzsche"},
	{"Thus, what is of supreme importance in war is to attack the enemy's strategy.", "Sun Tzu"},
	{"Great is the guilt of an unnecessary war.", "John Adams"},
	{"I have never advocated war except as a means of peace.", "Ulysses S Grant"},
	{"War is not only a matter of equipment, artillery, group troops or air force; it is largely a matter of spirit, or morale.", "Chiang Kai-Shek"},
	{"I know not with what weapons World War III will be fought, but World War IV will be fought with sticks and stones.", "Albert Einstein"},
	{"In nuclear war all men are cremated equal.", "Dexter Gordon"},
	{"There are no absolute rules of conduct, either in peace or war. Everything depends on circumstances.", "Leon Trotsky"},
	{"Weapons are an important factor in war, but not the decisive one; it is man and not materials that counts.", "Mao Zedong"},
	{"To secure peace is to prepare for war.", "Carl von Clausewitz"},
	{"Quickness is the essence of the war.", "Sun Tzu"},
	{"The whole art of war consists of guessing at what is on the other side of the hill.", "Arthur Wellesley"},
	{"War is a game that is played with a smile. If you can't smile, grin. If you can't grin, keep out of the way till you can.", "Winston Churchill"},
	{"War can only be abolished through war, and in order to get rid of the gun it is necessary to take up the gun.", "Mao zedong"},
	{"The quickest way of ending a war is to lose it.", "George Orwell"},
	{"Heaven cannot brook two suns, nor earth two masters.", "Alaxander the great"},
	{"People always make war when they say they love peace.", "D H Lawrence"},
	{"This is totally awesome. Wow. great job guys!!", "Chris Taylor"},
	{"War is like love; it always finds a way.", "Bertolt Brecht"},
	{"Ten soldiers wisely led will beat a hundred without a head.", "Euripides"},
	{"In war there is no prize for runner-up.", "Lucius Annaeus Seneca"},
	{"I think there should be holy war against yoga classes.", "Werner herzog"},
	{"An army marches on its stomach.", "Napoleon Bonaparte"},
	{"It is fatal to enter any war without the will to win it.", "Douglas MacArthur"},
	{"You cannot simultaneously prevent and prepare for war.", "Albert Einstein"},
	{"Try not to become a man of success, but rather try to become a man of value.", "Albert Einstein"},
	{"Every failure is a step to success.", "William Whewell"},
	{"If everyone is moving forward together, then success takes care of itself.", "Henry Ford"},
	{"Failure is success if we learn from it.", "Malcolm Forbes"},
	{"It is no use saying, 'We are doing our best.' You have got to succeed in doing what is necessary.", "Winston Churchill"},
	{"Knowledge will give you power, but character respect.", "Bruce Lee"},
	{"In time of war the laws are silent.", "Marcus Tullius Cicero"},
	{"War is a contagion.", "Franklin D Roosevelt"},
	{"War is the unfolding of miscalculations.", "Barbara Tuchman"},
	{"Girl power is about loving yourself and having confidence and strength from within, so even if you're not wearing a sexy outfit, you feel sexy.", "Nicole Scherzinger"},
	{"The most common way people give up their power is by thinking they don't have any.", "Alice Walker"},
	{"Mastering others is strength. Mastering yourself is true power.", "Lao Tzu"},
	{"There is more power in unity than division.", "Emmanuel Cleaver"},
	{"I am not afraid of an army of lions led by a sheep; I am afraid of an army of sheep led by a lion.", "Alexander the Great"},
	{"The power of an air force is terrific when there is nothing to oppose it.", "Winston Churchill"},
	{"You must never underestimate the power of the eyebrow.", "Jack Black"},
	{"Common sense is not so common.", "Voltaire"},
	{"If everyone is thinking alike, then somebody isn't thinking.", "George S Patton"},
	{"Ignorance is bold and knowledge reserved.", "Thucydides"},
	{"Don't find fault, find a remedy.", "Henry Ford"},
	{"There is nothing impossible to him who will try.", "Alaxander the great"},
	{"Peace is produced by war", "Pierre Corneille"},
}


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

local random_tip_or_desc = unit_descs[((k/3) % #unit_descs) + 1]
if k%3 == 1 then
	random_tip_or_desc = tips[((math.ceil(k/3)) % #tips) + 1]
elseif k%3 == 2 then
	random_tip_or_desc = quotes[((math.ceil(k/3)) % #quotes) + 1]
end

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


	-- In this format, there can be an optional image before the tip/description.
	-- Any image ends in .dss, so if such a text piece is found, we extract that and show it as an image.
	local text_to_show = random_tip_or_desc
	if random_tip_or_desc[2] then
		text_to_show = random_tip_or_desc[1]
	else
		i, j = string.find(random_tip_or_desc, ".dds")
	end
	local numLines = 1
	local fontSize = barTextSize * 0.67
	local image_text = nil
	local image_size = 0.04
	local height = 0.1

	if i ~= nil then
		text_to_show = string.sub(text_to_show, j+2)
		local maxWidth = ((0.58-image_size-0.012) * vsx) * (loadedFontSize/fontSize)
		text_to_show, numLines = font:WrapText(text_to_show, maxWidth)
		local textHeight, textDescender = font:GetTextHeight(text_to_show)
		height = (textHeight+math.abs(textDescender)*fontSize) / vsy
		if height < image_size then
			height = image_size
		end
	else
		local maxWidth = (0.585 * vsx) * (loadedFontSize/fontSize)
		text_to_show, numLines = font:WrapText(text_to_show, maxWidth)
		local textHeight, textDescender = font:GetTextHeight(text_to_show)
		height = (textHeight+math.abs(textDescender)*fontSize) / vsy
	end


	height = 0.104	-- done manually cause height calcs are wrong still


	-- Tip/unit description
	-- Background
	gl.Color(0.06,0.06,0.06,0.8)
	RectRound(0.2-paddingW,0.69-height-paddingH,0.8+paddingW,0.69+paddingH,0.007)

	-- Text
	gl.PushMatrix()
	gl.Scale(1/vsx,1/vsy,1)

	if i ~= nil then
		image_text = string.sub(random_tip_or_desc, 0, j)
		gl.Texture(":n:unitpics/" .. image_text)
		gl.Color(1.0,1.0,1.0,0.8)
		gl.TexRect(vsx * 0.21, vsy*0.675, vsx*(0.21+image_size), (vsy*0.675)-(vsx*image_size))
		font:Print(text_to_show, vsx * (0.21+image_size+0.012) , vsy * 0.6725, fontSize, "oa")
	else
		font:Print(text_to_show, vsx * 0.21, vsy * 0.6725, fontSize, "oa")
	end

	if random_tip_or_desc[2] then
		font:Print('\255\255\222\155'..random_tip_or_desc[2], vsx * 0.79, (vsy * (0.6725-height)) +(fontSize*2.66) , fontSize, "oar")
	end
	gl.PopMatrix()
end


function addon.MousePress(...)
	--Spring.Echo(...)
end


function addon.Shutdown()
	gl.DeleteFont(font)
end
