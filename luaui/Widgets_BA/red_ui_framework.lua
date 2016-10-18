function widget:GetInfo()
	return {
	version   = "9",
	name      = "Red_UI_Framework",
	desc      = "Red UI Framework",
	author    = "Regret (enhanced by Floris)",
	date      = "29 may 2015",
	license   = "GNU GPL, v2 or later",
	layer     = -99999, --lowest go first
	enabled   = true, --loaded by default
	handler   = true, --access to handler
	}
end

local useRoundedRectangles = true
local roundedSizeMultiplier = 1
local usedRoundedSize = roundedSize

local TN = "Red"
local DrawingTN = "Red_Drawing" --WG name for drawing function list
local version = 9

local clock = os.clock
local glGetTextWidth = gl.GetTextWidth
local sgsub = string.gsub
local function getLineCount(text)
	_,linecount = sgsub(text,"\n","\n")
	return linecount+1
end

local Main = {} --boss table with a manabar
local WidgetList = {} --list of widgets using the framework

local LastProcessedWidget = "" --for debugging
local inTweak = false

local vsx,vsy = widgetHandler:GetViewSizes()
if (vsx == 1) then --hax for windowed mode
	vsx,vsy = Spring.GetWindowGeometry()
end
function widget:ViewResize(viewSizeX, viewSizeY)
	vsx,vsy = widgetHandler:GetViewSizes()
	Main.vsx,Main.vsy = vsx,vsy
	Main.Screen.vsx,Main.Screen.vsy = vsx,vsy
	usedRoundedSize = 4 + math.floor((((vsx*vsy) / 900000))) * roundedSizeMultiplier
end


--helper functions
local type = type

local function getTextWidth(o)
	return glGetTextWidth(o.caption)*o.fontsize
end

local function getTextHeight(o)
	return getLineCount(o.caption)*o.fontsize
end

local function isInRect(x,y,px,py,sx,sy)
	if (not py) then
		py = px.py
		sx = px.sx
		sy = px.sy
		px = px.px
	end
	if ((x >= px) and (x <= px+sx)
	and (y >= py) and (y <= py+sy)) then
		return true
	end
	return false
end

local function copytable(t,copyeverything)
	local r = {}
	for i,v in pairs(t) do
		if (copyeverything and (type(v)=="table")) then
			r[i] = copytable(v) --can (probably) cause loops
		else
			r[i] = v
		end
	end
	return r
end
-------------------------


--Objects
local F = {
	[1] = function(o) --rectangle
		if (o.draw == false) then
			return
		end
		
		local color = o.color
		local border = o.border	--color
		local texturecolor = o.texturecolor
		local captioncolor = o.captioncolor
		local iconscale = 1
		if o.iconscale ~= nil then
			iconscale = o.iconscale
		end
		
		local texture = o.texture
		local px,py,sx,sy = o.px,o.py,o.sx,o.sy	
		
		local alphamult = o.alphamult
		if (alphamult~=nil) then
			if (color) then
				color = copytable(color)
				color[4] = o.color[4]*alphamult
			end
			if (border) then
				border = copytable(border)
				border[4] = o.border[4]*alphamult
			end
			if (captioncolor) then
				captioncolor = copytable(captioncolor)
				captioncolor[4] = o.captioncolor[4]*alphamult
			end
			if (texturecolor) then
				texturecolor = copytable(texturecolor)
				texturecolor[4] = o.texturecolor[4]*alphamult
			else
				texturecolor = {1,1,1,alphamult}
			end
		end
		
		if (color) then
			Rect(px,py,sx,sy,color,iconscale)
		end
		
		if (texture) then
			TexRect(px,py,sx,sy,texture,texturecolor,iconscale)
		end
		
		if (o.caption) then
			local px2,py2 = px,py
			local text = o.caption
			local width = glGetTextWidth(text)
			local linecount = getLineCount(text)
			local fontsize = sx/width
			local height = linecount*fontsize
			if (height > sy) then
				fontsize = sy/linecount
				px2 = px2 + (sx - width*fontsize) /2 --center
			else
				py2 = py2 + (sy - height) /2 --center
			end
			Text(px2+((sx*(1-iconscale))/2),py2+((sy*(1-iconscale))/2),fontsize*iconscale,text,o.options,captioncolor)
			o.autofontsize = fontsize
		end
		
		if (border) then --todo: border styles
			Border(px,py,sx,sy,o.borderwidth,border)
		end
	end,

	[2] = function(o) --text
		if (o.draw == false) then
			return
		end
		
		local color = o.color
		local captioncolor = o.captioncolor
		
		local alphamult = o.alphamult
		if (alphamult~=nil) then
			if (color) then
				color = copytable(color)
				color[4] = o.color[4]*alphamult
			elseif (captioncolor) then
				captioncolor = copytable(captioncolor)
				captioncolor[4] = o.captioncolor[4]*alphamult
			end
		end
		
		local px,py = o.px,o.py	
		local fontsize = o.fontsize
		
		Text(px,py,fontsize,o.caption,o.options,color or captioncolor)
	end,

	[3] = function(o) --area
		--plain dummy
	end,

	[4] = function(o) --rectangle rounded
		if (o.draw == false) then
			return
		end
		
		local color = o.color
		local border = o.border	--color
		local texturecolor = o.texturecolor
		local captioncolor = o.captioncolor
		local iconscale = 1
		if o.iconscale ~= nil then
			iconscale = o.iconscale
		end
		
		local texture = o.texture
		local px,py,sx,sy = o.px,o.py,o.sx,o.sy	
		
		local alphamult = o.alphamult
		if (alphamult~=nil) then
			if (color) then
				color = copytable(color)
				color[4] = o.color[4]*alphamult
			end
			if (border) then
				border = copytable(border)
				border[4] = o.border[4]*alphamult
			end
			if (captioncolor) then
				captioncolor = copytable(captioncolor)
				captioncolor[4] = o.captioncolor[4]*alphamult
			end
			if (texturecolor) then
				texturecolor = copytable(texturecolor)
				texturecolor[4] = o.texturecolor[4]*alphamult
			else
				texturecolor = {1,1,1,alphamult}
			end
		end
		if (color) then
			local roundedSize = usedRoundedSize
			if o.roundedsize ~= nil then
				roundedSize = o.roundedsize
			end
			RectRound(px,py,sx,sy,color,roundedSize,iconscale)
			if o.glone ~= nil and o.glone > 0 then
				RectRound(px,py,sx,sy,{color[1],color[2],color[3],o.glone},roundedSize,iconscale,true)
			end
		end
		
		if (texture) then
			TexRect(px,py,sx,sy,texture,texturecolor,iconscale)
		end
		
		if (o.caption) then
			local px2,py2 = px,py
			local text = o.caption
			local width = glGetTextWidth(text)
			local linecount = getLineCount(text)
			local fontsize = sx/width
			local height = linecount*fontsize
			if (height > sy) then
				fontsize = sy/linecount
				px2 = px2 + (sx - width*fontsize) /2 --center
			else
				py2 = py2 + (sy - height) /2 --center
			end
			Text(px2+((sx*(1-iconscale))/2),py2+((sy*(1-iconscale))/2),fontsize*iconscale,text,o.options,captioncolor)
			o.autofontsize = fontsize
		end
		
		if (border) then --todo: border styles
			--Border(px,py,sx,sy,o.borderwidth,border)
		end
	end,
}
if useRoundedRectangles == false then
	F[4] = F[1]
end

local otypes = {
	["rectangle"] = 1,
	["text"] = 2,
	["area"] = 3,
	["rectanglerounded"] = 4,
}
-------------------------

local function processEffects(o,CurClock)
	local e = o.effects
	
	if (o.active ~= false) then
		if (e.fadein_at_activation) then
			if (o.justactivated) then
				if (o.alphamult == nil) then
					o.alphamult = 0
				end
				o.fadein_at_activation_start = CurClock --effect start
			end
			if (o.alphamult~=nil) then
				local start = o.fadein_at_activation_start
				o.alphamult = (CurClock-start)/e.fadein_at_activation
				if (o.alphamult > 1) then
					o.alphamult = nil
					o.fadein_at_activation_start = nil
				else
					--useless here [x] maby
					o.tempactive = true --force object to be active
				end
			end
		end
	else
		o.fadein_at_activation_start = nil
	end
	
	if (o.active == false) then
		if (e.fadeout_at_deactivation) then
			if (o.justdeactivated) then
				if (o.alphamult == nil) then
					o.alphamult = 0
				end
				o.fadeout_at_deactivation_start = CurClock --effect start
			end
			if (o.alphamult~=nil) then
				local start = o.fadeout_at_deactivation_start
				if (start~=nil) then
					o.alphamult = 1-(CurClock-start)/e.fadeout_at_deactivation
					if (o.alphamult <= 0) then
						o.alphamult = nil
						o.fadeout_at_deactivation_start = nil
					else
						o.tempactive = true --force object to be active
					end
				end
			end
		end
	else
		o.fadeout_at_deactivation_start = nil
	end
end

--Mouse handling
local Mouse = {{},{},{}}
local sGetMouseState = Spring.GetMouseState

local dropClick = false
local dropWheel = false

local useDefaultMouseCursor = false
function widget:IsAbove(x,y)
	if (useDefaultMouseCursor) then 
		return true
	end
	return false
end

local WheelState = nil
function widget:MouseWheel(up,value) --up = true/false , value = -1/1
	if Spring.IsGUIHidden() then return end
	WheelState = up
	return dropWheel
end

function widget:MousePress(mx,my,mb)
	if Spring.IsGUIHidden() then return end
	if (type(dropClick)=="table") then
		for i=1,#dropClick do
			if (dropClick[i] == mb) then
				dropClick = true
				break
			end
		end
		if (dropClick ~= true) then
			dropClick = false
		end
	end
	
	return dropClick
end

local LastMouseState = {sGetMouseState()}
local function handleMouse()
	if Spring.IsGUIHidden() then return end
	--reset status
	dropClick = false
	dropWheel = false
	useDefaultMouseCursor = false
	----
	
	local CurMouseState = {sGetMouseState()} --{mx,my,m1,m2,m3}
	CurMouseState[2] = vsy-CurMouseState[2] --make 0,0 top left
	
	Mouse.hoverunused = true --used in mouseover
	Mouse.x = CurMouseState[1]
	Mouse.y = CurMouseState[2]
	
	if (WheelState ~= nil) then
		Mouse.wheel = WheelState
	else
		Mouse.wheel = nil
	end
	WheelState = nil
	
	for i=3,5 do
		local n=i-2
		Mouse[n][1] = nil
		Mouse[n][2] = nil
		Mouse[n][3] = nil
		
		if (CurMouseState[i] and LastMouseState[i]) then 
			Mouse[n][1] = true --isheld
		elseif (CurMouseState[i] and (not LastMouseState[i])) then
			Mouse[n][2] = true --waspressed
			Mouse[n][4] = {Mouse.x,Mouse.y} --last press
		elseif ((not CurMouseState[i]) and LastMouseState[i]) then
			Mouse[n][3] = true --wasreleased
			Mouse[n][5] = {Mouse.x,Mouse.y} --last release
		end
	end
	LastMouseState = CurMouseState
end

local function mouseEvent(t,e,o)
	if (t) then
		for i=1,#t do
			local m = Mouse[t[i][1]]
			if (m[e]) then
				if (not o.checkedformouse) then
					if (isInRect(Mouse.x,Mouse.y,o)) then
						o.checkedformouse = true 
					else
						return true
					end
				end
				
				if ((e==1) and (not isInRect(m[4][1],m[4][2],o))) then --last click was not in same area
					--nuthin'
				else
					m[e] = nil --so only topmost area will get the event
					t[i][2](Mouse.x,Mouse.y,o)
				end
			end
		end
	end
end

local function processMouseEvents(o)
	o.checkedformouse = nil
	
	if (o[2] == 2) then --text
		o.sx = o.getwidth()
		o.sy = o.getheight()
	end
	
	if (o.movable) then
		for i=1,#o.movable do
			if inTweak or (o.onlyTweakUi ~= nil and o.onlyTweakUi == false) then
				if (not o.wasclicked) then
					if (Mouse[o.movable[i]][2]) then
						if (isInRect(Mouse.x,Mouse.y,o)) then
							o.checkedformouse = true
							
							o.wasclicked = {o.px - Mouse.x,o.py - Mouse.y}
							Mouse[o.movable[i]][2] = nil --so only topmost area will get the event
						end
					end
				else
					local newpx = Mouse.x + o.wasclicked[1]
					local newpy = Mouse.y + o.wasclicked[2]
					
					if (o.obeyscreenedge) then
						if (newpx<0) then newpx = 0 end
						if (newpy<0) then newpy = 0 end
						if (newpx>(vsx-o.sx)) then newpx = vsx-o.sx end
						if (newpy>(vsy-o.sy)) then newpy = vsy-o.sy end
					elseif (o.movablearea) then
						if (newpx<o.movablearea.px) then newpx = o.movablearea.px end
						if (newpy<o.movablearea.py) then newpy = o.movablearea.py end
						if (newpx>((o.movablearea.px+o.movablearea.sx)-o.sx)) then newpx = (o.movablearea.px+o.movablearea.sx)-o.sx end
						if (newpy>((o.movablearea.py+o.movablearea.sy)-o.sy)) then newpy = (o.movablearea.py+o.movablearea.sy)-o.sy end
					elseif (o.minpx) then
						if (newpx<o.minpx) then newpx = o.minpx end
						if (newpy<o.minpy) then newpy = o.minpy end
						if (newpx>(o.maxpx-o.sx)) then newpx = o.maxpx-o.sx end
						if (newpy>(o.maxpy-o.sy)) then newpy = o.maxpy-o.sy end
					end
					
					local changex = newpx-o.px
					local changey = newpy-o.py
					if (o.movableslaves) then
						for j=1,#o.movableslaves do
							local s = o.movableslaves[j]
							local snewpx = s.px - (o.px - newpx)
							local snewpy = s.py - (o.py - newpy)
							
							if (s.obeyscreenedge) then
								if (snewpx<0) then snewpx = 0 end
								if (snewpy<0) then snewpy = 0 end
								if (snewpx>(vsx-s.sx)) then snewpx = vsx-s.sx end
								if (snewpy>(vsy-s.sy)) then snewpy = vsy-s.sy end
							elseif (s.movablearea and (s.movablearea~=o)) then --disregard self to prevent a bug
								if (snewpx<s.movablearea.px) then snewpx = s.movablearea.px end
								if (snewpy<s.movablearea.py) then snewpy = s.movablearea.py end
								if (snewpx>((s.movablearea.px+s.movablearea.sx)-s.sx)) then snewpx = (s.movablearea.px+s.movablearea.sx)-s.sx end
								if (snewpy>((s.movablearea.py+s.movablearea.sy)-s.sy)) then snewpy = (s.movablearea.py+s.movablearea.sy)-s.sy end
							elseif (s.minpx) then
								if (snewpx<s.minpx) then snewpx = s.minpx end
								if (snewpy<s.minpy) then snewpy = s.minpy end
								if (snewpx>(s.maxpx-s.sx)) then snewpx = s.maxpx-s.sx end
								if (snewpy>(s.maxpy-s.sy)) then snewpy = s.maxpy-s.sy end
							end
							
							local schangex = snewpx-s.px
							local schangey = snewpy-s.py
							
							if (math.abs(changex)>math.abs(schangex)) then changex = schangex end
							if (math.abs(changey)>math.abs(schangey)) then changey = schangey end
						end
						for j=1,#o.movableslaves do --move slaves
							local s = o.movableslaves[j]
							s.px = s.px+changex
							s.py = s.py+changey
						end
					end
					o.px = o.px+changex --move self
					o.py = o.py+changey
					if (Mouse[o.movable[i]][3]) then
						o.wasclicked = nil
						Mouse[o.movable[i]][3] = nil --so only topmost area will get the event
					end
				end
			end
		end
	end
	
	if (o.mousenotover) then
		if (isInRect(Mouse.x,Mouse.y,o)) then
			o.checkedformouse = true
		else
			o.mousenotover(Mouse.x,Mouse.y,o)
			return
		end
	end
	
	if (o.overridecursor) then
		if (not o.checkedformouse) then
			if (isInRect(Mouse.x,Mouse.y,o)) then o.checkedformouse = true else return end
		end
		useDefaultMouseCursor = true
	end
	if (o.overrideclick) then
		if (not o.checkedformouse) then
			if (isInRect(Mouse.x,Mouse.y,o)) then o.checkedformouse = true else return end
		end
		dropClick = o.overrideclick
	end
	if (o.overridewheel) then
		if (not o.checkedformouse) then
			if (isInRect(Mouse.x,Mouse.y,o)) then o.checkedformouse = true else return end
		end
		dropWheel = true
	end
	
	if (o.mouseover and Mouse.hoverunused) then
		if (not o.checkedformouse) then
			if (isInRect(Mouse.x,Mouse.y,o)) then
				o.checkedformouse = true
			else
				return
			end
		end
		Mouse.hoverunused = false
		o.mouseover(Mouse.x,Mouse.y,o)
	end
	
	if mouseEvent(o.mouseclick,2,o)
	or mouseEvent(o.mouseheld,1,o)
	or mouseEvent(o.mouserelease,3,o) then return end
	
	if (o.mousewheel) then
		if (not o.checkedformouse) then
			if (isInRect(Mouse.x,Mouse.y,o)) then
				o.checkedformouse = true
			else
				return
			end
		end
		if (Mouse.wheel ~= nil) then
			o.mousewheel(Mouse.wheel,Mouse.x,Mouse.y,o)
		end
	end
end
-------------------------

local ssub = string.sub
function widget:Initialize()
	WG[TN] = {{}}
	Main = WG[TN]
	Main.Version = version
	Main.vsx,Main.vsy = vsx,vsy
	Main.Screen = {vsx=vsx,vsy=vsy}
	Main.Copytable = copytable
	Main.Mouse = Mouse
	
	Main.GetWidgetObjects = function(w)
		for i=1,#WidgetList do
			if (WidgetList[i]:GetInfo().name == w:GetInfo().name) then
				return copytable(Main[1][i])
			end
		end
	end
	
	Main.SetTooltip = function(text)
		WG[TN].tooltip = text
	end
	Main.GetSetTooltip = function()
		return WG[TN].tooltip
	end
	
	Main.New = function(w) --function to create a function dawg
		for i=1,#WidgetList do --prevents duplicate widget tables
			if (WidgetList[i]:GetInfo().name == w:GetInfo().name) then
				--Spring.Echo(widget:GetInfo().name..">> don't reload the widget \""..w:GetInfo().name.."\" so fast :<")
				table.remove(WidgetList,i)
				table.remove(Main[1],i)
				break
			end
		end
	
		local n = #Main[1]+1
		WidgetList[n] = w --remember widget
		Main[1][n] = {}
		local t = Main[1][n]
		return function(o)
			local duplicate = false
			for i=1,#t do
				if (t[i] == o) then
					duplicate = true --object already exists, create a copy
					break
				end
			end
			
			local r = {}
			
			local m = #t+1
			if (duplicate) then
				--local new = copytable(o,true)
				local new = copytable(o)
				t[m] = new
				r = new
			else
				o[2] = otypes[o[1]] --translate object type
				t[m] = o
				r = o
			end
			
			r.delete = function()
				r.scheduledfordeletion = true
			end
			
			if (r.caption) then
				r.getwidth = function()
					return getTextWidth(r)
				end
				
				r.getheight = function()
					return getTextHeight(r)
				end
			end
			
			return r
		end
	end
end

function widget:Shutdown()
	WG[TN] = nil
	if (LastProcessedWidget ~= "") then
		Spring.Echo(widget:GetInfo().name..">> last processed widget was \""..LastProcessedWidget.."\"") --for debugging
	end
end

function widget:TweakDrawScreen()
	inTweak = true
end
function widget:DrawScreen()
	inTweak = false
end

local hookedtodrawing = false
local fc = 0 --framecount
function widget:Update()
	
	Main.tooltip = nil
	handleMouse()
	--flush deactivated widgets
	fc=fc+1
	if (fc > 200) then
		fc = 0
		local temp = {}
		for i=1,#WidgetList do
			local name = WidgetList[i]:GetInfo().name
			local order = widgetHandler.orderList[name]
		    local enabled = order and (order > 0)
			
			if (enabled) then
				temp[#temp+1] = WidgetList[i]
			else
				table.remove(Main[1],i)
			end
		end
		WidgetList = temp
	end
	
	if (not hookedtodrawing) then --so drawing widget can be loaded after this widget
		if (WG[DrawingTN]) then
			local X = WG[DrawingTN]
			if (X.version ~= version) then
				Spring.Echo(widget:GetInfo().name..">> Invalid drawing widget version.")
				widgetHandler:ToggleWidget(widget:GetInfo().name)
				return
			end
			Color = X.Color
			Rect = X.Rect
			RectRound = X.RectRound
			TexRect = X.TexRect
			Border = X.Border
			Text = X.Text
			hookedtodrawing = true
		end
	else --process widgets
		local wl = Main[1]
		for j=#wl,1,-1 do --iterate backwards
			if (j==0) then break end
			local CurClock = clock()
			
			--for debugging
			WG[DrawingTN].LastWidget = "<failed to get widget name>"
			local w = WidgetList[j]
			if (w) then
				local winfo = WidgetList[j]:GetInfo()
				if (winfo) then
					LastProcessedWidget = winfo.name
					WG[DrawingTN].LastWidget = LastProcessedWidget
				end
			end
			--
			
			local dellst = {}
			local objlst = wl[j]
			
			for i=1,#objlst do
				local o = objlst[i]
				o.tempactive = nil
				if (o.scheduledfordeletion) then
					dellst[#dellst+1] = i
				else
					if (o.active ~= false) then
						o.notfirstprocessing = true
						if (o.lastactivestate == false) then
							o.justactivated = true
						else
							o.justactivated = nil
						end
					else
						if ((o.lastactivestate ~= false) and o.notfirstprocessing) then
							o.justdeactivated = true
						else
							o.justdeactivated = nil
						end
					end
					o.lastactivestate = o.active
					
					if (o.effects) then
						processEffects(o,CurClock)
					end
					if ((o.active ~= false) or o.tempactive) then
						F[o[2]](o) --object draw function
					end
				end
				
				--process mouseevents backwards, so topmost drawn objects get to mouseevents first
				local ro = objlst[#objlst-i+1]
				if (not ro.scheduledfordeletion) then
					if (ro.active ~= false) then
						if (ro.onupdate) then
							ro.onupdate(ro)
						end
						processMouseEvents(ro)
					end
				end
			end
			
			for i=1,#dellst do
				table.remove(objlst,dellst[i])
			end
		end
	end
end

function widget:WorldTooltip(ttType,data1,data2,data3)
	return Main.tooltip
end
