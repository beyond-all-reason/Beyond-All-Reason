--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    actions.lua
--  brief:   action interface for text commands, and bound commands
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local actionHandler = {
  textActions       = {},
  keyPressActions   = {},
  keyRepeatActions  = {},
  keyReleaseActions = {},
  syncActions = {}
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function ParseTypes(types, def)
  if (type(types) ~= "string") then
    types = def
  end
  return (string.find(types, "t") ~= nil), -- text
        (string.find(types, "p") ~= nil), -- keyPress 
        (string.find(types, "R") ~= nil), -- keyRepeat
        (string.find(types, "r") ~= nil) -- keyRelease
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Insertions
--

local function InsertCallInfo(callInfoList, widget, func, data)
  local layer = widget.whInfo.layer
  local index, w = 1
  for i,ci in ipairs(callInfoList) do
    w = ci[1]
    if (w == widget) then
      return false  --  already in the table
    end
    if (layer >= w.whInfo.layer) then
      index = i + 1
    end
  end
  table.insert(callInfoList, index, { widget, func, data })
  return true
end

function actionHandler:TSuccessTest(types, val)
  local text, keyPress, keyRepeat, keyRelease = ParseTypes(types, val)

  local tSuccess, pSuccess, RSuccess, rSuccess = false, false, false, false

  if (text)       then tSuccess = add(self.textActions)       end
  if (keyPress)   then pSuccess = add(self.keyPressActions)   end
  if (keyRepeat)  then RSuccess = add(self.keyRepeatActions)  end
  if (keyRelease) then rSuccess = add(self.keyReleaseActions) end

  return tSuccess, pSuccess, RSuccess, rSuccess
end

function actionHandler:AddAction(widget, cmd, func, data, types)
  local function add(actionMap)
    local callInfoList = actionMap[cmd]
    if (callInfoList == nil) then
      callInfoList = {}
      actionMap[cmd] = callInfoList
    end
    return InsertCallInfo(callInfoList, widget, func, data)
  end

  -- make sure that this is a fully initialized widget
  assert(widget.whInfo, "LuaUI error adding action: please use widget:Initialize()")

  -- default to text and keyPress  (not repeat or releases)
  return self:TSuccessTest(types, "tp")
end


local function AddMapAction(map, widget, cmd, func, data)
  local callInfoList = map[cmd]
  if (callInfoList == nil) then
    callInfoList = {}
    map[cmd] = callInfoList
  end
  return InsertCallInfo(callInfoList, widget, func, data)
end


function actionHandler:AddSyncAction(widget, cmd, func, data)
  return AddMapAction(self.syncActions, widget, cmd, func, data)
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Removals
--

local function RemoveCallInfo(callInfoList, widget)
  local count, w = 0
  for i,callInfo in ipairs(callInfoList) do
    w = callInfo[1]
    if (w == widget) then
      table.remove(callInfoList, i)
      count = count + 1
      -- break
    end
  end
  return count
end


function actionHandler:RemoveAction(widget, cmd, types)
  local function remove(actionMap)
    local callInfoList = actionMap[cmd]
    if (callInfoList == nil) then
      return false
    end
    local count = RemoveCallInfo(callInfoList, widget)
    if (#callInfoList <= 0) then
      actionMap[cmd] = nil
    end
    return (count > 0)
  end

  -- default to removing all
  return self:TSuccessTest(types, "tpRr")
end


local function RemoveMapAction(map, widget, cmd)
  local callInfoList = map[cmd]
  if (callInfoList == nil) then
    return false
  end
  local count = RemoveCallInfo(callInfoList, widget)
  if (#callInfoList <= 0) then
    map[cmd] = nil
  end
  return (count > 0)
end


function actionHandler:RemoveSyncAction(widget, cmd)
  return RemoveMapAction(self.syncActions, widget, cmd)
end


function actionHandler:RemoveWidgetActions(widget)
  local function clearActionList(actionMap)
    for _, callInfoList in pairs(actionMap) do
      RemoveCallInfo(callInfoList, widget)
    end
  end
  clearActionList(self.textActions)
  clearActionList(self.keyPressActions)
  clearActionList(self.keyRepeatActions)
  clearActionList(self.keyReleaseActions)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Calls
--


local function TryAction(actionMap, cmd, optLine, optWords, isRepeat, release, actions)
  local callInfoList = actionMap[cmd]
  local func, data
  if (callInfoList == nil) then
    return false
  end
  for _, callInfo in ipairs(callInfoList) do
    --local widget = callInfo[1]
    func   = callInfo[2]
    data   = callInfo[3]
    if (func(cmd, optLine, optWords, data, isRepeat, release, actions)) then
      return true
    end
  end
  return false
end


function actionHandler:KeyAction(press, _, _, isRepeat, _, actions)
  if (not(actions and next(actions))) then return false end

  local actionSet
  if (press) then
    actionSet = isRepeat and self.keyRepeatActions or self.keyPressActions
  else
    actionSet = self.keyReleaseActions
  end

  local cmd, extra, words
  for _, bAction in ipairs(actions) do
    cmd = bAction["command"]
    extra = bAction["extra"]
    words = string.split(extra)

    if (TryAction(actionSet, cmd, extra, words, isRepeat, not press, actions)) then
      return true
    end
  end

  return false
end


function actionHandler:TextAction(line)
  local words = string.split(line)
  local cmd = words[1]
  if (cmd == nil) then
    return false
  end
  -- remove the command from the words list and the raw line
  table.remove(words, 1)
  _,_,line = string.find(line, "[^%s]+[%s]+(.*)")
  if (line == nil) then
    line = ""  -- no args
  end
  return TryAction(self.textActions, cmd, line, words, false, nil)
end


function actionHandler:RecvFromSynced(...)
  local arg1, arg2 = ...
  if (type(arg1) == 'string') then
    -- a raw sync msg
    local callInfoList = self.syncActions[arg1]
    if (callInfoList == nil) then
      return false
    end
    local func
    for _,callInfo in ipairs(callInfoList) do
      -- local widget = callInfo[1]
      func = callInfo[2]
      if (func(...)) then
        return true
      end
    end
    return false
  end

  if (type(arg1) == 'number') then
    -- a proxied chat msg
    if (type(arg2) == 'string') then
      return GotChatMsg(arg2, arg1)
    end
    return false
  end

  return false -- unknown type
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

actionHandler.HaveSyncAction = function() return (next(self.syncActions) ~= nil) end

return actionHandler

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
