--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Widget Profiler",
    desc      = "",
    author    = "jK",
    version   = "2.0",
    date      = "2007,2008,2009",
    license   = "GNU GPL, v2 or later",
    layer     = math.huge,
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

-- special widgets (things with a right to high usage that the user should not touch!)
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
  widgetCallinTime[name] = widgetCallinTime[name] or {0,0}
  local timeStats = widgetCallinTime[name]

  local t

  local helper_func = function(...)
    local dt = spDiffTimers(spGetTimer(),t)
    timeStats[1] = timeStats[1] + dt
    timeStats[2] = timeStats[2] + dt
    inHook = nil
    return ...
  end

  local hook_func = function(...)
    if (inHook) then
      return realFunc(...)
    end

    inHook = true
    t = spGetTimer()
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
local loadAverages = {}

local function CalcLoad(old_load, new_load, t)
  return old_load*math.exp(-tick/t) + new_load*(1 - math.exp(-tick/t)) 
end

local maximum = 0
local avg = 0
local totalLoads = {}
local allOverTime = 0
local allOverTimeSec = 0

local sortedList = {}
local function SortFunc(a,b)
    return a.plainname < b.plainname
end

local maxLines = 50
local deltaTime
local redStrength = {}

function DrawWidgetList(list,name,x,y,j)
    if j>=maxLines-5 then x = x - 350; j = 0; end
    j = j + 1
    gl.Text("\255\160\255\160"..name.." WIDGETS", x+150, y-1-(12)*j, 10)
    j = j + 2
    
    for i=1,#list do
      if j>=maxLines then x = x - 350; j = 0; end
      local v = list[i]
      local name = v.plainname
      local wname = v.fullname
      local tLoad = v.tLoad
      local colour = v.colourString
      gl.Text(wname, x+150, y+1-(12)*j, 10)
      gl.Text(colour .. ('%.3f%%'):format(tLoad), x+105, y+1-(12)*j, 10)	  

	  j = j + 1
    end
    
    gl.Text("\255\255\064\064total load ("..string.lower(name)..")", x+150, y+1-(12)*j, 10)
    gl.Text("\255\255\064\064"..('%.3f%%'):format(list.allOverTime), x+105, y+1-(12)*j, 10)	  
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

local minTime = 0.005 -- above this value, we fade in how heavy we mark a widget
local maxTime = 0.02 -- above this value, we mark a widget as heavy
local minFPS = 30 -- above this value, we fade out how red we mark heavy widgets 
local maxFPS = 60 -- above this value, we don't mark any widgets red

function CheckLoad(v) --tLoad is %
    local tTime = v.tTime
    local name = v.plainname
    local FPS = Spring.GetFPS() 
    
    if tTime>maxTime then tTime = maxTime end
    if tTime<minTime then tTime = minTime end
    if FPS>maxFPS then FPS = maxFPS end
    if FPS<minFPS then FPS = minFPS end
    
    local new_r = ((tTime-minTime)/(maxTime-minTime)) * ((maxFPS-FPS)/(maxFPS-minFPS))
    local u = math.exp(-deltaTime/5) --magic colour changing rate
    redStrength[name] = u*redStrength[name] + (1-u)*new_r
    local r,g,b = 1, 1-redStrength[name]*((255-64)/255), 1-redStrength[name]*((255-64)/255)
    return ColourString(r,g,b)
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
	  
      totalLoads = {}
      maximum = 0
      avg = 0
      allOverTime = 0
      local n = 1
      for wname,callins in pairs(callinTimes) do
        local total = 0
        local cmax  = 0
        local cmaxname = ""
        for cname,timeStats in pairs(callins) do
          total = total + timeStats[1]
          if (timeStats[2]>cmax) then
            cmax = timeStats[2]
            cmaxname = cname
          end
          timeStats[1] = 0
        end

        local load = 100*total/deltaTime
        local load_avg = CalcLoad(loadAverages[wname] or load, load, averageTime)
		loadAverages[wname] = load_avg

        allOverTimeSec = allOverTimeSec + total

        local tLoad = loadAverages[wname]
        sortedList[n] = {plainname=wname, fullname=wname..'('..cmaxname..')', tLoad=tLoad, tTime=total/deltaTime}
        allOverTime = allOverTime + tLoad
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
    for i=1,#sortedList do
        redStrength[sortedList[i].plainname] = redStrength[sortedList[i].plainname] or 0
        if userWidgets[sortedList[i].plainname] then
            sortedList[i].colourString = CheckLoad(sortedList[i])
            userList[#userList+1] = sortedList[i]
            userList.allOverTime = userList.allOverTime + sortedList[i].tLoad
        elseif specialWidgets[sortedList[i].plainname] then
            sortedList[i].colourString = "\255\255\255\255"
            specialList[#specialList+1] = sortedList[i]
            specialList.allOverTime = specialList.allOverTime + sortedList[i].tLoad  
        else
            sortedList[i].colourString = CheckLoad(sortedList[i])
            gameList[#gameList+1] = sortedList[i]
            gameList.allOverTime = gameList.allOverTime + sortedList[i].tLoad
        end
    end
    
    -- draw
    local vsx, vsy = gl.GetViewSizes()
    local x,y = vsx-350, vsy-150

    gl.Color(1,1,1,1)
    gl.BeginText()
	local j = -1 --line number
    
    x,j = DrawWidgetList(gameList,"GAME",x,y,j)
    x,j = DrawWidgetList(specialList,"API & SPECIAL",x,y,j)
    x,j = DrawWidgetList(userList,"USER",x,y,j)
    
    if j>=maxLines-5 then x = x - 350; j = 0; end
    j = j + 1
    gl.Text("\255\180\255\180TOTAL", x+150, y-1-(12)*j, 10)
    j = j + 1

	j = j + 1
    gl.Text("\255\255\064\064total load", x+150, y-1-(12)*j, 10)
    gl.Text("\255\255\064\064"..('%.1f%%'):format(allOverTime), x+105, y-1-(12)*j, 10)
    j = j + 1
    gl.Text("\255\255\064\064total time", x+150, y-1-(12)*j, 10)
    gl.Text("\255\255\064\064"..('%.3fs'):format(allOverTimeSec), x+105, y-1-(12)*j, 10)
    gl.EndText()
  
  end
  
  

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------