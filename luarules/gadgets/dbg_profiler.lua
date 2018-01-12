-- $Id: dbg_profiler.lua 3171 2008-11-06 09:06:29Z det $
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Profiler",
    desc      = "",
    author    = "jK",
    date      = "2007,2008,2009",
    license   = "GNU GPL, v2 or later",
    layer     = math.huge,
    handler   = true,
    enabled   = true, --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local callinTimes       = {}
local callinTimesSYNCED = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local SCRIPT_DIR = Script.GetName() .. '/'

local Hook = function(g,name) return function(...) return g[name](...) end end --//place holder

local inHook = false
local listOfHooks = {}
setmetatable(listOfHooks, { __mode = 'k' })

local function IsHook(func)
  return listOfHooks[func]
end

if (gadgetHandler:IsSyncedCode()) then
  Hook = function (g,name)
    local origFunc = g[name]

    local hook_func = function(...)
      if (inHook) then
        return origFunc(...)
      end

      inHook = true
      SendToUnsynced("prf_started", g.ghInfo.name, name)
      local results = {origFunc(...)}
      SendToUnsynced("prf_finished", g.ghInfo.name, name)
      inHook = false
      return unpack(results)
    end

    listOfHooks[hook_func] = true --note: using function in keys is unsafe in synced code!!!

    return hook_func
  end
else
  Hook = function (g,name)
    local spGetTimer = Spring.GetTimer
    local spDiffTimers = Spring.DiffTimers
    local gadgetName = g.ghInfo.name

    local realFunc = g[name]

    if (gadgetName=="Profiler") then
      return realFunc
    end
    local gadgetCallinTime = callinTimes[gadgetName] or {}
    callinTimes[gadgetName] = gadgetCallinTime
    gadgetCallinTime[name] = gadgetCallinTime[name] or {0,0}
    local timeStats = gadgetCallinTime[name]

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
end

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

local hookset = false

local function StartHook()
  if (hookset) then return end
  hookset = true
  Spring.Echo("start profiling")

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

  Spring.Echo("hooked all callins: OK")

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

  Spring.Echo("hooked UpdateCallin: OK")
  return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (gadgetHandler:IsSyncedCode()) then

  function gadget:Initialize()
    gadgetHandler.actionHandler.AddChatAction(gadget, 'profile', StartHook,
      " : starts the gadget profiler (for debugging issues)"
    )
    --StartHook()
  end

  --function gadget:Shutdown()
  --end

  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
else
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------

  local startTimer
  local startTimerSYNCED
  local profile_unsynced = false
  local profile_synced = false

  local function UpdateDrawCallin()
    gadget.DrawScreen = gadget.DrawScreen_
    gadgetHandler:UpdateGadgetCallIn("DrawScreen", gadget)
  end
  
  local function Start(cmd, msg, words, playerID)
    if (Spring.GetLocalPlayerID() ~= playerID) then
      return
    end

    if (not profile_unsynced) then
      UpdateDrawCallin()
      --UpdateDrawCallin()    -- not sure why they added this line a 2nd time
      startTimer = Spring.GetTimer()
      StartHook()
      profile_unsynced = true
    end
  end
  local function StartSYNCED(cmd, msg, words, playerID)
    show = true
    if (Spring.GetLocalPlayerID() ~= playerID) then
      return
    end

    if (not profile_synced) then
      startTimerSYNCED = Spring.GetTimer()
      profile_synced = true
      UpdateDrawCallin()
      --UpdateDrawCallin()    -- not sure why they added this line a 2nd time
    end
  end
  local show = true
  local function StartBoth(cmd, msg, words, playerID)
    show = true
    Start(cmd, msg, words, playerID)
    StartSYNCED(cmd, msg, words, playerID)
  end

  local function Hide(cmd, msg, words, playerID)
    show = false
  end
  local function Show(cmd, msg, words, playerID)
    show = true
  end
    

  local timers = {}
  function SyncedCallinStarted(_,gname,cname)
    local t  = Spring.GetTimer()
    timers[#timers+1] = t
  end

  function SyncedCallinFinished(_,gname,cname)
    local dt = Spring.DiffTimers(Spring.GetTimer(),timers[#timers])
    timers[#timers]=nil

    local gadgetCallinTime = callinTimesSYNCED[gname] or {}
    callinTimesSYNCED[gname] = gadgetCallinTime
    gadgetCallinTime[cname] = gadgetCallinTime[cname] or {0,0}
    local timeStats = gadgetCallinTime[cname]

    timeStats[1] = timeStats[1] + dt
    timeStats[2] = timeStats[2] + dt
  end

  function gadget:Initialize()
    gadgetHandler.actionHandler.AddSyncAction(gadget, "prf_started",SyncedCallinStarted) 
    gadgetHandler.actionHandler.AddSyncAction(gadget, "prf_finished",SyncedCallinFinished) 

    gadgetHandler.actionHandler.AddChatAction(gadget, 'uprofile', Start,
      " : starts the gadget profiler (for debugging issues)"
    )
    gadgetHandler.actionHandler.AddChatAction(gadget, 'profile', StartSYNCED,"")
    gadgetHandler.actionHandler.AddChatAction(gadget, 'ap', StartBoth,"")
    gadgetHandler.actionHandler.AddChatAction(gadget, 'hideprofile', Hide,"")
    gadgetHandler.actionHandler.AddChatAction(gadget, 'showprofile', Show,"")
    --StartHook()
  end

local tick = 0.1
local averageTime = 5
local loadAverages = {}

local function CalcLoad(old_load, new_load, t)
  return old_load*math.exp(-tick/t) + new_load*(1 - math.exp(-tick/t)) 
  --return (old_load-new_load)*math.exp(-tick/t) + new_load
end

local maximum = 0
local maximumSYNCED = 0
local totalLoads = {}
local allOverTime = 0
local allOverTimeSYNCED = 0
local allOverTimeSec = 0

local sortedList = {}
local sortedListSYNCED = {}
local function SortFunc(a,b)
  --if (a[2]==b[2]) then
    return a[1]<b[1]
  --else
  --  return a[2]>b[2]
  --end
end

  function gadget:DrawScreen_()
  	if not show then return end
    if not (next(callinTimes)) then
        --Spring.Echo("no callin times in profiler!")
      return --// nothing to do
    end

    if (profile_unsynced) then
      local deltaTime = Spring.DiffTimers(Spring.GetTimer(),startTimer)
      if (deltaTime>=tick) then
        startTimer = Spring.GetTimer()

        totalLoads = {}
        maximum = 0
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
          loadAverages[wname] = CalcLoad(loadAverages[wname] or load, load, averageTime)

          allOverTimeSec = allOverTimeSec + total
 
          local tLoad = loadAverages[wname]
          sortedList[n] = {wname..'('..cmaxname..')',tLoad}
          allOverTime = allOverTime + tLoad
          if (maximum<tLoad) then maximum=tLoad end
          n = n + 1
        end

        table.sort(sortedList,SortFunc)
      end
    end

    if (profile_synced) then
      local deltaTimeSYNCED = Spring.DiffTimers(Spring.GetTimer(),startTimerSYNCED)
      if (deltaTimeSYNCED>=tick) then
        startTimerSYNCED = Spring.GetTimer()

        totalLoads = {}
        maximumSYNCED = 0
        allOverTimeSYNCED = 0
        local n = 1
        for wname,callins in pairs(callinTimesSYNCED) do
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

          local load = 100*total/deltaTimeSYNCED
          loadAverages[wname] = CalcLoad(loadAverages[wname] or load, load, averageTime)

          allOverTimeSec = allOverTimeSec + total
 
          local tLoad = loadAverages[wname]
          sortedListSYNCED[n] = {wname..'('..cmaxname..')',tLoad}
          allOverTimeSYNCED = allOverTimeSYNCED + tLoad
          if (maximumSYNCED<tLoad) then maximumSYNCED=tLoad end
          n = n + 1
        end

        table.sort(sortedListSYNCED,SortFunc)
      end
    end

    if (not sortedList[1]) then
      return --// nothing to do
    end

    local vsx, vsy = gl.GetViewSizes()
    --local x,y = vsx-1050, vsy-100
    local x,y = vsx-450, vsy-100
  	local widgetScale = (1 + (vsx*vsy / 7500000))
	  gl.PushMatrix()
	    gl.Translate(vsx-(vsx*widgetScale),vsy-(vsy*widgetScale),0)
	    gl.Scale(widgetScale,widgetScale,1)
  	
    local maximum_ = (maximumSYNCED > maximum) and (maximumSYNCED) or (maximum)

    gl.Color(1,1,1,1)
    gl.BeginText()
    
    if (profile_unsynced) then    
      y = y - 24
      gl.Text("UNSYNCED", x+115, y-3, 12, "noc")
      y = y - 5

    for i=1,#sortedList do
        local v = sortedList[i]
        local wname = v[1]
        local tLoad = v[2]
        if maximum > 0 then
          gl.Rect(x+100-tLoad/maximum_*100, y+1-(12)*i, x+100, y+9-(12)*i)
        end
        gl.Text(wname, x+150, y+1-(12)*i, 10, "o")
        gl.Text(('%.3f%%'):format(tLoad), x+105, y+1-(12)*i, 10, "o")
      end
    end
    local j = 0
    if (profile_synced) then
      x = x - 300

      --gl.Rect(x, y+5-(12)*j, x+230, y+4-(12)*j)
      gl.Color(1,0,0)   
      y = y - 8
      gl.Text("SYNCED", x+115, y-3-(12)*j, 12, "noc")
      gl.Color(1,1,1,1)
      j = j
      y = y - 5

      for i=1,#sortedListSYNCED do
        local v = sortedListSYNCED[i]
        local wname = v[1]
        local tLoad = v[2]
        if maximum > 0 then
          gl.Rect(x+100-tLoad/maximum_*100, y+1-(12)*(j+i), x+100, y+9-(12)*(j+i))
        end
        gl.Text(wname, x+150, y+1-(12)*(j+i), 10, "o")
        gl.Text(('%.3f%%'):format(tLoad), x+105, y+1-(12)*(j+i), 10, "o")
        
        if i==50 then
            x = x - 300
            j = j - 50 --offset
        end
      end
    end
    --local i = #sortedList + #sortedListSYNCED + 2
    local i = #sortedListSYNCED + 1
    gl.Text("\255\255\064\064total time", x-110, y-1-(12)*(i+j), 10, "o")
    gl.Text("\255\255\064\064"..('%.3fs'):format(allOverTimeSec), x-10, y-1-(12)*(i+j), 10, "o")
    i = i+1
    gl.Text("\255\255\064\064total FPS cost", x-110, y-1-(12)*(i+j), 10, "o")
    gl.Text("\255\255\064\064"..('%.1f%%'):format(allOverTime+allOverTimeSYNCED), x-10, y-1-(12)*(i+j), 10, "o")
    gl.EndText()
    
	  gl.PopMatrix()
  end

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------