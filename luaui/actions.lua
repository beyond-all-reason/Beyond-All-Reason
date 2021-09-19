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
  local text       = (string.find(types, "t") ~= nil)
  local keyPress   = (string.find(types, "p") ~= nil)
  local keyRepeat  = (string.find(types, "R") ~= nil)
  local keyRelease = (string.find(types, "r") ~= nil)
  return text, keyPress, keyRepeat, keyRelease
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Insertions
--

local function InsertCallInfo(callInfoList, widget, func, data)
  local layer = widget.whInfo.layer
  local index = 1
  for i,ci in ipairs(callInfoList) do
    local w = ci[1]
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
  if (not widget.whInfo) then
    error("LuaUI error adding action: please use widget:Initialize()")
  end

  -- default to text and keyPress  (not repeat or releases)
  local text, keyPress, keyRepeat, keyRelease = ParseTypes(types, "tpRr")
  
  local tSuccess, pSuccess, RSuccess, rSuccess = false, false, false, false

  if (text)       then tSuccess = add(self.textActions)       end
  if (keyPress)   then pSuccess = add(self.keyPressActions)   end
  if (keyRepeat)  then RSuccess = add(self.keyRepeatActions)  end
  if (keyRelease) then rSuccess = add(self.keyReleaseActions) end

  return tSuccess, pSuccess, RSuccess, rSuccess
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
  local count = 0
  for i,callInfo in ipairs(callInfoList) do
    local w = callInfo[1]
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
  local text, keyPress, keyRepeat, keyRelease = ParseTypes(types, "tpRr")
  
  local tSuccess, pSuccess, RSuccess, rSuccess = false, false, false, false

  if (text)       then tSuccess = remove(self.textActions)       end
  if (keyPress)   then pSuccess = remove(self.keyPressActions)   end
  if (keyRepeat)  then RSuccess = remove(self.keyRepeatActions)  end
  if (keyRelease) then rSuccess = remove(self.keyReleaseActions) end
  
  return tSuccess, pSuccess, RSuccess, rSuccess
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
    for cmd, callInfoList in pairs(actionMap) do
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

local function MakeWords(line)
  local words = {}
  for w in string.gmatch(line, "[^%s]+") do
    table.insert(words, w)
  end
  return words
end


local function MakeKeySetString(key, mods)
  local keyset = ""
  if (mods.alt)   then keyset = keyset .. "A+" end
  if (mods.ctrl)  then keyset = keyset .. "C+" end
  if (mods.meta)  then keyset = keyset .. "M+" end
  if (mods.shift) then keyset = keyset .. "S+" end
  local userSym, defSym = Spring.GetKeySymbol(key)
  return (keyset .. defSym)
end


local function TryAction(actionMap, cmd, optLine, optWords, isRepeat, release)
  local callInfoList = actionMap[cmd]
  if (callInfoList == nil) then
    return false
  end
  for i,callInfo in ipairs(callInfoList) do
    --local widget = callInfo[1]
    local func   = callInfo[2]
    local data   = callInfo[3]
    if (func(cmd, optLine, optWords, data, isRepeat, release)) then
      return true
    end
  end
  return false
end


function actionHandler:KeyAction(press, key, mods, isRepeat)
  local keyset = MakeKeySetString(key, mods)
  local defBinds = Spring.GetKeyBindings(keyset)
  if (defBinds) then
    local actionSet
    if (press) then
      actionSet = isRepeat and self.keyRepeatActions or self.keyPressActions
    else
      actionSet = self.keyReleaseActions
    end
    for b,bAction in ipairs(defBinds) do
      local bCmd, bOpts = next(bAction, nil)
		  local words = MakeWords(bOpts)
      if (TryAction(actionSet, bCmd, bOpts, words, isRepeat, not press)) then
        return true
      end
    end
  end
  return false
end


function actionHandler:TextAction(line)
  local words = MakeWords(line)
  local cmd = words[1]
  if (cmd == nil) then
    return false
  end
  -- remove the command from the words list and the raw line
  table.remove(words, 1)
  local _,_,line = string.find(line, "[^%s]+[%s]+(.*)")
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
    
    for i,callInfo in ipairs(callInfoList) do
      -- local widget = callInfo[1]
      local func = callInfo[2]
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
