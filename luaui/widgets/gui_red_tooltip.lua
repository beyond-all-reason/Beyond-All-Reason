function widget:GetInfo()
	return {
	name      = "Red Tooltip", --version 4
	desc      = "Requires Red UI Framework",
	author    = "Regret",
	date      = "August 11, 2009", --last change September 10,2009
	license   = "GNU GPL, v2 or later",
	layer     = -100,
	enabled   = true, --enabled by default
	handler   = true, --can use widgetHandler:x()
	}
end
local NeededFrameworkVersion = 8
local CanvasX,CanvasY = 1272,734 --resolution in which the widget was made (for 1:1 size)
--1272,734 == 1280,768 windowed

--todo: sy adjustment

local Config = {
	tooltip = {
		px = 0,py = CanvasY-(12*6+5*2), --default start position
		sx = 300,sy = 12*6+5*2, --background size
		
		fontsize = 12,
		
		margin = 5, --distance from background border
		
		cbackground = {0,0,0,0.5}, --color {r,g,b,alpha}
		cborder = {0,0,0,1},
		
		dragbutton = {2}, --middle mouse button
		tooltip = {
			background = "Hold \255\255\255\1middle mouse button\255\255\255\255 to drag the tooltip display around.",
		},
	},
}

local sGetCurrentTooltip = Spring.GetCurrentTooltip
local sGetSelectedUnitsCount = Spring.GetSelectedUnitsCount

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

local function createtooltip(r)
	local text = {"text",
		px=r.px+r.margin,py=r.py+r.margin,
		fontsize=r.fontsize,
		caption="",
		options="o",
		
		onupdate=function(self)
			local unitcount = sGetSelectedUnitsCount()
			if (unitcount ~= 0) then
				self.caption = "Selected units: "..unitcount.."\n"
			else
				self.caption = "\n"
			end
		
			if (self._mouseoverself) then
				self.caption = self.caption..r.tooltip.background
			else
				self.caption = self.caption..(GetSetTooltip() or sGetCurrentTooltip())
			end
		end
	}
	
	local background = {"rectangle",
		px=r.px,py=r.py,
		sx=r.sx,sy=r.sy,
		color=r.cbackground,
		border=r.cborder,
		
		movable=r.dragbutton,
		movableslaves={text},
		
		obeyscreenedge = true,
		--overridecursor = true,
		overrideclick = {2},
		
		onupdate=function(self)
			if (self.px < (Screen.vsx/2)) then --left side of screen
				if ((self.sx-r.margin*2) <= text.getwidth()) then
					self.sx = (text.getwidth()+r.margin*2) -1
				else
					self.sx = r.sx * Screen.vsy/CanvasY
				end
				text.px = self.px + r.margin
			else --right side of screen
				if ((self.sx-r.margin*2 -1) <= text.getwidth()) then
					self.px = self.px - ((text.getwidth() + r.margin*2) - self.sx)
					self.sx = (text.getwidth() + r.margin*2)
				else
					self.px = self.px - ((r.sx * Screen.vsy/CanvasY) - self.sx)
					self.sx = r.sx * Screen.vsy/CanvasY
				end
				text.px = self.px + r.margin
			end
		end,
		
		mouseover=function(mx,my,self)
			text._mouseoverself = true
		end,
		mousenotover=function(mx,my,self)
			text._mouseoverself = nil
		end,
	}
	
	New(background)
	New(text)
	
	return {
		["background"] = background,
		["text"] = text,
		
		margin = r.margin,
	}
end

function widget:Initialize()
	PassedStartupCheck = RedUIchecks()
	if (not PassedStartupCheck) then return end
	
	tooltip = createtooltip(Config.tooltip)
		
	Spring.SetDrawSelectionInfo(false) --disables springs default display of selected units count
	Spring.SendCommands("tooltip 0")
	AutoResizeObjects()
end

function widget:Shutdown()
	Spring.SendCommands("tooltip 1")
end

function widget:Update()
	AutoResizeObjects()
end

--save/load stuff
--currently only position
function widget:GetConfigData() --save config
	if (PassedStartupCheck) then
		local vsy = Screen.vsy
		local unscale = CanvasY/vsy --needed due to autoresize, stores unresized variables
		Config.tooltip.px = tooltip.background.px * unscale
		Config.tooltip.py = tooltip.background.py * unscale
		return {Config=Config}
	end
end
function widget:SetConfigData(data) --load config
	if (data.Config ~= nil) then
		Config.tooltip.px = data.Config.tooltip.px
		Config.tooltip.py = data.Config.tooltip.py
	end
end
