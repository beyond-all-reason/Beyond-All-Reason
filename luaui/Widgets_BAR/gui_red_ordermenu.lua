
function widget:GetInfo()
	return {
	version   = "9.1",
	name      = "Red Order Menu",
	desc      = "Requires Red UI Framework",
	author    = "Regret, modified by CommonPlayer",
	date      = "29 may 2015", --modified by CommonPlayer, Oct 2016
	license   = "GNU GPL, v2 or later",
	layer     = -9,
	enabled   = true, --enabled by default
	handler   = true, --can use widgetHandler:x()
	}
end


local stateTexture		     = ":l:LuaUI/Images/resbar.dds"
local buttonTexture		     = ":l:LuaUI/Images/button.dds"
local barGlowCenterTexture = ":l:LuaUI/Images/barglow-center.png"
local barGlowEdgeTexture   = ":l:LuaUI/Images/barglow-edge.png"

local sound_queue_add = 'LuaUI/Sounds/buildbar_add.wav'
local sound_queue_rem = 'LuaUI/Sounds/buildbar_rem.wav'
local sound_button = 'LuaUI/Sounds/buildbar_waypoint.wav'

local NeededFrameworkVersion = 9
local CanvasX,CanvasY = 1272,734 --resolution in which the widget was made (for 1:1 size)
--1272,734 == 1280,768 windowed

--todo: build categories (eco | labs | defences | etc) basically sublists of buildcmds (maybe for regular orders too)

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)

local playSounds = true
local iconScaling = true
local highlightscale = true
local largeUnitIcons = false
local vsx,vsy = Spring.GetViewGeometry()
if (vsx/vsy) - 1.78 > 0.5 then
	largeUnitIcons = true
end

local mouseClicked = 0
local vsx, vsy = gl.GetViewSizes()
local widgetScale = (1 + (vsx*vsy / 7500000))

local normalOrderIconSize = {
	isx = 52,isy = 32, --icon size
	ix = 5,iy = 4, --icons x/y
}
local largeOrderIconSize = {
	isx = 62.5,isy = 32, --icon size
	ix = 5,iy = 4, --icons x/y
}
local Config = {
	ordermenu = {
		menuname = "ordermenu",
		px = 0,py = CanvasY - 415 - 145,
		isx = 45,isy = 33,
		ix = 5,iy = 4,
		
		roundedPercentage = 0.1,	-- 0.25 == iconsize / 4 == cornersize
		
		iconscale = 0.94,
		iconhoverscale = 0.94,
		ispreadx=0,ispready=0,
		
		margin = 5,
		
		padding = 3*widgetScale, -- for border effect
		color2 = {1,1,1,0.025}, -- for border effect
		
		fadetime = 0.1,
		fadetimeOut = 0.015, --fade effect time, in seconds
		
		ctext = {1,1,1,1},
		cbackground = {0,0,0,ui_opacity},
		cborder = {0,0,0,1},
		cbuttonbackground={0.1,0.1,0.1,1},
		
		dragbutton = {2,3}, --middle mouse button
		tooltip = {
			background = "In CTRL+F11 mode: Hold \255\255\255\1middle mouse button\255\255\255\255 to drag the ordermenu.",
		},
	},
}

function widget:ViewResize(newX,newY)
	vsx, vsy = gl.GetViewSizes()
	--if (vsx/vsy) - 1.78 > 0.5 then
	--	largeUnitIcons = true
	--end
	widgetScale = (1 + (vsx*vsy / 7500000))
	Config.ordermenu.padding = 3*widgetScale
end

local guishaderEnabled = WG['guishader'] or false

local sGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local sGetActiveCommand = Spring.GetActiveCommand
local sGetActiveCmdDescs = Spring.GetActiveCmdDescs
local ssub = string.sub

local function IncludeRedUIFrameworkFunctions()
	New = WG.Red.New(widget)
	Copy = WG.Red.Copytable
	SetTooltip = WG.Red.SetTooltip
	GetSetTooltip = WG.Red.GetSetTooltip
	Screen = WG.Red.Screen
	GetWidgetObjects = WG.Red.GetWidgetObjects
end

local function RedUIchecks()
	local color = "\255\255\255\1"
	local passed = true
	if (type(WG.Red)~="table") then
		Spring.Echo(color..widget:GetInfo().name.." requires Red UI Framework.")
		passed = false
	elseif (type(WG.Red.Screen)~="table") then
		Spring.Echo(color..widget:GetInfo().name..">> strange error.")
		passed = false
	elseif (WG.Red.Version < NeededFrameworkVersion) then
		Spring.Echo(color..widget:GetInfo().name..">> update your Red UI Framework.")
		passed = false
	end
	if (not passed) then
		widgetHandler:ToggleWidget(widget:GetInfo().name)
		return false
	end
	IncludeRedUIFrameworkFunctions()
	return true
end

local function AutoResizeObjects() --autoresize v2
	if (LastAutoResizeX==nil) then
		LastAutoResizeX = CanvasX
		LastAutoResizeY = CanvasY
	end
	local lx,ly = LastAutoResizeX,LastAutoResizeY
	local vsx,vsy = Screen.vsx,Screen.vsy
	if ((lx ~= vsx) or (ly ~= vsy)) then
		local objects = GetWidgetObjects(widget)
		local scale = vsy/ly
		local skippedobjects = {}
		for i=1,#objects do
			local o = objects[i]
			local adjust = 0
			if ((o.movableslaves) and (#o.movableslaves > 0)) then
				adjust = (o.px*scale+o.sx*scale)-vsx
				if (((o.px+o.sx)-lx) == 0) then
					o._moveduetoresize = true
				end
			end
			if (o.px) then o.px = o.px * scale end
			if (o.py) then o.py = o.py * scale end
			if (o.sx) then o.sx = o.sx * scale end
			if (o.sy) then o.sy = o.sy * scale end
			if (o.fontsize) then o.fontsize = o.fontsize * scale end
			if (adjust > 0) then
				o._moveduetoresize = true
				o.px = o.px - adjust
				for j=1,#o.movableslaves do
					local s = o.movableslaves[j]
					s.px = s.px - adjust/scale
				end
			elseif ((adjust < 0) and o._moveduetoresize) then
				o._moveduetoresize = nil
				o.px = o.px - adjust
				for j=1,#o.movableslaves do
					local s = o.movableslaves[j]
					s.px = s.px - adjust/scale
				end
			end
		end
		LastAutoResizeX,LastAutoResizeY = vsx,vsy
	end
end


local function CreateGrid(r)
	local background2 = {"rectanglerounded",
		px=r.px+r.padding,py=r.py+r.padding,
		sx=(r.isx*r.ix+r.ispreadx*(r.ix-1) +r.margin*2) -r.padding -r.padding,
		sy=(r.isy*(r.iy)+r.ispready*(r.iy) +r.margin*2) -r.padding -r.padding,
		color=r.color2,
		roundedsize=r.padding*1.45,
	}
	local background = {"rectanglerounded",
		px=r.px,py=r.py,
		sx=r.isx*r.ix+r.ispreadx*(r.ix-1) +r.margin*2,
		sy=r.isy*(r.iy)+r.ispready*(r.iy) +r.margin*2,
		color=r.cbackground,
		border=r.cborder,
		movable=r.dragbutton,
		obeyscreenedge = true,
		overrideclick = {1},
		padding=r.padding,

		guishader=true,
		effects = {
			fadein_at_activation = r.fadetime,
			fadeout_at_deactivation = r.fadetimeOut,
		},
		onupdate=function(self)
			background2.px = self.px + self.padding
			background2.py = self.py + self.padding
			background2.sx = self.sx - self.padding - self.padding
			background2.sy = self.sy - self.padding - self.padding
		end,
	}
	
	local selecthighlight = {"rectanglerounded",
		roundedsize = math.floor(r.isy*r.roundedPercentage),
		px=0,py=0,
		sx=r.isx,sy=r.isy,
		iconscale=(iconScaling and ((not highlightscale and r.menuname == "buildmenu") or r.menuname ~= "buildmenu") and r.iconscale or 1),
		color={0.85,0.65,0,0.25},
		border={0.8,0,0,0},
		glone=0.12,
		texture = "LuaUI/Images/button-pushed.dds",
		texturecolor={1,0,0,0.15},

		active=false,
		onupdate=function(self)
			self.active = false
		end,
	}
	
	local mouseoverhighlight = Copy(selecthighlight,true)
	mouseoverhighlight.color={1,1,1,0.08}
	mouseoverhighlight.border={1,1,1,0}
	mouseoverhighlight.texture = "LuaUI/Images/button-highlight.dds"
	mouseoverhighlight.texturecolor={1,1,1,0.08}
	
	local heldhighlight = Copy(selecthighlight,true)
	heldhighlight.color={1,0.75,0,0.06}
	heldhighlight.border={1,1,0,0}
	heldhighlight.texture = "LuaUI/Images/button-pushed.dds"
	heldhighlight.texturecolor={1,0.75,0,0.06}

	local icon = {"rectangle",
		px=0,py=0,
		sx=r.isx,sy=r.isy,
		iconscale=(iconScaling and r.iconscale or 1),
		iconhoverscale=(iconScaling and r.iconhoverscale or 1),
		iconnormalscale=(iconScaling and r.iconscale or 1),
		roundedsize = math.floor(r.isy*r.roundedPercentage),
		color={0,0,0,0},
		border={0,0,0,0},
		options="n", --disable colorcodes
		captioncolor=r.ctext,
		font2 = true,
		
		overridecursor = true,
		overrideclick = {3},

		mouseheld={
			{1,function(mx,my,self)
				self.iconscale=(iconScaling and self.iconhoverscale or 1)
				--if self.texture ~= nil and string.sub(self.texture, 1, 1) == '#' then
				--	heldhighlight.iconscale = (iconScaling and ((not highlightscale and r.menuname == "buildmenu") or r.menuname ~= "buildmenu") and self.iconhoverscale or 1)
				--else
				--	heldhighlight.iconscale = self.iconscale
				--end
				heldhighlight.iconscale = self.iconscale
				heldhighlight.color={1,0.75,0,0.06}
				heldhighlight.px = self.px
				heldhighlight.py = self.py
				heldhighlight.active = nil
			end},
			{3,function(mx,my,self)
				self.iconscale=(iconScaling and self.iconhoverscale or 1)
				--if self.texture ~= nil and string.sub(self.texture, 1, 1) == '#' then
				--	heldhighlight.iconscale = (iconScaling and ((not highlightscale and r.menuname == "buildmenu") or r.menuname ~= "buildmenu") and self.iconhoverscale or 1)
				--else
				--	heldhighlight.iconscale = self.iconscale
				--end
				heldhighlight.iconscale = self.iconscale
				heldhighlight.color={1,0.2,0,0.06}
				heldhighlight.px = self.px
				heldhighlight.py = self.py
				heldhighlight.active = nil
			end},
		},

		mouseover=function(mx,my,self)
			self.iconscale=(iconScaling and self.iconhoverscale or 1)
			--if self.texture ~= nil and string.sub(self.texture, 1, 1) == '#' then
			--	mouseoverhighlight.iconscale = (iconScaling and ((not highlightscale and r.menuname == "buildmenu") or r.menuname ~= "buildmenu") and self.iconhoverscale or 1)
			--else
				mouseoverhighlight.iconscale = self.iconscale
			--end
			mouseoverhighlight.px = self.px
			mouseoverhighlight.py = self.py
			mouseoverhighlight.active = nil
			SetTooltip(self.tooltip)

			mouseoverhighlight.texturecolor={1,1,1,0.02}
		end,

		onupdate=function(self)
			local _,_,_,curcmdname = sGetActiveCommand()
			self.iconscale= (iconScaling and self.iconnormalscale or 1)
			--selecthighlight.iconscale = (iconScaling and ((not highlightscale and r.menuname == "buildmenu") or r.menuname ~= "buildmenu") and self.iconhoverscale or 1)
			selecthighlight.iconscale = (iconScaling and self.iconhoverscale or 1)
			if (curcmdname ~= nil) then
				if (self.cmdname == curcmdname) then
					selecthighlight.px = self.px
					selecthighlight.py = self.py
					selecthighlight.active = nil
				end
			end
		end,
		
		effects = background.effects,
		
		active=false,
	}

	local text = {"rectangle",
		px,py = 0, 0,
		sx=r.isx,sy=r.isy,
		captioncolor={0.8,0.8,0.8,1},
		caption = nil,
		options = "on",
		--font2 = true,
	}
	New(background)
	New(background2)

	local backward = New(Copy(icon,true))
	backward.texture = "LuaUI/Images/backward.dds"

	local forward = New(Copy(icon,true))
	forward.texture = "LuaUI/Images/forward.dds"
	
	local indicator = New({"rectangle",
		px=0,py=0,
		sx=r.isx,sy=r.isy,
		captioncolor=r.ctext,
		options = "n",
		
		effects = background.effects,
	})
	background.movableslaves={backward,forward,indicator}

	local icons = {}
	local texts = {}
	for y=1,r.iy do
		for x=1,r.ix do
			local b = New(Copy(icon,true))
			b.px = background.px +r.margin + (x-1)*(r.ispreadx + r.isx)
			b.py = background.py +r.margin + (y-1)*(r.ispready + r.isy)
			background.movableslaves[#background.movableslaves+1] = b
			icons[#icons+1] = b

			b = New(Copy(text,true))
			b.px = background.px +r.margin + (x-1)*(r.ispreadx + r.isx)
			b.py = background.py +r.margin + (y-1)*(r.ispready + r.isy)
			background.movableslaves[#background.movableslaves+1] = b
			texts[#texts+1] = b

			if ((y==r.iy) and (x==r.ix)) then
				backward.px = icons[#icons-r.ix+1].px
				forward.px = icons[#icons].px
				indicator.px = (forward.px + backward.px)/2
				
				backward.py = icons[#icons-r.ix].py + r.isy + r.ispready
				forward.py = backward.py
				indicator.py = backward.py
			end
		end
	end
	
	local staterect = {"rectangle",
		border = r.cborder,
		texture = stateTexture,
		texturecolor = r.cborder,
		effects = background.effects,
	}
	local staterectangles = {}
	local staterectanglesglow = {}
	
	New(selecthighlight)
	New(mouseoverhighlight)
	New(heldhighlight)
	
	--tooltip
	background.mouseover = function(mx,my,self) SetTooltip(r.tooltip.background) end
	
	return {
		["menuname"] = r.menuname,
		["background"] = background,
		["background2"] = background2,
		["icons"] = icons,
		["backward"] = backward,
		["forward"] = forward,
		["indicator"] = indicator,
		["staterectangles"] = staterectangles,
		["staterectanglesglow"] = staterectanglesglow,
		["staterect"] = staterect,
		["texts"] = texts,
	}
end


local function UpdateGrid(g,cmds)
	if #cmds==0 then
		-- deactivate
		g.background.active = false
		g.background2.active = false
		g.backward.active = false
		g.forward.active = false
		g.indicator.active = false
		for i=1,#g.icons do
			g.icons[i].active = false
		end
		for i=1,#g.texts do
			g.texts[i].active = false
		end
		for i=1,#g.staterectangles do
			g.staterectangles[i].active = false
		end
		for i=1,#g.staterectanglesglow do
			g.staterectanglesglow[i].active = false
		end

	else
		-- activate
		g.background.active = nil
		g.background2.active = nil
		for i=1,#g.icons do
			g.icons[i].active = nil
		end
		for i=1,#g.texts do
			g.texts[i].active = nil
		end
		--for i=1,#g.staterectangles do
		--	g.staterectangles[i].active = nil
		--end
		--for i=1,#g.staterectanglesglow do
		--	g.staterectanglesglow[i].active = nil
		--end

		local curpage = g.page
		local icons = g.icons
		local page = {{}}


		local visibleIconCount = #icons
		if #cmds > #icons then
			visibleIconCount = visibleIconCount - Config[g.menuname].ix
		end
		for i=1,#cmds do
			local index = i-(#page-1)*visibleIconCount
			page[#page][index] = cmds[i]
			if ((i == (visibleIconCount*#page)) and (i~=#cmds)) then
				page[#page+1] = {}
			end
		end
		g.pagecount = #page


		if (curpage > g.pagecount) then
			curpage = 1
		end

		local iconsleft = (#icons-#page[curpage])
		if (iconsleft > 0) then
			for i=iconsleft+#page[curpage],#page[curpage]+1,-1 do
				icons[i].active = false --deactivate
			end
		end

		for i=1,#g.staterectangles do
			g.staterectangles[i].active = false
		end
		local usedstaterectangles = 0

		for i=1,#g.staterectanglesglow do
			g.staterectanglesglow[i].active = false
		end
		local usedstaterectanglesglow = 0

		for i=1,#g.texts do
			local text = g.texts[i]
			text.caption = nil
		end

		for i=1,#page[curpage] do
			local cmd = page[curpage][i]
			local icon = icons[i]
			icon.tooltip = cmd.tooltip
			icon.active = nil --activate
			icon.cmdname = cmd.name
			icon.cmdid = cmd.id
			icon.texture = nil
			if (cmd.texture) then
				if (cmd.texture ~= "") then
					icon.texture = cmd.texture
				end
			end
			if (cmd.disabled) then
				icon.texturecolor = {0.44,0.44,0.44,1}
			else
				icon.texturecolor = {1,1,1,1}
			end

			icon.mouseclick = {
				{1,function(mx,my,self)
					mouseClicked = 2
					if playSounds then
						Spring.PlaySoundFile(sound_queue_add, 0.75, 'ui')
					end
					Spring.SetActiveCommand(Spring.GetCmdDescIndex(cmd.id),1,true,false,Spring.GetModKeyState())
				end},
				{3,function(mx,my,self)
					mouseClicked = 2
					if playSounds then
						Spring.PlaySoundFile(sound_queue_rem, 0.75, 'ui')
					end
					Spring.SetActiveCommand(Spring.GetCmdDescIndex(cmd.id),3,false,true,Spring.GetModKeyState())
				end},
			}

			icon.texture = buttonTexture

			if (cmd.type == 5) then --state cmds (fire at will, etc)
				icon.caption = (cmd.params[cmd.params[1]+2] or cmd.name)
				if string.len(icon.caption) < 4 then
					icon.caption = "     "..icon.caption.."     "
				elseif string.len(icon.caption) < 5 then
					icon.caption = "  "..icon.caption.."  "
				elseif string.len(icon.caption) < 7 then
					icon.caption = "  "..icon.caption.."  "
				else
					icon.caption = " "..icon.caption.." "
				end
				local statecount = #cmd.params-1 --number of states for the cmd
				local curstate = cmd.params[1]+1

				local scale = icon.iconscale * 0.9
				local px = icon.px + ((icon.sx * (1-scale))/2)
				local py = icon.py + ((icon.sy * (1-scale))/2)
				local sx = icon.sx * scale
				local sy = icon.sy * scale
				local usr = nil

				for i=1,statecount do
					usedstaterectangles = usedstaterectangles + 1
					local s = g.staterectangles[usedstaterectangles]
					if (s == nil) then
						s = New(Copy(g.staterect,true))
						g.staterectangles[usedstaterectangles] = s
						g.background.movableslaves[#g.background.movableslaves+1] = s
					end
					s.active = nil --activate


					local spread = 7
					s.sx = (sx-(spread*(statecount-1+2)))/statecount
					s.sy = (sy/8.5)
					s.px = px+spread + (s.sx+spread)*(i-1)
					s.py = py + sy - s.sy - spread

					--s.sx = (icon.sx-(spread*(statecount-1+2)))/statecount
					--s.sy = (icon.sy/7)
					--s.px = icon.px+spread + (s.sx+spread)*(i-1)
					--s.py = icon.py + icon.sy - s.sy -spread
					s.border = {0.22,0.22,0.22,0.8}

					if (i == curstate) then
						usr = usedstaterectangles
						if (statecount < 4) then
							if (i == 1) then
								s.color = {0.93,0,0,1}
								s.border = {0.93,0,0,1}
							elseif (i == 2) then
								if (statecount == 3) then
									s.color = {0.93,0.93,0,1}
									s.border = {0.93,0.93,0,1}
								else
									s.color = {0,0.93,0,1}
									s.border = {0,0.93,0,1}
								end
							elseif (i == 3) then
								s.color = {0,0.93,0,1}
								s.border = {0,0.93,0,1}
							end
						else
							s.color = {0.93,0.93,0.93,1}
							s.border = {0.93,0.93,0.93,1}
						end
						s.border[4] = 0.3
					else
						s.color = nil
					end
					if s.color == nil then
						s.texturecolor = s.border
					else
						s.texturecolor = s.color
					end
				end

				-- add glow for current state
				if (g.staterectangles[usr] ~= nil) then
					s = g.staterectangles[usr]
					usedstaterectanglesglow = usedstaterectanglesglow + 1
					local s2 = g.staterectanglesglow[usedstaterectanglesglow]
					if (s2 == nil) then
						s2 = New(Copy(g.staterectangles[usr],true))
						g.staterectanglesglow[usedstaterectanglesglow] = s2
						g.background.movableslaves[#g.background.movableslaves+1] = s2
					end

					local glowSize = s.sy * 6
					s2.sy = s.sy + glowSize + glowSize
					s2.py = s.py - glowSize
					s2.px = s.px
					s2.sx = s.sx
					s2.texture = barGlowCenterTexture
					s2.border = {0,0,0,0}
					s2.color = {s.color[1] * 10, s.color[2] * 10, s.color[3] * 10, 0}
					s2.texturecolor = {s.texturecolor[1] * 10, s.texturecolor[2] * 10, s.texturecolor[3] * 10, 0.11}
					s2.active = true

					usedstaterectanglesglow = usedstaterectanglesglow + 1
					local s3 = g.staterectanglesglow[usedstaterectanglesglow]
					if (s3 == nil) then
						s3 = New(Copy(s2,true))
						g.staterectanglesglow[usedstaterectanglesglow] = s3
						g.background.movableslaves[#g.background.movableslaves+1] = s3
					end
					s3.sy = s.sy + glowSize + glowSize
					s3.py = s.py - glowSize
					s3.px = s.px - (glowSize * 2)
					s3.sx = (glowSize * 2)
					s3.texture = barGlowEdgeTexture
					s3.border = s2.border
					s3.color = s2.color
					s3.texturecolor = s2.texturecolor
					s3.active = true

					usedstaterectanglesglow = usedstaterectanglesglow + 1
					local s4 = g.staterectanglesglow[usedstaterectanglesglow]
					if (s4 == nil) then
						s4 = New(Copy(s2,true))
						g.staterectanglesglow[usedstaterectanglesglow] = s4
						g.background.movableslaves[#g.background.movableslaves+1] = s4
					end
					s4.sy = s.sy + glowSize + glowSize
					s4.py = s.py - glowSize
					s4.px = s.px + s.sx + (glowSize * 2)
					s4.sx = -(glowSize * 2)
					s4.texture = barGlowEdgeTexture
					s4.border = s2.border
					s4.color = s2.color
					s4.texturecolor = s2.texturecolor
					s4.active = true

				end
			else
				if string.len(cmd.name) < 4 then
					icon.caption = "   "..cmd.name.."   "
				elseif string.len(cmd.name) < 7 then
					icon.caption = "  "..cmd.name.."  "
				else
					icon.caption = " "..cmd.name.." "
				end
			end

		end

		if (#page>1) then
			g.forward.mouseclick={
				{1,function(mx,my,self)
					g.page = g.page + 1
					if (g.page > g.pagecount) then
						g.page = 1
					end
					UpdateGrid(g,cmds)
					if playSounds then
						Spring.PlaySoundFile(sound_button, 0.6, 'ui')
					end
				end},
			}
			g.backward.mouseclick={
				{1,function(mx,my,self)
					g.page = g.page - 1
					if (g.page < 1) then
						g.page = g.pagecount
					end
					UpdateGrid(g,cmds)
					if playSounds then
						Spring.PlaySoundFile(sound_button, 0.6, 'ui')
					end
				end},
			}
			g.backward.active = nil --activate
			g.forward.active = nil
			g.indicator.active = nil
			g.indicator.caption = "   "..curpage.." / "..#page.."   "
		else
			g.backward.active = false
			g.forward.active = false
			g.indicator.active = false
		end
	end
end

function tableMerge(t1, t2)
	for k,v in pairs(t2) do
		if type(v) == "table" then
			if type(t1[k] or false) == "table" then
				tableMerge(t1[k] or {}, t2[k] or {})
			else
				t1[k] = v
			end
		else
			t1[k] = v
		end
	end
	return t1
end

function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end


function widget:Initialize()
	if WG['Red'].font then
		font = WG['Red'].font
	end

	if WG['red_buildmenu'] and WG['red_buildmenu'].getConfigLargeUnitIcons then
		largeUnitIcons = WG['red_buildmenu'].getConfigLargeUnitIcons()
	end

	PassedStartupCheck = RedUIchecks()
	if (not PassedStartupCheck) then return end

	if largeUnitIcons then
		Config.ordermenu = tableMerge(deepcopy(Config.ordermenu), deepcopy(largeOrderIconSize))
	else
		Config.ordermenu = tableMerge(deepcopy(Config.ordermenu), deepcopy(normalOrderIconSize))
	end

	ordermenu = CreateGrid(Config.ordermenu)
	ordermenu.page = 1

	AutoResizeObjects() --fix for displacement on crash issue

end


local function onWidgetUpdate() --function widget:Update()
	AutoResizeObjects()
end

--save/load stuff
--currently only position
function widget:GetConfigData() --save config
	if (PassedStartupCheck) then
		local vsy = Screen.vsy
		local unscale = CanvasY/vsy --needed due to autoresize, stores unresized variables
		--Config.ordermenu.px = ordermenu.background.px * unscale
		--Config.ordermenu.py = ordermenu.background.py * unscale
		return {Config=Config}
	end
end
function widget:SetConfigData(data) --load config
	if (data.Config ~= nil) then
		Config.ordermenu.px = data.Config.ordermenu.px
		Config.ordermenu.py = data.Config.ordermenu.py
	end
	if (data.largeUnitIcons ~= nil) then
		largeUnitIcons = data.largeUnitIcons
	end
	if (data.iconScaling ~= nil) then
		iconScaling = data.iconScaling
	end
end


function widget:Shutdown()

end

local function GetCommands()
	local hiddencmds = {
		[76] = true, --load units clone
		[65] = true, --selfd
		[9] = true, --gatherwait
		[8] = true, --squadwait
		[7] = true, --deathwait
		[6] = true, --timewait
		[39812] = true, --raw move
		[34922] = true, -- set unit target
		--[34923] = true, -- set target
	}
	local statecmds = {}
	local othercmds = {}
	local statecmdscount = 0
	local othercmdscount = 0
	for index,cmd in pairs(sGetActiveCmdDescs()) do
		if (type(cmd) == "table") then
			if (
			(not hiddencmds[cmd.id]) and
			(cmd.action ~= nil) and
			--(not cmd.disabled) and
			(cmd.type ~= 21) and
			(cmd.type ~= 18) and
			(cmd.type ~= 17)
			) then
				if (((cmd.type == 20) --build building
				or (ssub(cmd.action,1,10) == "buildunit_"))) and (cmd["disabled"] ~= true) then


				elseif (cmd.type == 5) and (cmd["disabled"] ~= true) then
					statecmdscount = statecmdscount + 1
					statecmds[statecmdscount] = cmd
				elseif (cmd["disabled"] ~= true) then
					othercmdscount = othercmdscount + 1
					othercmds[othercmdscount] = cmd
				end
			end
		end
	end
	local tempcmds = {}
	for i=1,statecmdscount do
		tempcmds[i] = statecmds[i]
	end
	for i=1,othercmdscount do
		tempcmds[i+statecmdscount] = othercmds[i]
	end
	othercmdscount = othercmdscount + statecmdscount
	othercmds = tempcmds
	
	return othercmds
end



local selectionChanged = true
local function onNewCommands(force)
	local othercmds = {}
	if selectionChanged or force then
		if (SelectedUnitsCount==0) then
			ordermenu.page = 1
		else
			othercmds = GetCommands()
		end
		UpdateGrid(ordermenu,othercmds)
		selectionChanged = false
	end
end

local function updateGrids()
	local othercmds = {}
	if (SelectedUnitsCount == 0) then
		ordermenu.page = 1
	else
		othercmds = GetCommands()
	end
	UpdateGrid(ordermenu,othercmds)
end

local sec = 0
local queueUpdateSec = 0
local guishaderCheckInterval = 1
local uiOpacitySec = 0
function widget:Update(dt)
	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec>0.5 then
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
			ordermenu.background.color = {0,0,0,ui_opacity}
			ordermenu.background2.color = {1,1,1,ui_opacity*0.055}
		end
	end
	sec=sec+dt
	if (sec>1/guishaderCheckInterval) then
		sec = 0
		if (WG['guishader'] ~= guishaderEnabled) then
			guishaderEnabled = WG['guishader']
			if (guishaderEnabled) then
				Config.ordermenu.fadetimeOut = 0.02
			else
				Config.ordermenu.fadetimeOut = Config.ordermenu.fadetime*0.66
			end
		end
	end
	onWidgetUpdate()


	-- hijacking spring layout only works for the buildmenu so we always run the code below
	onNewCommands(mouseClicked>0)
	mouseClicked = mouseClicked-1
	if (SelectedUnitsCount == 0) then
		onNewCommands() --flush
	end
	if mouseClicked == -1 then
		updateGrids()
	end
end


function widget:SelectionChanged(sel)
	selectionChanged = true
	SelectedUnitsCount = sGetSelectedUnitsCount()
end

