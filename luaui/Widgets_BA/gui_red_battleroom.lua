-- disable as clipLine is very slow on headless
if (Spring.GetConfigInt('Headless', 0) ~= 0) then
   return false
end

function widget:GetInfo()
	return {
	name      = "Red Console (Battle and autohosts)", --version 4.1
	desc      = "Requires Red UI Framework",
	author    = "Regret + Doo edit",
	date      = "29 may 2015",
	license   = "GNU GPL, v2 or later",
	layer     = 0,
	enabled   = true, --enabled by default
	handler   = true, --can use widgetHandler:x()
	}
end
local vsx, vsy = gl.GetViewSizes()
local widgetScale = (1 + (vsx*vsy / 4000000))

local NeededFrameworkVersion = 8
local SoundIncomingChat  = 'beep4'
local SoundIncomingChatVolume = 1.0

local gameOver = false
local lastConnectionAttempt = ''
--todo: dont cut words apart when clipping text 


local clock = os.clock
local slen = string.len
local ssub = string.sub
local sgsub = string.gsub
local sfind = string.find
local sformat = string.format
local schar = string.char
local sgsub = string.gsub
local mfloor = math.floor
local sbyte = string.byte
local sreverse = string.reverse
local mmax = math.max
local glGetTextWidth = gl.GetTextWidth
local sGetPlayerRoster = Spring.GetPlayerRoster
local sGetTeamColor = Spring.GetTeamColor
local sGetMyAllyTeamID = Spring.GetMyAllyTeamID
local sGetModKeyState = Spring.GetModKeyState
local spPlaySoundFile = Spring.PlaySoundFile
local sGetMyPlayerID = Spring.GetMyPlayerID

local Config = {
	console = {
		px = vsx*0.3,py = vsy*0.05, --default start position
		sx = vsx*0.4, --background size
		
		fontsize = 10*widgetScale,
		minlines = 3, --minimal number of lines to display
		maxlines = 3,
		maxlinesScrollmode = 3,
		
		maxage = 30, --max time for a message to be displayed, in seconds
		
		margin = 7*widgetScale, --distance from background border
		
		fadetime = 0.25, --fade effect time, in seconds
		fadedistance = 1*widgetScale, --distance from cursor at which console shows up when empty

		filterduplicates = true, --group identical lines, f.e. ( 5x Nickname: blahblah)
		
		--note: transparency for text not supported yet
		cothertext = {1,1,1,1}, --normal chat color
		callytext = {0,1,0,1}, --ally chat
		cspectext = {1,1,0,1}, --spectator chat
		
		cotherallytext = {1,0.5,0.5,1}, --enemy ally messages (seen only when spectating)
		cmisctext = {0.78,0.78,0.78,1}, --everything else
		cgametext = {0.4,1,1,1}, --server (autohost) chat
		
		cbackground = {0,0,0,0.0},
		cborder = {0,0,0,0},
		noblur = true,
		
		dragbutton = {2,3}, --middle mouse button
		tooltip = {
			background ="In CTRL+F11 mode:  Hold \255\255\255\1middle mouse button\255\255\255\255 to drag the console.\n"..
			"- Press \255\255\255\1CTRL\255\255\255\255 while mouse is above the \nconsole to activate chatlog viewing.\n"..
			"- Use mousewheel (+hold \255\255\255\1SHIFT\255\255\255\255 for speedup)\n to scroll through the chatlog.",
		},
	},
}


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
		LastAutoResizeX = vsx
		LastAutoResizeY = vsy
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
		noblur = true,
	}
	
	local activationarea = {"area",
		px=r.px-r.fadedistance,py=r.py-r.fadedistance,
		sx=r.sx+r.fadedistance*2,sy=0,
		noblur = true,
		
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

	local background = {"rectanglerounded",
		px=r.px,py=r.py,
		sx=r.sx,sy=r.maxlines*r.fontsize+r.margin*2,
		color=r.cbackground,
		border=r.cborder,
		movable=r.dragbutton,
		noblur = true,
		
		obeyscreenedge = true,
		--overrideclick = {2},
		
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
				background.sy = (r.minlines*lines.fontsize + (lines.px-background.px)*2)
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
		background.movableslaves[#background.movableslaves+1] = b
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

local function lineColour(prevline) -- search prevline and find the final instance of a colour code

	local prevlineReverse = sreverse(prevline)
	local newlinecolour = ""
	
	local colourCodePosReverse = sfind(prevlineReverse, "\255") --search string from back to front

	if colourCodePosReverse then
		for i = 0,2 do
			if ssub(prevlineReverse, colourCodePosReverse + 3 - i, colourCodePosReverse + 3 - i) == "\255" then
				colourCodePosReverse = colourCodePosReverse + 3 - i
				break
			end
		end

		local colourCodePos = slen(prevline) - colourCodePosReverse + 1 	
		if slen(ssub(prevline, colourCodePos)) >= 4 then
			newlinecolour = ssub(prevline, colourCodePos, colourCodePos+3)
		end
	end	

	return newlinecolour
end

local function clipLine(line,fontsize,maxwidth)
	local clipped = {}
		
	local firstclip = line:len()
	local firstpass = true
	while (1) do --loops over lines
		local linelen = slen(line)
		local i=1
		while (1) do -- loop through potential positions where we might need to clip
			if (glGetTextWidth(ssub(line,1,i+1))*fontsize > maxwidth) then
				local test = line
				local newlinecolour = ""
				
				-- set colour of new clipped line
				if firstpass == nil then
					newlinecolour = lineColour(clipped[#clipped])
				end
				
				local newline = newlinecolour .. ssub(test,1,i)
				
				clipped[#clipped+1] = newline
				line = ssub(line,i+1)
	
				if (firstpass) then
					firstclip = i
					firstpass = nil
				end
				
				break
			end
			i=i+1
			if (i > linelen) then
				break
			end
		end

		-- check if we need to clip again
		local width = glGetTextWidth(line)*fontsize
		if (width <= maxwidth) then
			break
		end
	end
	
	-- put remainder of line into final clipped line
	local newlinecolour = ""
	if #clipped > 0 then 
		newlinecolour = lineColour(clipped[#clipped])
	end
	clipped[#clipped+1] = newlinecolour .. line
	
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
	
	g.vars.nextupdate = 0

	local roster = sGetPlayerRoster()
	--[[DEBUG
	for i,el in pairs(roster) do
		if i==1 then
			Spring.Echo(#el)
			for j,val in pairs(el) do
				Spring.Echo(j,val)
			end
		end
		Spring.Echo(i,el)
	end
	--]]
	
	local names = {}
	for i=1,#roster do
		names[roster[i][1]] = {roster[i][4],roster[i][5],roster[i][3],roster[i][2]}
		-- Spring.Echo(roster[i][3])
		-- if roster[i][3] == Spring.GetMyPlayerID() then
		-- Spring.Echo(Spring.GetMyPlayerID())
		-- myname = roster[i][1]
		-- end
	end
	local name = ""
	local text = ""
	local linetype = 0 --other
	if Initialized == true then
		ignoreThisMessage = false
	else
		ignoreThisMessage = false
	end
    local playSound = false
	
	if sfind(line, "My player ID is") and sfind(line, regID) and not nameregistered then
	-- Spring.SendCommands("say Registration ID found")
	registermyname = true
	ignoreThisMessage = true
	end

	if sfind(line, "Input grabbing is ") then
		ignoreThisMessage = true
	end

	if (not newlinecolor) then
		if (names[ssub(line,2,(sfind(line,"> ") or 1)-1)] ~= nil) then
				ignoreThisMessage = true
			linetype = 1 --playermessage
			name = ssub(line,2,sfind(line,"> ")-1)
			text = ssub(line,slen(name)+4)
		if ssub(text,1,1) == "!" then
			ignoreThisMessage = true
				if myname and myname == name then
				waitbotanswer = true
				end
		end
		elseif (names[ssub(line,2,(sfind(line,"] ") or 1)-1)] ~= nil) then
				ignoreThisMessage = true
			linetype = 2 --spectatormessage
			name = ssub(line,2,sfind(line,"] ")-1)
			text = ssub(line,slen(name)+4)
		if ssub(text,1,1) == "!" then
			ignoreThisMessage = true
			-- Spring.Echo(name)
			-- Spring.Echo(myname)
				if myname and myname == name then
				waitbotanswer = true
				end
		end
		elseif (names[ssub(line,2,(sfind(line,"(replay)") or 3)-3)] ~= nil) then
				ignoreThisMessage = true
			linetype = 2 --spectatormessage
			name = ssub(line,2,sfind(line,"(replay)")-3)
			text = ssub(line,slen(name)+13)
		if ssub(text,1,1) == "!" then
			ignoreThisMessage = true
				if myname and myname == name then
				waitbotanswer = true
				end
		end
		elseif (names[ssub(line,1,(sfind(line," added point: ") or 1)-1)] ~= nil) then
				ignoreThisMessage = true
			linetype = 3 --playerpoint
			name = ssub(line,1,sfind(line," added point: ")-1)
			text = ssub(line,slen(name.." added point: ")+1)
		elseif (ssub(line,1,1) == ">") then
			linetype = 4 --gamemessage
			playSound = true
			text = ssub(line,3)
			if sfind(text, "Invalid command" )or sfind(line, "not a valid") or sfind(text, "you cannot") or sfind(text, "You are not allowed") or (sfind(text, "Invalid") and sfind(text, "you are not allowed to vote for command")) or sfind(text, "Unable to") or sfind(text, "Could not find") or sfind(text, "Ringing") or sfind(text, " is no one to ring") then
				ignoreThisMessage = true
				playSound = false
				if waitbotanswer then
				playSound = true
				ignoreThisMessage = false
				waitbotanswer = nil
				if sfind(text, myname) then
				ignoreThisMessage = false
				playSound = true
				end
				end
			end
			if sfind(text, "BAAlphatest1") then
				playSound = true
			text = ssub(text, sfind(text, "BAAlphatest1") + 15)
			end
			if sfind(text, "Ticot") then
				playSound = true
			text = ssub(text, sfind(text, "Ticot") + 8)
			end
			if sfind(text, "Pirateur") then
				playSound = true
			text = ssub(text, sfind(text, "Pirateur") + 11)
			end
			if sfind(text, "OverKillHost1") then
				playSound = true
			text = ssub(text, sfind(text, "OverKillHost1") + 15)
			end
			if sfind(text, "Pirine") then
			playSound = true
			text = ssub(text, sfind(text, "Pirine") + 9)
			end
			
			--PROCESSS VOTES HERE--
			if sfind(text, "called a vote for command") then
				-- vote start: "Didgeri[doo] called a vote for command "bKick Didgeri[doo]" [!vote y, !vote n, !vote b]"
				local command = ssub(text, sfind(text,"called a vote for command") + 27, sfind(text, '" ')-1)
				local user = ssub(text, 1, sfind(text,"called a vote for command")-1)
				text = user.." started vote: "..command
			elseif sfind(text, "Vote for command") then
				-- vote end: "Vote for command "xxx" passed."
				status = ssub(text, sfind(text, '" ')+2,sfind(text, '" ')+7)
				text = "Vote "..status.."."
			-- elseif sfind(text, [[Vote in progress: ]]) then
				-- vote progress :"Vote in progress: "bKick Didgeri[doo]" [y:0/2, n:1/2] (39s remaining)"
				-- local votes = ssub(text,sfind(text, [[y:]]), sfind(text, [[\(]])-1)
				-- local timeremaining = ssub(text,sfind(text, [[ \(]]) + 2, sfind(text, [[ remaining]])-1)
				-- text = "Vote: "..votes..", "..timeremaining.." seconds left."
			end			
			
			-- Will have to insert a basic autohosts list here, for now it's just available on tests hosts so let's not bother too much.
			
            if ssub(line,1,3) == "> <" then --player speaking in battleroom
					ignoreThisMessage = true
			if ssub(text,1,1) == "!" then
				ignoreThisMessage = true
		end
                local i = sfind(ssub(line,4,slen(line)), ">")
				if (i) then
					name = ssub(line,4,i+2)
				else
					name = "unknown"
				end
            end
		end		
    end
	
	if registermyname and not nameregistered then
		myname = name
		registermyname = false
		nameregistered = true
		ignoreThisMessage = true
		-- Spring.SendCommands("wByNum "..regID.." Registered as "..myname)
	end
	
	-- filter shadows config changes
	if sfind(line,"^Set \"shadows\" config(-)parameter to ") then
		ignoreThisMessage = true
	end
	
	if sfind(line,"->") then
		ignoreThisMessage = true
	end

	-- filter hash messages: server= / client=
	if sfind(line,"server=[0-9a-z][0-9a-z][0-9a-z][0-9a-z]") or sfind(line,"client=[0-9a-z][0-9a-z][0-9a-z][0-9a-z]") then
		ignoreThisMessage = true
	end
	
	-- filter Sync error when its a spectator
	--if sfind(line,"^Sync error for ") then
	--	name = ssub(line,16,sfind(line," in frame ")-1)
	--	if names[name] ~= nil and names[name][2] ~= nil and names[name][2] and sGetMyPlayerID() ~= names[name][4] then	-- when spec
	--		ignoreThisMessage = true
	--	end
	--end
	
	-- filter Sync error when its a spectator
	--if sfind(line,"^Error: %[DESYNC WARNING%] ") then
	--	name = ssub(line,sfind(line," %(")+2,sfind(line,"%) ")-1)
	--	if names[name] ~= nil and names[name][2] ~= nil and names[name][2] and sGetMyPlayerID() ~= names[name][4] then	-- when spec
	--		ignoreThisMessage = true
	--	end
	--end
	
	-- filter Connection attempts
	--if sfind(line,"^Connection attempt from ") then
	--	name = ssub(line,25)
	--	lastConnectionAttempt = name
	--  ignoreThisMessage = true
	--end
	
	-- filter Connection established
	--if sfind(line," Connection established") then
	--	name = lastConnectionAttempt
	--  ignoreThisMessage = true
	--end
	
	
	if linetype==0 then
		--filter out some engine messages; 
		--2 lines (instead of 4) appears when player connects
		if sfind(line,'-> Version') or sfind(line,'ClientReadNet') or sfind(line,'Address') then
			ignoreThisMessage = true
		end

        if sfind(line,"Wrong network version") then
            local n,_ = sfind(line,"Message")
            if n ~= nil then
				line = ssub(line,1,n-3) --shorten so as these messages don't get clipped and can be detected as duplicates
			end
        end

		
		if gameOver then
			if sfind(line,'left the game') then
				ignoreThisMessage = true
			end
		end
	end
	

	--ignore messages from muted--
	if WG.ignoredPlayers and WG.ignoredPlayers[name] then 
		ignoreThisMessage = true 
		--Spring.Echo ("blocked message by " .. name)
	end
	
	local MyAllyTeamID = sGetMyAllyTeamID()
	local textcolor = nil
	

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
		textcolor = convertColor(c[1],c[2],c[3])
		
		line = textcolor..line
	end
	
	if (g.vars.consolehistory == nil) then
		g.vars.consolehistory = {}
	end
	local history = g.vars.consolehistory	
	
	if not Initialized then
	ignoreThisMessage = false
	end

	if (not ignoreThisMessage) then		--mute--
	if (g.vars.browsinghistory) then
		if (g.vars.historyoffset == nil) then
			g.vars.historyoffset = 0
		end
		g.vars.historyoffset = g.vars.historyoffset + 1
	end
		local lineID = #history+1	
		history[#history+1] = {line,clock(),lineID,textcolor,linetype}
        
        if ( playSound and not Spring.IsGUIHidden() ) then
            spPlaySoundFile( SoundIncomingChat, SoundIncomingChatVolume, nil, "ui" )
        end
	end
	onelinedone = true
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
	
	local maxlines = cfg.maxlines
	
	local historyoffset = 0
	if (g.vars.browsinghistory) then
		if (g.vars.historyoffset == nil) then
			g.vars.historyoffset = 0
		end
		historyoffset = g.vars.historyoffset
		maxlines = cfg.maxlinesScrollmode
	end
	
	if (usecounters == nil) then
		usecounters = cfg.filterduplicates
	end

	
	local counters = {}
	for i=1,maxlines do
		counters[i] = 1
		if g.counters[i] == nil then
			g.counters[i] = {}
		end
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
		g.background.sy = (cfg.minlines*g.lines.fontsize + (g.lines.px-g.background.px)*2 ) -(cfg.margin/3.5)
	else
		g.background.active = nil --activate
		g.lines.active = nil --activate
		g.vars._empty = nil
		g.background.sy = (count*g.lines.fontsize + (g.lines.px-g.background.px)*2 ) -(cfg.margin/3.5)
	end
	
	g.lines.caption = display
	g.lines.sx = 100
end

function widget:Initialize()
regID = tostring(Spring.GetMyPlayerID())
	PassedStartupCheck = RedUIchecks()
	if (not PassedStartupCheck) then return end
	
	console = createconsole(Config.console)
	Spring.SendCommands("console 0")
	Spring.SendCommands('inputtextgeo 0.26 0.73 0.02 0.028')
	AutoResizeObjects()
end

function widget:GameOver()
	gameOver = true
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
if not Initialized then
	if onelinedone == true then
Initialized = true
regID = tostring(Spring.GetMyPlayerID())
Spring.SendCommands("wByNum "..regID.." My player ID is "..regID)
end
end
end

--save/load stuff
--currently only position
function widget:GetConfigData() --save config
	if (PassedStartupCheck) then
		local vsy = Screen.vsy
		Config.console.px = console.background.px
		Config.console.py = console.background.py
		return {Config=Config}
	end
end
function widget:SetConfigData(data) --load config
	if (data.Config ~= nil) then
		--Config.console.px = data.Config.console.px
		--Config.console.py = data.Config.console.py
	end
end
