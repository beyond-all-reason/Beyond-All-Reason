function widget:GetInfo()
	return {
	version   = "9.1",
	name      = "Red Build/Order Menu",
	desc      = "Requires Red UI Framework",
	author    = "Regret, modified by CommonPlayer",
	date      = "29 may 2015", --modified by CommonPlayer, Oct 2016
	license   = "GNU GPL, v2 or later",
	layer     = 0,
	enabled   = true, --enabled by default
	handler   = true, --can use widgetHandler:x()
	}
end

-- build hotkeys stuff
local building = -1
local buildStartKey = 98
local buildNextKey = 110
local buildKeys = {113, 119, 101, 114, 116, 97, 115, 100, 102, 103, 122, 120, 99, 118, 98}
local buildLetters = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"}

local stateTexture		     = "LuaUI/Images/resbar.dds"
local buttonTexture		     = "LuaUI/Images/button.dds"
local barGlowCenterTexture = ":n:LuaUI/Images/barglow-center.png"
local barGlowEdgeTexture   = ":n:LuaUI/Images/barglow-edge.png"

local oldUnitpicsDir   = "unitpics/"

local sound_queue_add = 'LuaUI/Sounds/buildbar_add.wav'
local sound_queue_rem = 'LuaUI/Sounds/buildbar_rem.wav'
local sound_button = 'LuaUI/Sounds/buildbar_waypoint.wav'

local iconTypesMap = {}
local NeededFrameworkVersion = 9
local CanvasX,CanvasY = 1272,734 --resolution in which the widget was made (for 1:1 size)
--1272,734 == 1280,768 windowed

--todo: build categories (eco | labs | defences | etc) basically sublists of buildcmds (maybe for regular orders too)

local ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)

local playSounds = true
local iconScaling = true
local highlightscale = true
local drawPrice = true
local drawTooltip = true
local drawBigTooltip = false
local drawRadaricon = true
local largePrice = true
local shortcutsInfo = false
local oldUnitpics = false
local largeUnitIcons = true

local vsx, vsy = gl.GetViewSizes()
local widgetScale = (1 + (vsx*vsy / 7500000))

local normalUnitIconSize = {
	isx = 41,isy = 41, --icon size
	ix = 5,iy = 8, --icons x/y
}
local largeUnitIconSize = {
	isx = 47,isy = 47, --icon size
	ix = 5,iy = 7, --icons x/y
}
local normalOrderIconSize = {
	isx = 41,isy = 33, --icon size
	ix = 5,iy = 4, --icons x/y
}
local largeOrderIconSize = {
	isx = 47,isy = 33, --icon size
	ix = 5,iy = 4, --icons x/y
}
local Config = {
	buildmenu = {
		menuname = "buildmenu",
		px = 0,py = CanvasY - 415, --default start position
		
		isx = 45,isy = 40, --icon size
		ix = 5,iy = 8, --icons x/y
		
		roundedPercentage = 0.2,	-- 0.25 == iconsize / 4 == cornersize
		
		iconscale = 0.91,
		iconhoverscale = 0.91,
		ispreadx=0,ispready=0, --space between icons
		
		margin = 5, --distance from background border
		
		padding = 3*widgetScale, -- for border effect
		color2 = {1,1,1,ui_opacity*0.04}, -- for border effect
		
		fadetime = 0.14, --fade effect time, in seconds
		fadetimeOut = 0.022, --fade effect time, in seconds
		
		ctext = {1,1,1,1}, --color {r,g,b,alpha}
		cbackground = {0,0,0,ui_opacity},
		cborder = {0,0,0,1},
		cbuttonbackground = {0.1,0.1,0.1,1},
		dragbutton = {2,3}, --middle mouse button
		tooltip = {
			background = "In CTRL+F11 mode: Hold \255\255\255\1middle mouse button\255\255\255\255 to drag the buildmenu.",
		},
	},
	
	ordermenu = {
		menuname = "ordermenu",
		px = 0,py = CanvasY - 415 - 145,
		
		isx = 45,isy = 33,
		ix = 5,iy = 4,
		
		roundedPercentage = 0.2,	-- 0.25 == iconsize / 4 == cornersize
		
		iconscale = 0.93,
		iconhoverscale = 0.93,
		ispreadx=0,ispready=0,
		
		margin = 5,
		
		padding = 3*widgetScale, -- for border effect
		color2 = {1,1,1,0.025}, -- for border effect
		
		fadetime = 0.14,
		fadetimeOut = 0.022, --fade effect time, in seconds
		
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
	widgetScale = (1 + (vsx*vsy / 7500000))
	Config.buildmenu.padding = 3*widgetScale
	Config.ordermenu.padding = 3*widgetScale
end

local guishaderEnabled = WG['guishader_api'] or false

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

local function esc(x)
   return (x:gsub('%%', '%%%%')
            :gsub('^%^', '%%^')
            :gsub('%$$', '%%$')
            :gsub('%(', '%%(')
            :gsub('%)', '%%)')
            :gsub('%.', '%%.')
            :gsub('%[', '%%[')
            :gsub('%]', '%%]')
            :gsub('%*', '%%*')
            :gsub('%+', '%%+')
            :gsub('%-', '%%-')
            :gsub('%?', '%%?'))
end

function wrap(str, limit)
	limit = limit or 72
	local here = 1
	local buf = ""
	local t = {}
	str:gsub("(%s*)()(%S+)()",
		function(sp, st, word, fi)
			if fi-here > limit then
				--# Break the line
				here = st
				t[#t+1] = buf
				buf = word
			else
				buf = buf..sp..word  --# Append
			end
		end)
	--# Tack on any leftovers
	if(buf ~= "") then
		t[#t+1] = buf
	end
	return t
end
	WG.hoverID = nil
local function CreateGrid(r)

	local background2 = {"rectanglerounded",
		px=r.px+r.padding,py=r.py+r.padding,
		sx=(r.isx*r.ix+r.ispreadx*(r.ix-1) +r.margin*2) -r.padding -r.padding,
		sy=(r.isy*(r.iy)+r.ispready*(r.iy) +r.margin*2) -r.padding -r.padding,
		color=r.color2,
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

	local queuetext = {"rectangle",
		px=0,py=0,
		sx=r.isx,sy=r.isy,
		iconscale=(iconScaling and r.iconscale or 1),
		iconhoverscale=(iconScaling and r.iconhoverscale or 1),
		iconnormalscale=(iconScaling and r.iconscale or 1),
		color={0,0,0,0},
		border={0,0,0,0},
		options="onr",
		captioncolor={1,0.7,0.3,1},
	}
	local radaricon = {"rectangle",
		px=0,py=0,
		sx=r.isx,sy=r.isy,
		iconscale=(iconScaling and r.iconscale or 1),
		iconhoverscale=(iconScaling and r.iconhoverscale or 1),
		iconnormalscale=(iconScaling and r.iconscale or 1),
		color={0,0,0,0},
		border={0,0,0,0},
		options="n",
		texturecolor={0.77,0.77,0.77,1},
	}
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
		
			--[[mouserelease={
			{1,function(mx,my,self)
				if r.menuname == "buildmenu" then
					self.iconscale=(iconScaling and self.iconhoverscale or 1)
					if self.texture ~= nil and string.sub(self.texture, 1, 1) == '#' then
						heldhighlight.iconscale = (iconScaling and ((not highlightscale and r.menuname == "buildmenu") or r.menuname ~= "buildmenu") and self.iconhoverscale or 1)
					else
						heldhighlight.iconscale = self.iconscale
					end
					heldhighlight.px = self.px
					heldhighlight.py = self.py
					heldhighlight.active = nil
				end
			end},
		},]]--
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
			local tt = self.tooltip
			if r.menuname == "buildmenu" then
				if self.texture ~= nil and self.udid then--string.sub(self.texture, 1, 1) == '#' then
					local udefid = self.udid	--tonumber(string.sub(self.texture, 2))
					WG.hoverID = udefid
                    local alt, ctrl, meta, shift = Spring.GetModKeyState()
                    if not meta and drawTooltip and WG['tooltip'] ~= nil then
                        local text = "\255\215\255\215"..UnitDefs[udefid].humanName.."\n\255\240\240\240"
                        if drawBigTooltip and UnitDefs[udefid].customParams.description_long ~= nil then
                            local lines = wrap(UnitDefs[udefid].customParams.description_long, 58)
                            local description = ''
                            local newline = ''
                            for i, line in ipairs(lines) do
                                description = description..newline..line
                                newline = '\n'
                            end
                            text = text..description
                        else
                            text = text..UnitDefs[udefid].tooltip
                        end
                        WG['tooltip'].ShowTooltip('redui_buildmenu', text)
                        tt = string.gsub(tt, esc("Build: "..UnitDefs[udefid].humanName.." - "..UnitDefs[udefid].tooltip).."\n", "")
                    end
				end
			end
			if drawPrice and tt ~= nil then
			  tt = string.gsub(tt, "Metal cost %d*\nEnergy cost %d*\n", "")
			end
			SetTooltip(tt)
			if r.menuname == "ordermenu" then
				mouseoverhighlight.texturecolor={1,1,1,0.02}
			end
			--[[
			if r.menuname == "buildmenu" then
				local CurMouseState = {Spring.GetMouseState()} --{mx,my,m1,m2,m3}
				if CurMouseState[3] or CurMouseState[5] then
					if self.cmdid ~= nil then
						Spring.SetActiveCommand(Spring.GetCmdDescIndex(self.cmdid),1,true,false,Spring.GetModKeyState())
					end
				end
			end]]--
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
	local queuetexts = {}
	local radaricons = {}
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

			b = New(Copy(queuetext,true))
			b.px = background.px +r.margin + (x-1)*(r.ispreadx + r.isx) + b.sx -(r.margin*1.4)
			b.py = background.py + r.margin + (y-1)*(r.ispready + r.isy) - (r.margin*0.2)
			b.py = b.py - (b.sy/4.7)
			background.movableslaves[#background.movableslaves+1] = b
			queuetexts[#queuetexts+1] = b

			local iconsize = 0.28
			b = New(Copy(radaricon,true))
			b.px = background.px +r.margin + (x-1)*(r.ispreadx + r.isx) + b.sx*(1-iconsize) -(r.margin/1.33)
			b.py = background.py +r.margin + (y-1)*(r.ispready + r.isy) -(r.margin/1.33) +(b.sy*(1-iconsize))
			b.sx = b.sx*iconsize
			b.sy = b.sy*iconsize
			background.movableslaves[#background.movableslaves+1] = b
			radaricons[#radaricons+1] = b
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
		["radaricons"] = radaricons,
		["queuetexts"] = queuetexts,
	}
end


local function UpdateGrid(g,cmds,ordertype)
	if (#cmds==0) then
		g.background.active = false
		g.background2.active = false
	else
		g.background.active = nil
		g.background2.active = nil
	end

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
	for i=1,#g.radaricons do
		g.radaricons[i].texture = nil
	end
	for i=1,#g.queuetexts do
		g.queuetexts[i].caption = nil
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
				if playSounds then
					Spring.PlaySoundFile(sound_queue_add, 0.75, 'ui')
				end
				Spring.SetActiveCommand(Spring.GetCmdDescIndex(cmd.id),1,true,false,Spring.GetModKeyState())
			end},
			{3,function(mx,my,self)
				if playSounds then
					Spring.PlaySoundFile(sound_queue_rem, 0.75, 'ui')
				end
				Spring.SetActiveCommand(Spring.GetCmdDescIndex(cmd.id),3,false,true,Spring.GetModKeyState())
			end},
		}
		
		if (ordertype == 1) then --build icons
			if Spring.GetModOptions ~= nil and (tonumber(Spring.GetModOptions().barmodels) or 0) == 1 and oldUnitpics and UnitDefs[cmd.id*-1] ~= nil and VFS.FileExists(oldUnitpicsDir..UnitDefs[cmd.id*-1].name..'.dds') then
				icon.texture = oldUnitpicsDir..UnitDefs[cmd.id*-1].name..'.dds'
			else
				icon.texture = "#"..cmd.id*-1
			end
			icon.udid = cmd.id*-1

			if (cmd.params[1]) then
				icon.options = "o"
				--icon.caption = "    "..cmd.params[1].."  "
				local color = "\255\190\255\190"
				if tonumber(cmd.params[1]) < 10 then
					g.queuetexts[i].caption = color.."        "..cmd.params[1]
				elseif tonumber(cmd.params[1]) < 100 then
					g.queuetexts[i].caption = color.."       "..cmd.params[1]
				else
					g.queuetexts[i].caption = color.."      "..cmd.params[1]
				end
			else
				icon.caption = nil
				g.queuetexts[i].caption = nil
			end
			icon.texturecolor = {0.95,0.95,0.95,1}
			
			--text to show build hotkey
			local white = "\255\255\255\255"
			local offwhite = "\255\222\222\222"
			local yellow = "\255\255\255\0"
			local orange = "\255\255\135\0"
			local green = "\255\0\255\0"
			local red = "\255\255\0\0"
			local skyblue = "\255\136\197\226"
			local s, e = string.find(cmd.tooltip, "Metal cost %d*")
			local metalCost = string.sub(cmd.tooltip, s + 11, e)
			local s, e = string.find(cmd.tooltip, "Energy cost %d*")
			local energyCost = string.sub(cmd.tooltip, s + 12, e)
			--local metalColor = "\255\136\197\226"
			--Spring.Echo('m'..metalCost..'e'..energyCost)
			
			if (not cmd.disabled) then
				local text = g.texts[i]
				text.px = icon.px+(icon.sy/100)
				text.py = icon.py+(icon.sy/60)
				
				local captionColor = "\255\175\175\175"
				
	-- If you don't want to display the metal or energy cost on the unit buildicon, then you can disable it here
				
				
				local shotcutCaption = ''
				if shortcutsInfo then
					if i <= 15 then
						if building == 0 then
							captionColor = skyblue
						end
						shotcutCaption = captionColor.."  "..buildLetters[buildStartKey-96].."→"..buildLetters[buildKeys[i]-96]
					elseif i <= 30 then
						if building == 1 then
							captionColor = skyblue
						end
						shotcutCaption = captionColor.."  "..buildLetters[buildNextKey-96].."→"..buildLetters[buildKeys[i-15]-96]
					end
				end
				
				if not drawPrice then
					text.caption = ""..shotcutCaption.."\n\n\n\n"
				else
					-- redui adjusts position based on text length, so adding spaces helps us putting it at the left side of the icon
					local str = tostring(math.max(metalCost, energyCost))
					local addedSpaces = "                 "			-- too bad 1 space isnt as wide as 1 number in the used font
					local infoNewline = '\n'
					if largePrice then
						addedSpaces =   "                "			-- too bad 1 space isnt as wide as 1 number in the used font
						infoNewline = ''
						metalCost = '  '..metalCost
						energyCost = '  '..energyCost
					end
					if tonumber(energyCost) < 10 then
						energyCost = energyCost .. '       '
					elseif tonumber(energyCost) < 100 then
						energyCost = energyCost .. '    '
					elseif tonumber(energyCost) < 1000 then
						energyCost = energyCost .. '  '
					elseif tonumber(energyCost) < 10000 then
						energyCost = energyCost .. ' '
					end
					for digit in string.gmatch(str, "%d") do
					  addedSpaces = string.sub(addedSpaces, 0, -2)
					end
					text.caption = ""..shotcutCaption.."\n\n\n"..infoNewline..'\255\240\240\240'..metalCost.."\n"..yellow..energyCost..addedSpaces
				end
				text.options = "bs"
				if drawRadaricon then
					g.radaricons[i].texture = iconTypesMap[UnitDefs[icon.udid].iconType]
				end
			end
		else
			if buttonTexture ~= nil then
				icon.texture = buttonTexture
			end
			if (cmd.type == 5) then --state cmds (fire at will, etc)
				icon.caption = " "..(cmd.params[cmd.params[1]+2] or cmd.name).." "
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
				UpdateGrid(g,cmds,ordertype)
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
				UpdateGrid(g,cmds,ordertype)
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


function widget:TextCommand(command)
	if (string.find(command, "iconspace") == 1  and  string.len(command) == 9) then 
		iconScaling = not iconScaling
		--AutoResizeObjects()
		Spring.ForceLayoutUpdate()
		if iconScaling then
			Spring.Echo("Build/order menu icon spacing:  enabled")
		else
			Spring.Echo("Build/order menu icon spacing:  disabled")
		end
	end
	if (string.find(command, "icontooltip") == 1  and  string.len(command) == 11) then
		drawTooltip = not drawTooltip
		--AutoResizeObjects()
		Spring.ForceLayoutUpdate()
		if drawTooltip then
			Spring.Echo("Build menu icon tooltip:  enabled")
		else
			Spring.Echo("Build menu icon tooltip:  disabled")
		end
	end
	if (string.find(command, "iconbigtooltip") == 1  and  string.len(command) == 14) then
		drawBigTooltip = not drawBigTooltip
		--AutoResizeObjects()
		Spring.ForceLayoutUpdate()
		if drawBigTooltip then
			Spring.Echo("Build menu icon tooltip:  enabled")
		else
			Spring.Echo("Build menu icon tooltip:  disabled")
		end
	end
	if (string.find(command, "iconprice") == 1  and  string.len(command) == 9) then 
		drawPrice = not drawPrice
		--AutoResizeObjects()
		Spring.ForceLayoutUpdate()
		if drawPrice then
			Spring.Echo("Build/order menu icon price:  enabled")
		else
			Spring.Echo("Build/order menu icon price:  disabled")
		end
	end
	if (string.find(command, "iconpricesize") == 1  and  string.len(command) == 13) then
		largePrice = not largePrice
		--AutoResizeObjects()
		Spring.ForceLayoutUpdate()
		if largePrice then
			Spring.Echo("Build/order menu icon info:  large")
		else
			Spring.Echo("Build/order menu icon info:  small")
		end
	end
	if (string.find(command, "olduniticons") == 1  and  string.len(command) == 12) then
		oldUnitpics = not oldUnitpics
		--AutoResizeObjects()
		Spring.ForceLayoutUpdate()
		if oldUnitpics then
			Spring.Echo("Using old unit icons in buildmenu")
		else
			Spring.Echo("Not using old unit icons in buildmenu")
		end
	end
	if (string.find(command, "iconinfokeys") == 1  and  string.len(command) == 12) then 
		shortcutsInfo = not shortcutsInfo
		--AutoResizeObjects()
		Spring.ForceLayoutUpdate()
		if shortcutsInfo then
			Spring.Echo("Build/order menu icon shortcut info:  enabled")
		else
			Spring.Echo("Build/order menu icon shortcut info:  disabled")
		end
	end
	if (string.find(command, "buildmenusounds") == 1  and  string.len(command) == 15) then
		playSounds = not playSounds
		--AutoResizeObjects()
		Spring.ForceLayoutUpdate()
		if playSounds then
			Spring.Echo("Build/order menu sounds:  enabled")
		else
			Spring.Echo("Build/order menu sounds:  disabled")
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
	if Script.LuaRules('GetIconTypes') then
		iconTypesMap = Script.LuaRules.GetIconTypes()
	end

	PassedStartupCheck = RedUIchecks()
	if (not PassedStartupCheck) then return end

	if largeUnitIcons then
		Config.buildmenu = tableMerge(deepcopy(Config.buildmenu), deepcopy(largeUnitIconSize))
		Config.ordermenu = tableMerge(deepcopy(Config.ordermenu), deepcopy(largeOrderIconSize))
	else
		Config.buildmenu = tableMerge(deepcopy(Config.buildmenu), deepcopy(normalUnitIconSize))
		Config.ordermenu = tableMerge(deepcopy(Config.ordermenu), deepcopy(normalOrderIconSize))
	end

	ordermenu = CreateGrid(Config.ordermenu)
	ordermenu.page = 1
	buildmenu = CreateGrid(Config.buildmenu)
	buildmenu.page = 1

	AutoResizeObjects() --fix for displacement on crash issue


  WG['red_buildmenu'] = {}
  WG['red_buildmenu'].getConfigUnitPrice = function()
  	return drawPrice
  end
  WG['red_buildmenu'].getConfigUnitRadaricon = function()
  	return drawRadaricon
  end
  WG['red_buildmenu'].getConfigUnitTooltip = function()
  	return drawTooltip
  end
  WG['red_buildmenu'].getConfigUnitBigTooltip = function()
  	return drawBigTooltip
  end
  WG['red_buildmenu'].getConfigUnitPriceLarge = function()
  	return largePrice
  end
  WG['red_buildmenu'].getConfigOldUnitIcons = function()
  	return oldUnitpics
  end
  WG['red_buildmenu'].getConfigShortcutsInfo = function()
  	return shortcutsInfo
  end
  WG['red_buildmenu'].getConfigPlaySounds = function()
  	return playSounds
  end
  WG['red_buildmenu'].getConfigLargeUnitIcons = function()
  	return largeUnitIcons
  end

  WG['red_buildmenu'].setConfigUnitPrice = function(value)
  	drawPrice = value
  end
  WG['red_buildmenu'].setConfigUnitRadaricon = function(value)
	drawRadaricon = value
  end
  WG['red_buildmenu'].setConfigUnitTooltip = function(value)
  	drawTooltip = value
  end
  WG['red_buildmenu'].setConfigUnitBigTooltip = function(value)
  	drawBigTooltip = value
  end
  WG['red_buildmenu'].setConfigUnitPriceLarge = function(value)
  	largePrice = value
  end
  WG['red_buildmenu'].setConfigOldUnitIcons = function(value)
  	oldUnitpics = value
  end
  WG['red_buildmenu'].setConfigShortcutsInfo = function(value)
  	shortcutsInfo = value
  end
  WG['red_buildmenu'].setConfigPlaySounds = function(value)
  	playSounds = value
  end
  WG['red_buildmenu'].setConfigLargeUnitIcons = function(value)
	largeUnitIcons = value
	Spring.SendCommands("luarules reloadluaui")
  end
end

local function onNewCommands(buildcmds,othercmds)
	if (SelectedUnitsCount==0) then
		buildmenu.page = 1
		ordermenu.page = 1
	end

	UpdateGrid(ordermenu,othercmds,2)
	UpdateGrid(buildmenu,buildcmds,1)
end

local function onWidgetUpdate() --function widget:Update()
	AutoResizeObjects()
	SelectedUnitsCount = sGetSelectedUnitsCount()
end

--save/load stuff
--currently only position
function widget:GetConfigData() --save config
	if (PassedStartupCheck) then
		local vsy = Screen.vsy
		local unscale = CanvasY/vsy --needed due to autoresize, stores unresized variables
		Config.buildmenu.px = buildmenu.background.px * unscale
		Config.buildmenu.py = buildmenu.background.py * unscale
		Config.ordermenu.px = ordermenu.background.px * unscale
		Config.ordermenu.py = ordermenu.background.py * unscale
		return {Config=Config, iconScaling=iconScaling, drawPrice=drawPrice, drawRadaricon=drawRadaricon, drawTooltip=drawTooltip, drawBigTooltip=drawBigTooltip, largePrice=largePrice, oldUnitpics=oldUnitpics, shortcutsInfo=shortcutsInfo, playSounds=playSounds, largeUnitIcons=largeUnitIcons}
	end
end
function widget:SetConfigData(data) --load config
	if (data.Config ~= nil) then
		Config.buildmenu.px = data.Config.buildmenu.px
		Config.buildmenu.py = data.Config.buildmenu.py
		Config.ordermenu.px = data.Config.ordermenu.px
		Config.ordermenu.py = data.Config.ordermenu.py
		if (data.drawPrice ~= nil) then
			drawPrice = data.drawPrice
		end
		if (data.drawRadaricon ~= nil) then
			drawRadaricon = data.drawRadaricon
		end
		if (data.drawTooltip ~= nil) then
			drawTooltip = data.drawTooltip
		end
		if (data.drawTooltip ~= nil) then
			drawBigTooltip = data.drawBigTooltip
		end
		if (data.iconScaling ~= nil) then
			iconScaling = data.iconScaling
		end
		if (data.largePrice ~= nil) then
			largePrice = data.largePrice
		end
		if (data.oldUnitpics ~= nil) then
			oldUnitpics = data.oldUnitpics
		end
		if (data.shortcutsInfo ~= nil) then
			shortcutsInfo = data.shortcutsInfo
		end
		if (data.largeUnitIcons ~= nil) then
			largeUnitIcons = data.largeUnitIcons
		end
		if (data.playSounds ~= nil) then
			playSounds = data.playSounds
		end
	end
end






--lots of hacks under this line ------------- overrides/disables default spring menu layout and gets current orders + filters out some commands
local hijackedlayout = false
function widget:Shutdown()
	if (hijackedlayout) then
		widgetHandler:ConfigLayoutHandler(true)
		Spring.ForceLayoutUpdate()
	end
	WG['red_buildmenu'] = nil
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
	local buildcmds = {}
	local statecmds = {}
	local othercmds = {}
	local buildcmdscount = 0
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

					buildcmdscount = buildcmdscount + 1
					buildcmds[buildcmdscount] = cmd
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
	
	return buildcmds,othercmds
end

local hijackattempts = 0
local layoutping = 54352 --random number
local function hijacklayout()
	if (hijackattempts>5) then
		Spring.Echo(widget:GetInfo().name.." failed to hijack config layout.")
		widgetHandler:ToggleWidget(widget:GetInfo().name)
		return
	end
	local function dummylayouthandler(xIcons, yIcons, cmdCount, commands) --gets called on selection change
		WG.layoutpinghax = 54352
		widgetHandler.commands = commands
		widgetHandler.commands.n = cmdCount
		widgetHandler:CommandsChanged() --call widget:CommandsChanged()
		local iconList = {[1337]=9001}
		local custom_cmdz = widgetHandler.customCommands
		return "", xIcons, yIcons, {}, custom_cmdz, {}, {}, {}, {}, {}, iconList
	end
	widgetHandler:ConfigLayoutHandler(dummylayouthandler) --override default build/ordermenu layout
	Spring.ForceLayoutUpdate()
	hijackedlayout = true
	hijackattempts = hijackattempts + 1
end
local updatehax = false
local updatehax2 = true
local firstupdate = true
local function haxlayout()
	if (WG.layoutpinghax~=layoutping) then
		hijacklayout()
	end
	WG.layoutpinghax = nil
	updatehax = true
end
function widget:CommandsChanged()
	haxlayout()
end
local sec = 0
local guishaderCheckInterval = 1
local uiOpacitySec = 0
function widget:Update(dt)
	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec>0.5 then
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
			ordermenu.background.color = {0,0,0,ui_opacity}
			buildmenu.background.color = {0,0,0,ui_opacity}
			ordermenu.background2.color = {1,1,1,ui_opacity*0.04}
			buildmenu.background2.color = {1,1,1,ui_opacity*0.04}
		end
	end
	sec=sec+dt
	if (sec>1/guishaderCheckInterval) then
		sec = 0
		if (WG['guishader_api'] ~= guishaderEnabled) then
			guishaderEnabled = WG['guishader_api']
			if (guishaderEnabled) then
				Config.buildmenu.fadetimeOut = 0.02
				Config.ordermenu.fadetimeOut = 0.02
			else
				Config.buildmenu.fadetimeOut = Config.buildmenu.fadetime*0.66
				Config.ordermenu.fadetimeOut = Config.ordermenu.fadetime*0.66
			end
		end
	end
	onWidgetUpdate()
	if (updatehax or firstupdate) then
		if (firstupdate) then
			haxlayout()
			firstupdate = nil
		end
		onNewCommands(GetCommands())
		updatehax = false
		updatehax2 = true
	end
	if (updatehax2) then
		if (SelectedUnitsCount == 0) then
			onNewCommands({},{}) --flush
			updatehax2 = false
		end
	end
end



function widget:KeyPress(key, mods, isRepeat)
	if shortcutsInfo then
		if building ~= -1 then
 			if building == 1 and key == buildNextKey then
 				building = 2
 				onNewCommands(GetCommands())
 				return true
			end
			local buildcmds, othercmds = GetCommands()
			local found = -1
			for index = 1, #buildKeys do
				if buildKeys[index] == key then
					found = index + (15*building)
					break
				end
			end
			if found ~= -1 and buildcmds[found] ~= nil then
				if playSounds then
					Spring.PlaySoundFile(sound_queue_add, 0.75, 'ui')
				end
				Spring.SetActiveCommand(Spring.GetCmdDescIndex(buildcmds[found].id),1,true,false,Spring.GetModKeyState())
			end
			building = -1
			onNewCommands(GetCommands())
			return true
		else
			-- this prevents keys to be captured when you cannot build anything
			local buildcmds = GetCommands()
			if #buildcmds == 0 then return false end
			
			if key == buildStartKey then
				building = 0
				onNewCommands(GetCommands())
				return true
			elseif key == buildNextKey then
				building = 1
				onNewCommands(GetCommands())
				return true
			end
		end
		-- updates UI because hotkeys text changed color
		onNewCommands(GetCommands())
		return false
	end
end