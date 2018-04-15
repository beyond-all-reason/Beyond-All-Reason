function gadget:GetInfo()
return {
	name      = "Gadget Profiler",
	desc      = "",
	author    = "jK, Bluestone",
	date      = "2007+",
	license   = "GNU GPL, v2 or later",
	layer     = math.huge,
	handler   = true,
	enabled   = true, 
}
end

-- switch on this profiler with the chat action 'luarules profile'

-- once switched on, the data recording cannot be disabled without restarting spring (i.e. once hooked, there is currently no function to unhook)
-- once switched on, future use of 'luarules profile' act as a toggle to show/hide the on-screen profiling data

-- the DrawScreen call of this profiler has a performance impact, but note that this profiler does not profile its own time/allocation loads

-- running this profiler during a multi-player game, with the profiler contained within the game archive, will (also) have a small performance impact on *all* players 
-- nobody will notice, but don't do it if you don't need too!

local usePrefixedNames = true

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local callinStats       = {}
local callinStatsSYNCED = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function ArrayInsert(t, f, g)
	if (f) then
		local layer = g.ghInfo.layer
		local index = 1
		for i,v in ipairs(t) do
			if (v == g) then
				return -- already in the table
			end
			if (layer >= v.ghInfo.layer) then
				index = i + 1
			end
		end
		table.insert(t, index, g)
	end
end


local function ArrayRemove(t, g)
	for k,v in ipairs(t) do
		if (v == g) then
		table.remove(t, k)
		-- break
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local spGetLuaMemUsage = Spring.GetLuaMemUsage

local Hook = function(g,name) return function(...) return g[name](...) end end -- placeholder

local inHook = false
local listOfHooks = {}
setmetatable(listOfHooks, { __mode = 'k' })

local function IsHook(func)
	return listOfHooks[func]
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local prefixedGnames = {}
local function ConstructPrefixedName (ghInfo)
	local gadgetName = ghInfo.name
	local baseName = ghInfo.basename
	local _pos = baseName:find("_", 1)
	local prefix = ((_pos and usePrefixedNames) and (baseName:sub(1, _pos-1)..": ") or "")
	local prefixedGadgetName = "\255\200\200\200" .. prefix .. "\255\255\255\255" .. gadgetName
	
	prefixedGnames[gadgetName] = prefixedGadgetName
	return prefixedGnames[gadgetName]
end


if (gadgetHandler:IsSyncedCode()) then
	Hook = function (g,name)
		local origFunc = g[name]
		local gadgetName = g.ghInfo.name

		if (gadgetName=="Gadget Profiler") then 
			return origFunc -- don't profile ourselves
		end

		local hook_func = function(...)
		if (inHook) then
			return origFunc(...)
		end
		
		local gname = prefixedGnames[gadgetName] or ConstructPrefixedName(g.ghInfo)

		inHook = true
		SendToUnsynced("prf_started", gname, name)
		local results = {origFunc(...)}
			SendToUnsynced("prf_finished", gname, name)
			inHook = false
		return unpack(results)
		end

		listOfHooks[hook_func] = true -- note: using function in keys is unsafe in synced code!!! 

		return hook_func
	end
else
	Hook = function (g,name)
		local gadgetName = g.ghInfo.name

		local realFunc = g[name]

		if (gadgetName=="Gadget Profiler") then 
			return realFunc -- don't profile ourselves
		end
		
		local gname = prefixedGnames[gadgetName] or ConstructPrefixedName(g.ghInfo)
		
		local gadgetCallinStats = callinStats[gname] or {}
		callinStats[gname] = gadgetCallinStats
		gadgetCallinStats[name] = gadgetCallinStats[name] or {0,0,0,0}
		local c = gadgetCallinStats[name]

		local t,s

		local helper_func = function(...)
			local dt = spDiffTimers(spGetTimer(),t)    
			local _,_,new_s,_ = spGetLuaMemUsage() 
			local ds = new_s - s
			c[1] = c[1] + dt
			c[2] = c[2] + dt
			c[3] = c[3] + ds 
			c[4] = c[4] + ds
			inHook = nil
			return ...
		end

		local hook_func = function(...)
			if (inHook) then
				return realFunc(...)
			end

			inHook = true
			t = spGetTimer()
			local _,_,new_s,_ = spGetLuaMemUsage() 		
			s = new_s
			--Spring.Echo(s, collectgarbage("count"))
			return helper_func(realFunc(...))
		end

		listOfHooks[hook_func] = true

		return hook_func
	end
end

local hookset = false

local function StartHook(a,b,c,d)
	if (hookset) then return false end
	
	hookset = true
	Spring.Echo("start profiling (" .. (SendToUnsynced~=nil and "synced" or "unsynced") .. ")")

	local gh = gadgetHandler

	local CallInsList = {}
	for name,e in pairs(gh) do
		local i = name:find("List")
		if (i)and(type(e)=="table") then
			CallInsList[#CallInsList+1] = name:sub(1,i-1)
		end
	end

	--// hook all existing callins
	for _,callin in ipairs(CallInsList) do
		local callinGadgets = gh[callin .. "List"]
		for _,g in ipairs(callinGadgets or {}) do
			g[callin] = Hook(g,callin)
		end
	end

	Spring.Echo("hooked all callins")

	oldUpdateGadgetCallIn = gh.UpdateGadgetCallIn
	gh.UpdateGadgetCallIn = function(self,name,g)
		local listName = name .. 'List'
		local ciList = self[listName]
		if (ciList) then
			local func = g[name]
			if (type(func) == 'function') then
				if (not IsHook(func)) then
				g[name] = Hook(g,name)
				end
				ArrayInsert(ciList, func, g)
			else
				ArrayRemove(ciList, g)
			end
			self:UpdateCallIn(name)
		else
			print('UpdateGadgetCallIn: bad name: ' .. name)
		end
	end

	Spring.Echo("hooked UpdateCallin")

	if SendToUnsynced then
		--Spring.Echo("sending start command to unsynced")
		SendToUnsynced("Start_from_synced")
	end

	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (gadgetHandler:IsSyncedCode()) then

function gadget:Initialize()
	gadgetHandler.actionHandler.AddChatAction(gadget, 'profile', StartHook, " : starts the gadget profiler" ) -- first hook the synced callins, then synced will come back and tell us to (really) start
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
else
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local show = false 
local startedProfiler = false
local validated = false

local timersSynced = {}
local startTickTimer
local memUsage  = {} 

local function UpdateDrawCallin() -- when the profiler isn't running, the profiler gadget should have *no* draw callin
	gadget.DrawScreen = gadget.DrawScreen_
	gadgetHandler:UpdateGadgetCallIn("DrawScreen", gadget)
end

local function Start(cmd)
	StartHook() -- the unsynced one!
	startTickTimer = Spring.GetTimer()
	
	UpdateDrawCallin()
	startedProfiler = true
end

function SyncedCallinStarted(_,gname,cname)
	timersSynced[#timersSynced+1] = spGetTimer() -- callins may call each other -> we need a FIFO queue 
	local _,_,s,_ = spGetLuaMemUsage() 
	memUsage[#memUsage+1] = s
end

function SyncedCallinFinished(_,gname,cname)
	local dt = spDiffTimers(spGetTimer(),timersSynced[#timersSynced])
	timersSynced[#timersSynced] = nil
	local _,_,new_s,_ = spGetLuaMemUsage() 
	local ds = new_s - memUsage[#memUsage] 
	memUsage[#memUsage] = nil

	local gadgetCallinStats = callinStatsSYNCED[gname] or {}
	callinStatsSYNCED[gname] = gadgetCallinStats
	gadgetCallinStats[cname] = gadgetCallinStats[cname] or {0,0,0,0}
	local c = gadgetCallinStats[cname]

	c[1] = c[1] + dt
	c[2] = c[2] + dt
	c[3] = c[3] + ds
	c[4] = c[4] + ds
end

function Validate (_,_,_,pID,_)
	if pID~=Spring.GetMyPlayerID() then return end
	validated = true
	show = not show 
end

function gadget:Initialize()
	gadgetHandler.actionHandler.AddChatAction(gadget, "profile", Validate) 
	
	gadgetHandler.actionHandler.AddSyncAction(gadget, "prf_started",SyncedCallinStarted) -- internal, not meant to be called by user
	gadgetHandler.actionHandler.AddSyncAction(gadget, "prf_finished",SyncedCallinFinished) -- internal, not meant to be called by user 
	gadgetHandler.actionHandler.AddSyncAction(gadget, "Start_from_synced",Start) -- internal, not meant to be called by user 
end


---------------------------
-- data reporting code
---------------------------

local tick = 0.2
local averageTime = 2
local timeLoadAverages = {}
local spaceLoadAverages = {}
local redStrength = {}
local timeLoadAveragesSYNCED = {}
local spaceLoadAveragesSYNCED = {}
local redStrengthSYNCED = {}

local function CalcLoad(old_load, new_load, t)
return old_load*math.exp(-tick/t) + new_load*(1 - math.exp(-tick/t)) 
end

local totalLoads = {}
local allOverTimeSec = 0

local sortedList = {}
local sortedListSYNCED = {}
local function SortFunc(a,b)
	return a.plainname < b.plainname
end

local minPerc = 0.005 -- above this value, we fade in how red we mark a widget (/gadget)
local maxPerc = 0.02 -- above this value, we mark a widget as red
local minSpace = 10 -- Kb
local maxSpace = 100

local function ColourString(R,G,B)
	R255 = math.floor(R*255)
	G255 = math.floor(G*255)
	B255 = math.floor(B*255)
	if (R255%10 == 0) then R255 = R255+1 end
	if (G255%10 == 0) then G255 = G255+1 end
	if (B255%10 == 0) then B255 = B255+1 end
	return "\255"..string.char(R255)..string.char(G255)..string.char(B255)
end

function GetRedColourStrings(tTime, sLoad, name, redStr, deltaTime) 
	local u = math.exp(-deltaTime/5) --magic colour changing rate

	if tTime>maxPerc then tTime = maxPerc end
	if tTime<minPerc then tTime = minPerc end

	-- time
	local new_r = ((tTime-minPerc)/(maxPerc-minPerc)) 
	redStr[name..'_time'] = redStr[name..'_time'] or 0
	redStr[name..'_time'] = u*redStr[name..'_time'] + (1-u)*new_r
	local r,g,b = 1, 1-redStr[name.."_time"]*((255-64)/255), 1-redStr[name.."_time"]*((255-64)/255)
	local timeColourString = ColourString(r,g,b)
	
	-- space
	new_r = math.max(0,math.min(1,(sLoad-minSpace)/(maxSpace-minSpace)))
	redStr[name..'_space'] = redStr[name..'_space'] or 0
	redStr[name..'_space'] = u*redStr[name..'_space'] + (1-u)*new_r
	g = 1-redStr[name.."_space"]*((255-64)/255)
	b = g
	local spaceColourString = ColourString(r,g,b)
	return timeColourString, spaceColourString
end

local function ProcessCallinStats (stats, timeLoadAvgs, spaceloadAvgs, redStr, deltaTime)
	totalLoads = {}
	local allOverTime = 0
	local allOverSpace = 0
	local n = 1
	
	local sorted = {}
	
	for gname,callins in pairs(stats) do
		local t = 0 -- would call it time, but protected
		local cmax_t = 0
		local cmaxname_t = "-"
		local space = 0
		local cmax_space = 0
		local cmaxname_space = "-"
		for cname,c in pairs(callins) do
			t = t + c[1]
			if (c[2]>cmax_t) then
				cmax_t = c[2]
				cmaxname_t = cname
			end
			c[1] = 0
			
			space = space + c[3]
			if (c[4]>cmax_space) then 
				cmax_space = c[4]
				cmaxname_space = cname
			end
			c[3] = 0
		end

		local relTime = 100 * t / deltaTime
		timeLoadAvgs[gname] = CalcLoad(timeLoadAvgs[gname] or relTime, relTime, averageTime) 
		
		local relSpace = space / deltaTime
		spaceloadAvgs[gname] = CalcLoad(spaceloadAvgs[gname] or relSpace, relSpace, averageTime)

		allOverTimeSec = allOverTimeSec + t

		local tLoad = timeLoadAvgs[gname]
		local sLoad = spaceloadAvgs[gname]
		local tTime = t/deltaTime
		
		local tColourString, sColourString = GetRedColourStrings(tTime, sLoad, gname, redStr, deltaTime)
		
		sorted[n] = {plainname=gname, fullname=gname..' \255\200\200\200('..cmaxname_t..','..cmaxname_space..')', tLoad=tLoad, sLoad=sLoad, tTime=tTime, tColourString=tColourString, sColourString=sColourString}
		allOverTime = allOverTime + tLoad
		allOverSpace = allOverSpace + sLoad

		n = n + 1
	end

	table.sort(sorted,SortFunc)

	sorted.allOverTime = allOverTime 
	sorted.allOverSpace = allOverSpace 
	
	return sorted
end

local title_colour = "\255\160\255\160"
local totals_colour = "\255\200\200\255"
local info_colour = "\255\1\1\1"

local maxLines = 50

local function DrawSortedList(list, name, x,y,j)
	if #list==0 then return 0,0 end

	if j>=maxLines-5 then x = x - 375; j = 0; end
	j = j + 1
	gl.Text(title_colour..name, x+152, y-1-(12)*j, 10, "no")
	j = j + 2

	for i=1,#list do
	if j>=maxLines then x = x - 375; j = 0; end
		local v = list[i]
		local name = v.plainname
		local gname = v.fullname
		local tTime = v.tTime
		local tLoad = v.tLoad
		local sLoad = v.sLoad
		local tColour = v.tColourString
		local sColour = v.sColourString	  
		
		gl.Text(gname, x+150, y+1-(12)*j, 10, "no")
		gl.Text(tColour .. ('%.2f%%'):format(tLoad), x+60, y+1-(12)*j, 10, "no")
		gl.Text(sColour .. ('%.0f'):format(sLoad) .. 'kB/s', x+105, y+1-(12)*j, 10, "no")

		j = j + 1
	end

	gl.Text(totals_colour.."totals ("..string.lower(name)..")", x+152, y+1-(12)*j, 10, "no")
	gl.Text(totals_colour..('%.2f%%'):format(list.allOverTime), x+60, y+1-(12)*j, 10, "no")
	gl.Text(totals_colour..('%.0f'):format(list.allOverSpace) .. 'kB/s', x+105, y+1-(12)*j, 10, "no")
	j = j + 1

	return x,j
end

local lm,_,gm,_ = spGetLuaMemUsage()

function gadget:DrawScreen_()
	if not (startedProfiler and validated and show) then return end
	
	if not (next(callinStats)) and not (next(callinStatsSYNCED)) then
		Spring.Echo("no data in profiler!")
		return 
	end

	local deltaTime = Spring.DiffTimers(Spring.GetTimer(),startTickTimer)
	if (deltaTime>=tick) then
		startTickTimer = Spring.GetTimer()

		sortedList = ProcessCallinStats(callinStats, timeLoadAverages, spaceLoadAverages, redStrength, deltaTime)
		sortedListSYNCED = ProcessCallinStats(callinStatsSYNCED, timeLoadAveragesSYNCED, spaceLoadAveragesSYNCED, redStrengthSYNCED, deltaTime)		

		lm,_,gm,_ = spGetLuaMemUsage()
	end

	local vsx, vsy = gl.GetViewSizes()
	local x,y = vsx-400, vsy-150
	local orig_x = x
	local j = 0 -- line#

	local widgetScale = (1 + (vsx*vsy / 7500000))
	gl.PushMatrix()
	gl.Translate(vsx-(vsx*widgetScale),vsy-(vsy*widgetScale),0)
	gl.Scale(widgetScale,widgetScale,1)
	
	gl.Color(1,1,1,1)
	gl.BeginText()
	
	x,j = DrawSortedList(sortedList, "UNSYNCED", x,y,j)

	if j>=maxLines-15 or x==orig_x then
		j=0
		x = x - 375
	end
	
	x,j = DrawSortedList(sortedListSYNCED, "SYNCED", x,y,j)

	if j>=maxLines-12 then x = x - 375; j = 0; end
	j = j + 1
	gl.Text(title_colour.."ALL", x+152, y-1-(12)*j, 10, "no")
	j = j + 1

	j = j + 1
	gl.Text(info_colour.."total percentage of running time spent in luarules callins", x+152, y-1-(12)*j, 10, "no")
	gl.Text(info_colour..('%.1f%%'):format((sortedList.allOverTime or 0)+(sortedListSYNCED.allOverTime or 0)), x+65, y-1-(12)*j, 10, "no")
	j = j + 1
	gl.Text(info_colour.."total rate of mem allocation by luarules callins", x+152, y-1-(12)*j, 10, "no")
	gl.Text(info_colour..('%.0f'):format((sortedList.allOverSpace or 0)+(sortedListSYNCED.allOverSpace or 0)) .. 'kB/s', x+105, y-1-(12)*j, 10, "no")
	j = j + 2
	gl.Text(info_colour..'total lua memory usage is '.. ('%.0f'):format(gm/1000) .. 'MB, of which ' .. ('%.0f'):format(100*lm/gm) .. '% is from luarules', x+65, y-1-(12)*j, 10, "no")
	
	j = j + 2
	gl.Text(title_colour.."All data excludes load from executing GL calls", x+65, y-1-(12)*j, 10, "no")
	j = j + 1
	gl.Text(title_colour.."Callins in brackets are heaviest per gadget for (time,allocs)", x+65, y-1-(12)*j, 10, "no")
	
	j = j + 2
	gl.Text(title_colour.."Tick time: " .. tick .. "s", x+65, y-1-(12)*j, 10, "no")
	j = j + 1
	gl.Text(title_colour.."Smoothing time: " .. averageTime .. "s", x+65, y-1-(12)*j, 10, "no")

	gl.EndText()
	
	gl.PopMatrix()
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
end
