function widget:GetInfo()
	return {
	name      = "Red Console", --version 4.1
	desc      = "Requires Red UI Framework",
	author    = "Regret",
	date      = "August 13, 2009", --last change September 10,2009
	license   = "GNU GPL, v2 or later",
	layer     = 0,
	enabled   = true, --enabled by default
	handler   = true, --can use widgetHandler:x()
	}
end
local NeededFrameworkVersion = 8
local CanvasX,CanvasY = 1272,734 --resolution in which the widget was made (for 1:1 size)
--1272,734 == 1280,768 windowed
local SoundIncomingChat  = 'sounds/beep4.wav'
local SoundIncomingChatVolume = 1.0

--todo: dont cut words apart when clipping text 

local Config = {
	console = {
		px = 300,py = 34+5, --default start position
		sx = 605, --background size
		
		fontsize = 12,
		
		minlines = 1, --minimal number of lines to display
		maxlines = 10,
		
		maxage = 15, --max time for a message to be displayed, in seconds
		
		margin = 5, --distance from background border
		
		fadetime = 0.25, --fade effect time, in seconds
		fadedistance = 100, --distance from cursor at which console shows up when empty
		
		filterduplicates = true, --group identical lines, f.e. ( 5x Nickname: blahblah)
		
		--note: transparency for text not supported yet
		cothertext = {1,1,1,1}, --normal chat color
		callytext = {0,1,0,1}, --ally chat
		cspectext = {1,1,0,1}, --spectator chat
		
		cotherallytext = {1,0.5,0.5,1}, --enemy ally messages (seen only when spectating)
		cmisctext = {0.78,0.78,0.78,1}, --everything else
		cgametext = {0.4,1,1,1}, --server (autohost) chat
		
		cbackground = {0,0,0,0.1},
		cborder = {0,0,0,0.5},
		
		dragbutton = {2}, --middle mouse button
		tooltip = {
			background ="Hold \255\255\255\1middle mouse button\255\255\255\255 to drag the console around.\n\n"..
			"Press \255\255\255\1CTRL\255\255\255\255 while mouse is above the console to activate chatlog viewing.\n"..
			"Use mousewheel (+hold \255\255\255\1SHIFT\255\255\255\255 for speedup) to scroll through the chatlog.",
		},
	},
}

local clock = os.clock
local slen = string.len
local ssub = string.sub
local sfind = string.find
local sformat = string.format
local schar = string.char
local sgsub = string.gsub
local mfloor = math.floor
local sbyte = string.byte
local mmax = math.max
local glGetTextWidth = gl.GetTextWidth
local sGetPlayerRoster = Spring.GetPlayerRoster
local sGetTeamColor = Spring.GetTeamColor
local sGetMyAllyTeamID = Spring.GetMyAllyTeamID
local sGetModKeyState = Spring.GetModKeyState
local spPlaySoundFile = Spring.PlaySoundFile

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

local function createconsole(r)
	local vars = {}
	
	local lines = {"text",
		px=r.px+r.margin,py=r.py+r.margin,
		fontsize=r.fontsize,
		caption="",
		options="o", --black outline
	}
	
	local activationarea = {"area",
		px=r.px-r.fadedistance,py=r.py-r.fadedistance,
		sx=r.sx+r.fadedistance*2,sy=0,
		
		mousewheel=function(up,mx,my,self)
			if (vars.browsinghistory) then
				local alt,ctrl,meta,shift = Spring.GetModKeyState()
				local step = 1
				if (shift) then
					step = 5
				end
				if (vars.historyoffset == nil) then
					vars.historyoffset = 0
				end
				if (up) then
					vars.historyoffset = vars.historyoffset + step
					vars._forceupdate = true
				else
					vars.historyoffset = vars.historyoffset - step
					vars._forceupdate = true
				end
				if (vars.historyoffset > (#vars.consolehistory - r.maxlines)) then
					vars.historyoffset = #vars.consolehistory - r.maxlines
				elseif (vars.historyoffset < 0) then
					vars.historyoffset = 0
				end
			end
		end,
	}

	local background = {"rectangle",
		px=r.px,py=r.py,
		sx=r.sx,sy=r.maxlines*r.fontsize+r.margin*2,
		color=r.cbackground,
		border=r.cborder,
		movable=r.dragbutton,
		
		obeyscreenedge = true,
		overrideclick = {2},
		
		movableslaves={lines,activationarea},
		
		effects = {
			fadein_at_activation = r.fadetime,
			fadeout_at_deactivation = r.fadetime,
		},
	}
	
	activationarea.onupdate=function(self)
		local fadedistance = (self.sx-background.sx)/2
		self.sy = background.sy+fadedistance*2
		self.px = background.px-fadedistance
		self.py = background.py-fadedistance
		
		if (not self._mousenotover) then
			background.active = nil --activate
			if (vars._empty) then
				background.sy = r.minlines*lines.fontsize + (lines.px-background.px)*2
			end
			local alt,ctrl,meta,shift = Spring.GetModKeyState()
			if (ctrl and not vars.browsinghistory) then
				if (vars._skipagecheck == nil) then
					vars._forceupdate = true
					vars.nextupdate = -1
					vars.browsinghistory = true
					vars.historyoffset = 0
					
					self.overridewheel = true
				end
				vars._skipagecheck = true
				vars._usecounters = false
			end
		else
			if (vars._skipagecheck ~= nil) then
				vars._forceupdate = true
				vars.browsinghistory = nil
				vars.historyoffset = 0
				
				self.overridewheel = nil
				vars._skipagecheck = nil
				vars._usecounters = nil
			end
		end
		
		self._mousenotover = nil
	end
	activationarea.mousenotover=function(mx,my,self)
		self._mousenotover = true
		if (vars._empty) then
			background.active = false
		end
	end
	
	New(activationarea)
	New(background)
	New(lines)
	
	local counters = {}
	for i=1,r.maxlines do
		local b = New(lines)
		b.onupdate = function(self)
			self.px = background.px - self.getwidth() - (lines.px-background.px)
		end
		b._count = 0
		b.active = false
		b.py = b.py+(i-1)*r.fontsize
		counters[#counters+1] = b
		table.insert(background.movableslaves,b)
	end
	
	--tooltip
	background.mouseover = function(mx,my,self) SetTooltip(r.tooltip.background) end
	
	background.active = nil
	
	return {
		["background"] = background,
		["lines"] = lines,
		["counters"] = counters,
		["vars"] = vars
	}
end

local function clipLine(line,fontsize,maxwidth)
	local clipped = {}
		
	local firstclip = line:len()
	local firstpass = true
	while (1) do
		local linelen = slen(line)
		local i=1
		while (1) do
			if (glGetTextWidth(ssub(line,1,i+1))*fontsize > maxwidth) then
				if (firstpass) then
					firstclip = i
					firstpass = nil
				end
				local test = line
				clipped[#clipped+1] = ssub(test,1,i)
				line = ssub(line,i+1)
				break
			end
			i=i+1
			if (i > linelen) then
				break
			end
		end
		
		local width = glGetTextWidth(line)*fontsize
		if (width <= maxwidth) then
			break
		end
	end
	clipped[#clipped+1] = line
	return clipped,firstclip
end

local function clipHistory(g,oneline)
	local history = g.vars.consolehistory
	local maxsize = g.background.sx - (g.lines.px-g.background.px)
	local fontsize = g.lines.fontsize
	
	if (oneline) then
		local line = history[#history]
		local lines,firstclip = clipLine(line[1],fontsize,maxsize)	
		line[1] = ssub(line[1],1,firstclip)
		for i=1,#lines do
			if (i>1) then
				history[#history+1] = {line[4]..lines[i],line[2],line[3],line[4],line[5]}
			end
		end
	else
		local clippedhistory = {}
		for i=1,#history do
			local line = history[i]
			local lines,firstclip = clipLine(line[1],fontsize,maxsize)
			lines[1] = ssub(line[1],1,firstclip)
			for i=1,#lines do
				if (i>1) then
					clippedhistory[#clippedhistory+1] = {line[4]..lines[i],line[2],line[3],line[4],line[5]}
				else
					clippedhistory[#clippedhistory+1] = {lines[i],line[2],line[3],line[4],line[5]}
				end
			end
		end
		g.vars.consolehistory = clippedhistory
	end
end

local function convertColor(r,g,b)
	return schar(255, (r*255), (g*255), (b*255))
end

local function processLine(line,g,cfg,newlinecolor)
	if (g.vars.browsinghistory) then
		if (g.vars.historyoffset == nil) then
			g.vars.historyoffset = 0
		end
		g.vars.historyoffset = g.vars.historyoffset + 1
	end
	
	g.vars.nextupdate = 0

	local roster = sGetPlayerRoster()
	local names = {}
	for i=1,#roster do
		names[roster[i][1]] = {roster[i][4],roster[i][5],roster[i][3]}
	end
	
	local name = ""
	local text = ""
	local linetype = 0 --other
	
	if (not newlinecolor) then
		if (names[ssub(line,2,(sfind(line,"> ") or 1)-1)] ~= nil) then
			linetype = 1 --playermessage
			name = ssub(line,2,sfind(line,"> ")-1)
			text = ssub(line,slen(name)+4)
		elseif (names[ssub(line,2,(sfind(line,"] ") or 1)-1)] ~= nil) then
			linetype = 2 --spectatormessage
			name = ssub(line,2,sfind(line,"] ")-1)
			text = ssub(line,slen(name)+4)
		elseif (names[ssub(line,2,(sfind(line,"(replay)") or 3)-3)] ~= nil) then
			linetype = 2 --spectatormessage
			name = ssub(line,2,sfind(line,"(replay)")-3)
			text = ssub(line,slen(name)+13)
		elseif (names[ssub(line,1,(sfind(line," added point: ") or 1)-1)] ~= nil) then
			linetype = 3 --playerpoint
			name = ssub(line,1,sfind(line," added point: ")-1)
			text = ssub(line,slen(name.." added point: ")+1)
		elseif (ssub(line,1,1) == ">") then
			linetype = 4 --gamemessage
			text = ssub(line,3)
		end		
    end
	--mute--
	local ignoreThisMessage = false
	if (mutedPlayers[name]) then 
		ignoreThisMessage = true 
		--Spring.Echo ("blocked message by " .. name)
	end
	
	local MyAllyTeamID = sGetMyAllyTeamID()
	local textcolor = nil
	
    local playSound = false
	if (linetype==1) then --playermessage
		local c = cfg.cothertext
		local misccolor = convertColor(c[1],c[2],c[3])
		if (sfind(text,"Allies: ") == 1) then
			text = ssub(text,9)
			if (names[name][1] == MyAllyTeamID) then
				c = cfg.callytext
			else
				c = cfg.cotherallytext
			end
		elseif (sfind(text,"Spectators: ") == 1) then
			text = ssub(text,13)
			c = cfg.cspectext
		end
		
		textcolor = convertColor(c[1],c[2],c[3])
		local r,g,b,a = sGetTeamColor(names[name][3])
		local namecolor = convertColor(r,g,b)
		
		line = namecolor..name..misccolor..": "..textcolor..text
        
        playSound = true
		
	elseif (linetype==2) then --spectatormessage
		local c = cfg.cothertext
		local misccolor = convertColor(c[1],c[2],c[3])
		if (sfind(text,"Allies: ") == 1) then
			text = ssub(text,9)
			c = cfg.cspectext
		elseif (sfind(text,"Spectators: ") == 1) then
			text = ssub(text,13)
			c = cfg.cspectext
		end
		textcolor = convertColor(c[1],c[2],c[3])
		c = cfg.cspectext
		local namecolor = convertColor(c[1],c[2],c[3])
		
		line = namecolor.."(s) "..name..misccolor..": "..textcolor..text
		
        playSound = true
        
	elseif (linetype==3) then --playerpoint
		local c = cfg.cspectext
		local namecolor = convertColor(c[1],c[2],c[3])
		
		local spectator = true
		if (names[name] ~= nil) then
			spectator = names[name][2]
		end
		if (spectator) then
            name = "(s) "..name
		else
            local r,g,b,a = sGetTeamColor(names[name][3])
            namecolor =  convertColor(r,g,b)
		end
		
		c = cfg.cotherallytext
		if (spectator) then
			c = cfg.cspectext
		elseif (names[name][1] == MyAllyTeamID) then
			c = cfg.callytext
		end
		textcolor = convertColor(c[1],c[2],c[3])
		c = cfg.cothertext
		local misccolor = convertColor(c[1],c[2],c[3])
		
		line = namecolor..name..misccolor.." * "..textcolor..text
		
	elseif (linetype==4) then --gamemessage
		local c = cfg.cgametext
		textcolor = convertColor(c[1],c[2],c[3])
		
		line = textcolor.."> "..text
	else --every other message
		local c = cfg.cmisctext
		textcolor = newlinecolor or convertColor(c[1],c[2],c[3])
		
		line = textcolor..line
	end
	
	if (g.vars.consolehistory == nil) then
		g.vars.consolehistory = {}
	end
	local history = g.vars.consolehistory	
	
	if (not ignoreThisMessage) then		--mute--
		local lineID = #history+1	
		history[#history+1] = {line,clock(),lineID,textcolor,linetype}
        
        if ( playSound ) then
            spPlaySoundFile( SoundIncomingChat, SoundIncomingChatVolume, nil, "ui" )
        end
	end

	return history[#history]
end

local function updateconsole(g,cfg)
	local forceupdate = g.vars._forceupdate
	local justforcedupdate = g.vars._justforcedupdate
	
	if (forceupdate and (not justforcedupdate)) then
		g.vars._justforcedupdate = true
		g.vars._forceupdate = nil
	else
		g.vars._justforcedupdate = nil
		g.vars._forceupdate = nil
		
		if (g.vars.nextupdate == nil) then
			g.vars.nextupdate = 0
		end
		if ((g.vars.nextupdate < 0) or (clock() < g.vars.nextupdate)) then
			return
		end
	end
	
	local skipagecheck = g.vars._skipagecheck
	local usecounters = g.vars._usecounters
	
	local historyoffset = 0
	if (g.vars.browsinghistory) then
		if (g.vars.historyoffset == nil) then
			g.vars.historyoffset = 0
		end
		historyoffset = g.vars.historyoffset
	end
	
	if (usecounters == nil) then
		usecounters = cfg.filterduplicates
	end

	local maxlines = cfg.maxlines
	
	local counters = {}
	for i=1,maxlines do
		counters[i] = 1
		g.counters[i].active = false
		g.counters[i].caption = ""
	end
	
	local maxage = cfg.maxage
	local display = ""
	local count = 0
	local i=0
	local lastID = 0
	local lastLine = ""
	
	local history = g.vars.consolehistory or {}

	while (count < maxlines) do
		if (history[#history-i-historyoffset]) then
			local line = history[#history-i-historyoffset]
			if (skipagecheck or ((clock()-line[2]) <= maxage)) then
				if (count == 0) then
					count = count + 1
					display = line[1]
				else
					if (usecounters and (lastID > 0) and (lastID~=line[3]) and (line[1] == lastLine)) then
						counters[count] = counters[count] + 1
					else
						count = count + 1
						display = line[1].."\n"..display
					end
				end
				
				lastLine = line[1]
				lastID = line[3]
				
				if (skipagecheck) then
					g.vars.nextupdate = -1
				else
					g.vars.nextupdate = line[2]+maxage
				end
			else
				break
			end
			i=i+1
		else
			break
		end
	end
	
	if (usecounters) then
		for i=1,#counters do
			if (counters[i] ~= 1) then
				local counter = count-i+1
				g.counters[counter].active = nil
				g.counters[counter].caption = counters[i].."x"
			end
		end
	end
	
	if (count == 0) then
		g.vars.nextupdate = -1 --no update until new console line
		g.background.active = false
		g.lines.active = false
		g.vars._empty = true
		g.background.sy = cfg.minlines*g.lines.fontsize + (g.lines.px-g.background.px)*2
	else
		g.background.active = nil --activate
		g.lines.active = nil --activate
		g.vars._empty = nil
		g.background.sy = count*g.lines.fontsize + (g.lines.px-g.background.px)*2
	end
	
	g.lines.caption = display
end

function widget:Initialize()
	PassedStartupCheck = RedUIchecks()
	if (not PassedStartupCheck) then return end
	
	console = createconsole(Config.console)
	Spring.SendCommands("console 0")
	AutoResizeObjects()
end

function widget:Shutdown()
	Spring.SendCommands("console 1")
end

function widget:AddConsoleLine(lines,priority)
	lines = lines:match('^\[f=[0-9]+\] (.*)$') or lines
	local textcolor
	for line in lines:gmatch("[^\n]+") do
		textcolor = processLine(line, console, Config.console, textcolor)[4]
	end
	clipHistory(console,true)
end

function widget:Update()
	updateconsole(console,Config.console)
	AutoResizeObjects()
end

--save/load stuff
--currently only position
function widget:GetConfigData() --save config
	if (PassedStartupCheck) then
		local vsy = Screen.vsy
		local unscale = CanvasY/vsy --needed due to autoresize, stores unresized variables
		Config.console.px = console.background.px * unscale
		Config.console.py = console.background.py * unscale
		return {Config=Config}
	end
end
function widget:SetConfigData(data) --load config
	if (data.Config ~= nil) then
		Config.console.px = data.Config.console.px
		Config.console.py = data.Config.console.py
	end
end

--mute--
function widget:TextCommand(s)     
     local token = {}
	 local n = 0
	 --for w in string.gmatch(s, "%a+") do
	 for w in string.gmatch(s, "%S+") do
		n = n +1
		token[n] = w		
     end
	 
	--for i = 1,n do Spring.Echo (token[i]) end
	 
	 if (token[1] == "mute") then
		--Spring.Echo ("geht ums muten")
		 for i = 2,n do
			mutePlayer (token[i])
			Spring.Echo ("*muting " .. token[i] .. "*")
		end
	end
	
	if (token[1] == "unmute") then
		--Spring.Echo ("geht ums UNmuten")
		 for i = 2,n do
			unmutePlayer (token[i])
			Spring.Echo ("*unmuting " .. token[i] .."*")
		end
		if (n==1) then unmuteAll() Spring.Echo ("unmuting everybody") end
	end
	
end

--mute
mutedPlayers = {}
function mutePlayer (playername)
	mutedPlayers[playername] = true
end

function unmutePlayer (playername)
	mutedPlayers[playername] = nil
end

function unmuteAll ()
	mutedPlayers = {}
end