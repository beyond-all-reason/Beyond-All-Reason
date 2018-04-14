--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "WidgetProfiler",
    desc      = "",
    author    = "jK",
    version   = "2.0",
    date      = "2007,2008,2009",
    license   = "GNU GPL, v2 or later",
    layer     = -math.huge,
    handler   = true,
    enabled   = false  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- make a table of the names of user widgets 
local userWidgets = {}
function widget:Initialize()
    for name,wData in pairs(widgetHandler.knownWidgets) do
        userWidgets[name] = (not wData.fromZip)
    end
end

-- special widgets
local specialWidgets = {
    ["Lups"] = true,
    ["API Chili"] = true,
    ["Red_UI_Framework"] = true,
    ["Red_Drawing"] = true,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local callinTimes       = {}

local oldUpdateWidgetCallIn
local oldInsertWidget

local listOfHooks = {}
setmetatable(listOfHooks, { __mode = 'k' })

local inHook = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local SCRIPT_DIR = Script.GetName() .. '/'

local function IsHook(func)
  return listOfHooks[func]
end

local function Hook(g,name)
  local spGetTimer = Spring.GetTimer
  local spDiffTimers = Spring.DiffTimers
  local widgetName = g.whInfo.name

  local realFunc = g[name]
  g["_old" .. name] = realFunc

  if (widgetName=="WidgetProfiler") then
    return realFunc
  end
  local widgetCallinTime = callinTimes[widgetName] or {}
  callinTimes[widgetName] = widgetCallinTime
  widgetCallinTime[name] = widgetCallinTime[name] or {0,0,0,0}
  local callinStats = widgetCallinTime[name]

  local t

  local helper_func = function(...)
    local dt = spDiffTimers(spGetTimer(),t)    
    local ds = collectgarbage("count") - s
    callinStats[1] = callinStats[1] + dt
    callinStats[2] = callinStats[2] + dt
    callinStats[3] = callinStats[3] + ds 
    callinStats[4] = callinStats[4] + ds
    inHook = nil
    return ...
  end

  local hook_func = function(...)
    if (inHook) then
      return realFunc(...)
    end

    inHook = true
    t = spGetTimer()
    s = collectgarbage("count")
    return helper_func(realFunc(...))
  end

  listOfHooks[hook_func] = true

  return hook_func
end

local function ArrayInsert(t, f, g)
  if (f) then
    local layer = g.whInfo.layer
    local index = 1
    for i,v in ipairs(t) do
      if (v == g) then
        return -- already in the table
      end
      if (layer >= v.whInfo.layer) then
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


local function StartHook()
  Spring.Echo("start profiling")

  local wh = widgetHandler

  local CallInsList = {}
  for name,e in pairs(wh) do
    local i = name:find("List")
    if (i)and(type(e)=="table") then
      CallInsList[#CallInsList+1] = name:sub(1,i-1)
    end
  end

  --// hook all existing callins
  for _,callin in ipairs(CallInsList) do
    local callinGadgets = wh[callin .. "List"]
    for _,w in ipairs(callinGadgets or {}) do
      w[callin] = Hook(w,callin)
    end
  end

  Spring.Echo("hooked all callins: OK")

  --// hook the UpdateCallin function

  oldUpdateWidgetCallIn =  wh.UpdateWidgetCallIn
  wh.UpdateWidgetCallIn = function(self,name,w)
    local listName = name .. 'List'
    local ciList = self[listName]
    if (ciList) then
      local func = w[name]
      if (type(func) == 'function') then
        if (not IsHook(func)) then
          w[name] = Hook(w,name)
        end
        ArrayInsert(ciList, func, w)
      else
        ArrayRemove(ciList, w)
      end
      self:UpdateCallIn(name)
    else
      print('UpdateWidgetCallIn: bad name: ' .. name)
    end
  end

  oldInsertWidget =  wh.InsertWidget
  widgetHandler.InsertWidget = function(self,widget)
    if (widget == nil) then
      return
    end

    oldInsertWidget(self,widget)

    for _,callin in ipairs(CallInsList) do
      local func = widget[callin]
      if (type(func) == 'function') then
        widget[callin] = Hook(widget,callin)
      end
    end
  end

  Spring.Echo("hooked UpdateCallin: OK")
end


local function StopHook()
  Spring.Echo("stop profiling")

  local wh = widgetHandler

  local CallInsList = {}
  for name,e in pairs(wh) do
    local i = name:find("List")
    if (i)and(type(e)=="table") then
      CallInsList[#CallInsList+1] = name:sub(1,i-1)
    end
  end

  --// unhook all existing callins
  for _,callin in ipairs(CallInsList) do
    local callinGadgets = wh[callin .. "List"]
    for _,w in ipairs(callinGadgets or {}) do
      if (w["_old" .. callin]) then
        w[callin] = w["_old" .. callin]
      end
    end
  end

  Spring.Echo("unhooked all callins: OK")

  --// unhook the UpdateCallin function
  wh.UpdateWidgetCallIn = oldUpdateWidgetCallIn
  wh.InsertWidget = oldInsertWidget

  Spring.Echo("unhooked UpdateCallin: OK")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local green = '\255\0\255\0'
local red = '\255\255\0\0'
local grey = '\255\150\150\150'
local white = '\255\255\255\255'
local grey = "\255\200\200\255"
local darkgrey = "\255\100\100\255"
local yellow = "\255\255\255\0"
local lilac = "\255\200\162\200"
local tomato = "\255\255\99\71"
local turqoise = "\255\48\213\200"
local lightgreen = "\255\160\255\160"

local title_colour = lightgreen
local totals_colour = grey
local info_colour = "\255\1\1\1"
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


  local startTimer

  function widget:Update()
    widgetHandler:RemoveWidgetCallIn("Update", self)
    StartHook()
    startTimer = Spring.GetTimer()
  end

  function widget:Shutdown()
    StopHook()
  end

local tick = 0.2
local averageTime = 2
local timeLoadAverages = {}
local spaceLoadAverages = {}

local function CalcLoad(old_load, new_load, t)
  return old_load*math.exp(-tick/t) + new_load*(1 - math.exp(-tick/t)) 
end

local maximum = 0
local avg = 0
local allOverTime = 0
local allOverTimeSec = 0
local allOverSpace = 0
local totalSpace = {}

local sortedList = {}
local function SortFunc(a,b)
    return a.plainname < b.plainname
end

local maxLines = 45
local deltaTime
local redStrength = {}

function DrawWidgetList(list,name,x,y,j)
    if j>=maxLines-5 then x = x - 350; j = 0; end
    j = j + 1
    gl.Text(title_colour..name.." WIDGETS", x+150, y-1-(12)*j, 10, "no")
    j = j + 2

    for i=1,#list do
      if j>=maxLines then x = x - 350; j = 0; end
      local v = list[i]
      local name = v.plainname
      local wname = v.fullname
      local tLoad = v.tLoad
	  local sLoad = v.sLoad
      local tColour = v.timeColourString
      local sColour = v.spaceColourString
      gl.Text(wname, x+150, y+1-(12)*j, 10, "no")
      gl.Text(tColour .. ('%.2f%%'):format(tLoad), x+60, y+1-(12)*j, 10, "no")
      gl.Text(sColour .. ('%.0f'):format(sLoad) .. 'Kb', x+105, y+1-(12)*j, 10, "no")

	  j = j + 1
    end

    gl.Text(totals_colour.."totals ("..string.lower(name)..")", x+150, y+1-(12)*j, 10, "no")
    gl.Text(totals_colour..('%.2f%%'):format(list.allOverTime), x+60, y+1-(12)*j, 10, "no")
    gl.Text(totals_colour..('%.0f'):format(list.allOverSpace) .. 'Kb', x+105, y+1-(12)*j, 10, "no")
    j = j + 1

    return x,j
end

function ColourString(R,G,B)
	R255 = math.floor(R*255)
    G255 = math.floor(G*255)
    B255 = math.floor(B*255)
    if (R255%10 == 0) then R255 = R255+1 end
    if (G255%10 == 0) then G255 = G255+1 end
    if (B255%10 == 0) then B255 = B255+1 end
	return "\255"..string.char(R255)..string.char(G255)..string.char(B255)
end

local minPerc = 0.005 -- above this value, we fade in how heavy we mark a widget
local maxPerc = 0.02 -- above this value, we mark a widget as heavy
local minFPS = 30 -- above this value, we fade out how red we mark heavy widgets
local maxFPS = 60 -- above this value, we don't mark any widgets red
local minSpace = 25 -- Kb
local maxSpace = 250

function CheckLoad(v) --tLoad is %
    local tTime = v.tTime
	local sLoad = v.sLoad
    local name = v.plainname
    local FPS = Spring.GetFPS()
    local u = math.exp(-deltaTime/5) --magic colour changing rate

    if tTime>maxPerc then tTime = maxPerc end
    if tTime<minPerc then tTime = minPerc end
    if FPS>maxFPS then FPS = maxFPS end
    if FPS<minFPS then FPS = minFPS end

	-- time
    local new_r = ((tTime-minPerc)/(maxPerc-minPerc)) * ((maxFPS-FPS)/(maxFPS-minFPS))
    redStrength[name..'_time'] = u*redStrength[name..'_time'] + (1-u)*new_r
    local r,g,b = 1, 1-redStrength[name.."_time"]*((255-64)/255), 1-redStrength[name.."_time"]*((255-64)/255)
    v.timeColourString = ColourString(r,g,b)
	
	-- space
	new_r = math.max(0,math.min(1,(sLoad-minSpace)/(maxSpace-minSpace)))
    redStrength[name..'_space'] = u*redStrength[name..'_space'] + (1-u)*new_r
	g = 1-redStrength[name.."_space"]*((255-64)/255)
	b = g
    v.spaceColourString = ColourString(r,g,b)
end

  function widget:DrawScreen()
    if not (next(callinTimes)) then
      return --// nothing to do
    end


    deltaTime = Spring.DiffTimers(Spring.GetTimer(),startTimer)

    -- sort & count timing
    if (deltaTime>=tick) then
      startTimer = Spring.GetTimer()
	  sortedList = {}

      maximum = 0
      avg = 0
      allOverTime = 0
      allOverSpace = 0
      local n = 1
      for wname,callins in pairs(callinTimes) do
        local t = 0 -- would call it time, but protected
        local cmax_t = 0
        local cmaxname_t = "-"
		local space = 0
        local cmax_space = 0
        local cmaxname_space = "-"
        for cname,callinStats in pairs(callins) do
          t = t + callinStats[1]
          if (callinStats[2]>cmax_t) then
            cmax_t = callinStats[2]
            cmaxname_t = cname
          end
          callinStats[1] = 0
		  
          space = space + callinStats[3]
          if (callinStats[4]>cmax_space) then 
            cmax_space = callinStats[4]
            cmaxname_space = cname
          end
          callinStats[3] = 0
        end

        local relTime = 100 * t / deltaTime
        timeLoadAverages[wname] = CalcLoad(timeLoadAverages[wname] or relTime, relTime, averageTime)
		
		local relSpace = space / deltaTime
		spaceLoadAverages[wname] = CalcLoad(spaceLoadAverages[wname] or relSpace, relSpace, averageTime)

        allOverTimeSec = allOverTimeSec + t

		local tLoad = timeLoadAverages[wname]
		local sLoad = spaceLoadAverages[wname]
        sortedList[n] = {plainname=wname, fullname=wname..' ('..cmaxname_t..','..cmaxname_space..')', tLoad=tLoad, sLoad=sLoad, tTime=t/deltaTime}
        allOverTime = allOverTime + tLoad
        allOverSpace = allOverSpace + sLoad
		avg = avg + tLoad
        if (maximum<tLoad) then maximum=tLoad end
        n = n + 1
      end
      avg = avg/n

      table.sort(sortedList,SortFunc)
    end

    if (not sortedList[1]) then
      return --// nothing to do
    end

    -- add to category and set colour
    local userList = {}
    local gameList = {}
    local specialList = {}
    userList.allOverTime = 0
    gameList.allOverTime = 0
    specialList.allOverTime = 0
    userList.allOverSpace = 0
    gameList.allOverSpace = 0
    specialList.allOverSpace = 0
    for i=1,#sortedList do
        redStrength[sortedList[i].plainname..'_time'] = redStrength[sortedList[i].plainname..'_time'] or 0
        redStrength[sortedList[i].plainname..'_space'] = redStrength[sortedList[i].plainname..'_space'] or 0
		CheckLoad(sortedList[i])
        if userWidgets[sortedList[i].plainname] then
            userList[#userList+1] = sortedList[i]
            userList.allOverTime = userList.allOverTime + sortedList[i].tLoad
            userList.allOverSpace = userList.allOverSpace + sortedList[i].sLoad
        elseif specialWidgets[sortedList[i].plainname] then
            specialList[#specialList+1] = sortedList[i]
            specialList.allOverTime = specialList.allOverTime + sortedList[i].tLoad
            specialList.allOverSpace = specialList.allOverSpace + sortedList[i].sLoad
        else
            gameList[#gameList+1] = sortedList[i]
            gameList.allOverTime = gameList.allOverTime + sortedList[i].tLoad
            gameList.allOverSpace = gameList.allOverSpace + sortedList[i].sLoad
        end
    end

    -- draw
    local vsx, vsy = gl.GetViewSizes()
    local x,y = vsx-450, vsy-150
  	local widgetScale = (1 + (vsx*vsy / 6500000))

	  gl.PushMatrix()
	    gl.Translate(vsx-(vsx*widgetScale),vsy-(vsy*widgetScale),0)
	    gl.Scale(widgetScale,widgetScale,1)

	    gl.Color(1,1,1,1)
	    gl.BeginText()
			local j = -1 --line number

	    x,j = DrawWidgetList(gameList,"GAME",x,y,j)
	    x,j = DrawWidgetList(specialList,"API & SPECIAL",x,y,j)
	    x,j = DrawWidgetList(userList,"USER",x,y,j)

	    if j>=maxLines-5 then x = x - 450; j = 0; end
	    j = j + 1
	    gl.Text(title_colour.."ALL", x+150, y-1-(12)*j, 10, "no")
	    j = j + 1

	    if j>=maxLines-7 then x = x - 450; j = 0; end
		j = j + 1
	    gl.Text(info_colour.."total percentage of running time spent in luaui", x+150, y-1-(12)*j, 10, "no")
	    gl.Text(info_colour..('%.1f%%'):format(allOverTime), x+65, y-1-(12)*j, 10, "no")
		j = j + 1
	    gl.Text(info_colour.."total rate (per sec) of mem allocation by luaui", x+150, y-1-(12)*j, 10, "no")
        gl.Text(info_colour..('%.0f'):format(allOverSpace) .. 'Kb', x+105, y+1-(12)*j, 10, "no")
	    
		--j = j + 1
	    --gl.Text(totals_colour.."total time", x+150, y-1-(12)*j, 10, "no")
	    --gl.Text(totals_colour..('%.2fs'):format(allOverTimeSec), x+65, y-1-(12)*j, 10, "no")
		j = j + 2
	    gl.Text(title_colour.."note: all data excludes load from executing GL calls", x+65, y-1-(12)*j, 10, "no")

	    gl.EndText()
		
	  gl.PopMatrix()
  end
  
  

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------