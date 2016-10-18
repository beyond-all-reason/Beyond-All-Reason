function widget:GetInfo()
	return {
	version   = "2",
	name      = "Red Minimap",
	desc      = "Requires Red UI Framework",
	author    = "Regret",
	date      = "December 7, 2009", --last change December 11,2009
	license   = "GNU GPL, v2 or later",
	layer     = -11,
	enabled   = true, --enabled by default
	handler   = true, --can use widgetHandler:x()
	}
end
local rescalevalue = 1.26
local buttonScale = 0.5
local NeededFrameworkVersion = 8
local CanvasX,CanvasY = 1272/rescalevalue,734/rescalevalue --resolution in which the widget was made (for 1:1 size)
--1272,734 == 1280,768 windowed

local Config = {
	minimap = {
		px = -0.5,py = -0.5, --default start position
		sx = math.min(135*Game.mapX/Game.mapY,270),sy = 135, --background size
		
		bsx = 15,bsy = 15, --button size

		fadetime = 0.25, --fade effect time, in seconds
		fadedistance = 100, --distance from cursor at which console shows up when empty
		
		cresizebackground = {0.9,0.9,0.9,0.5}, --color {r,g,b,alpha}
		cresizecolor = {1,1,1,1},
		
		cmovebackground = {0,1,0,0.5},
		cmovecolor = {0.9,0.9,0.9,0.8},
		
		cborder = {0,0,0,0},
		cbackground = {0,0,0,0.55},
		cbordersize = 3.5,
		
		dragbutton = {1}, --left mouse button
		tooltip = {
			--todo? kinda useless
		},
	},
}

local sformat = string.format
local sSendCommands = Spring.SendCommands
local sGetMiniMapGeometry = Spring.GetMiniMapGeometry
local sGetCameraState = Spring.GetCameraState
local sceduleMinimapGeometry = false

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

local function createminimap(r)
	local minimap = {"rectangle",
		px=r.px,py=r.py,
		sx=r.sx,sy=r.sy,
		border=r.cborder,
		obeyscreenedge = true,
	}
	local minimapbg = {"rectanglerounded",
		px=r.px-r.cbordersize,py=r.py,
		sx=r.sx,sy=r.sy,
		color=r.cbackground,
		obeyscreenedge = true,
		bordersize=r.cbordersize
	}
	
	local resizebutton = {"rectangle",
		px=r.px+r.sx-r.bsx,py=r.py+r.sy-1,
		sx=r.bsx*buttonScale,sy=r.bsy*buttonScale,
		
		color=r.cresizebackground,
		texturecolor=r.cmovecolor,
		texture="LuaUI/Images/RedMinimap/resize.png",		
		border=r.cborder,
		movable=r.dragbutton,
		overridecursor = true,
		overrideclick = r.dragbutton,
		roundedsize = math.floor(r.bsy*0.15),
		onlyTweakUi = false,
		
		effects = {
			fadein_at_activation = r.fadetime,
			fadeout_at_deactivation = r.fadetime,
		},
	}
	local offsetcorrection = r.bsx - ((r.bsx * buttonScale))
	local movebutton = {"rectangle",
		px=r.px+r.sx-r.bsx*2+1 + offsetcorrection,py=r.py+r.sy-1,
		sx=r.bsx*buttonScale,sy=r.bsy*buttonScale,
		
		color=r.cmovebackground,
		texturecolor=r.cmovecolor,
		texture="LuaUI/Images/RedMinimap/move.png",
		
		border=r.cborder,
		movable=r.dragbutton,
		obeyscreenedge = true,
		overridecursor = true,
		overrideclick = r.dragbutton,
		roundedsize = math.floor(r.bsy*0.15),
		onlyTweakUi = false,
		
		effects = {
			fadein_at_activation = r.fadetime,
			fadeout_at_deactivation = r.fadetime,
		},
	}
	
	New(movebutton)
	New(resizebutton)
	New(minimap)
	New(minimapbg)
	
	resizebutton.mouseover = function(mx,my,self)
		self.active = nil
		movebutton.active = nil
		
		if (not self._mouseover) then
			self._color4 = self.color[4]
			self.color[4] = 4
		end
		
		self._mouseover = true
	end
	resizebutton.mousenotover = function(mx,my,self)
		if ((not minimap._mouseover) and (not movebutton._mouseover)) then
			self.active = false --deactivate
		end
		
		if (self._mouseover) then
			self.color[4] = self._color4
		end
		
		self._mouseover = nil
	end
	
	movebutton.mouseover = function(mx,my,self)
		self.active = nil
		resizebutton.active = nil
		
		if (not self._mouseover) then
			self._color4 = self.color[4]
			self.color[4] = 1
		end
		
		self._mouseover = true
	end
	movebutton.mousenotover = function(mx,my,self)
		if ((not minimap._mouseover) and (not resizebutton._mouseover)) then
			self.active = false --deactivate
		end
		
		if (self._mouseover) then
			self.color[4] = self._color4
		end
		
		self._mouseover = nil
	end
	
	minimap.onupdate=function(self)
		self.sx = resizebutton.px-self.px+resizebutton.sx
		self.sy = resizebutton.py-self.py+1
		minimapbg.px = self.px - minimapbg.bordersize
		minimapbg.py = self.py - minimapbg.bordersize
		minimapbg.sx = self.sx + minimapbg.bordersize + minimapbg.bordersize
		minimapbg.sy = self.sy + minimapbg.bordersize + minimapbg.bordersize
	end
	resizebutton.onupdate=function(self)
		if (self._mouseover) then
			self.minpx = minimap.px+r.bsx-1
			self.minpy = minimap.py+r.bsx
		else
			self.minpx = 0
			self.minpy = 0
		end
		self.maxpx = Screen.vsx
		self.maxpy = Screen.vsy
	end
	
	minimap.mousenotover = function(mx,my,self)
		self._mouseover = nil
	end
	
	minimap.mouseover = function(mx,my,self)
		self._mouseover = true
	
		movebutton.active = nil
		resizebutton.active = nil
	end
	
	minimap.movableslaves = {
		movebutton,
	}
	movebutton.movableslaves = {
		minimap,resizebutton,
	}
	resizebutton.movableslaves = {
		movebutton,
	}
	
	return minimap
end

function widget:Initialize()
	--oldMinimapGeometry = Spring.GetConfigString("MiniMapGeometry","2 2 200 200") -- store original geometry
	oldMinimapGeometry = sGetMiniMapGeometry()
	
	PassedStartupCheck = RedUIchecks()
	if (not PassedStartupCheck) then return end
	
	rMinimap = createminimap(Config.minimap)
	
	gl.SlaveMiniMap(true)
	
	AutoResizeObjects() --fix for displacement on crash issue
end

local lastPos = {}


function widget:ViewResize(viewSizeX, viewSizeY)
	sceduleMinimapGeometry = true
end


function widget:Update()
	local _,_,_,_,minimized,maximized = sGetMiniMapGeometry()
	if (maximized) then
		--hack to reset state minimap
		gl.SlaveMiniMap(false) 
		gl.SlaveMiniMap(true)
		----
	end
	
	if (minimized) then
		rMinimap.active = false
		--hack to reset state minimap
		gl.SlaveMiniMap(false) 
		gl.SlaveMiniMap(true)
		----
	else
		rMinimap.active = nil
	end
	
	local st = sGetCameraState()
	if (st.name == "ov") then --overview camera
		rMinimap.active = false
	else
		rMinimap.active = nil
	end

	AutoResizeObjects()
	if ((lastPos.px ~= rMinimap.px) or (lastPos.py ~= rMinimap.py) or (lastPos.sx ~= rMinimap.sx) or (lastPos.sy ~= rMinimap.sy) or sceduleMinimapGeometry) then
		sSendCommands(sformat("minimap geometry %i %i %i %i",
		rMinimap.px,
		rMinimap.py,
		rMinimap.sx,
		rMinimap.sy))
		sceduleMinimapGeometry = false
	end
	lastPos.px = rMinimap.px
	lastPos.py = rMinimap.py
	lastPos.sx = rMinimap.sx
	lastPos.sy = rMinimap.sy
end

function widget:DrawScreen()
	if (rMinimap.active ~= nil) then
		return
	end
	-- this makes jK rage
	gl.ResetState()
	gl.ResetMatrices()
	----
	
    --gl.SlaveMiniMap(true)
    gl.DrawMiniMap()
    --gl.SlaveMiniMap(false)
	
	-- this makes jK rage
	gl.ResetState()
	gl.ResetMatrices()
	----
end

function widget:Shutdown()
	gl.SlaveMiniMap(false)
	Spring.SendCommands("minimap geometry "..oldMinimapGeometry)
end


--save/load stuff
--currently only position
function widget:GetConfigData() --save config
	if (PassedStartupCheck) then
		local vsy = Screen.vsy
		local unscale = CanvasY/vsy --needed due to autoresize, stores unresized variables
		Config.minimap.px = rMinimap.px * unscale
		Config.minimap.py = rMinimap.py * unscale
		return {Config=Config}
	end
end
function widget:SetConfigData(data) --load config
	if (data.Config ~= nil) then
		Config.minimap.px = data.Config.minimap.px
		Config.minimap.py = data.Config.minimap.py
	end
end
