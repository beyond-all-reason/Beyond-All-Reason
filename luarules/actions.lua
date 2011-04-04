--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    actions
--  brief:   hooks for GotChatMsg() and RecvFromSynced() calls
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (actionHandler) then
  return actionHandler
end


--------------------------------------------------------------------------------

local chatActions = {}

local syncActions = {}


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local isSyncedCode = (SendToUnsynced ~= nil)

local function MakeWords(line)
  local words = {}
  for w in string.gmatch(line, "[^%s]+") do
    table.insert(words, w)
  end   
  return words
end

            
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Insertions
--

local function InsertCallInfo(callInfoList, gadget, func, help)
  local layer = gadget.ghInfo.layer
  local index = 1
  for i,ci in ipairs(callInfoList) do
    local g = ci[1]
    if (g == gadget) then
      return false  --  already in the table
    end
    if (layer >= g.ghInfo.layer) then
      index = i + 1
    end
  end
  table.insert(callInfoList, index, { func, gadget, help = help })
  return true
end


local function InsertAction(map, gadget, cmd, func, help)
  local callInfoList = map[cmd]
  if (callInfoList == nil) then
    callInfoList = {}
    map[cmd] = callInfoList
  end
  return InsertCallInfo(callInfoList, gadget, func, help)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Removals
--

local function RemoveCallInfo(callInfoList, gadget)
  local count = 0
  for i,callInfo in ipairs(callInfoList) do
    local g = callInfo[1]
    if (g == gadget) then
      table.remove(callInfoList, i)
      count = count + 1
      -- break
    end
  end
  return count
end


local function RemoveAction(map, gadget, cmd)
  local callInfoList = map[cmd]
  if (callInfoList == nil) then
    return false
  end
  local count = RemoveCallInfo(callInfoList, gadget)
  if (#callInfoList <= 0) then
    map[cmd] = nil
  end
  return (count > 0)
end


local function RemoveGadgetActions(gadget)
  local function clearActionList(actionMap)
    for cmd, callInfoList in pairs(actionMap) do
      RemoveCallInfo(callInfoList, gadget)
    end
  end
  clearActionList(chatActions)
  clearActionList(syncActions)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Add / Remove Chat Action
--


local function AddChatAction(gadget, cmd, func, help)
  return InsertAction(chatActions, gadget, cmd, func, help)
end


local function RemoveChatAction(gadget, cmd)
  return RemoveAction(chatActions, gadget, cmd)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Add / Remove Sync Action
--

local function AddSyncAction(gadget, cmd, func, help)
  return InsertAction(syncActions, gadget, cmd, func, help)
end


local function RemoveSyncAction(gadget, cmd)
  return RemoveAction(syncActions, gadget, cmd)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function EchoLines(msg)
  for line in string.gmatch(msg, '([^\n]+)\n?') do
    Spring.Echo(line)
  end
end


local function Help(playerID, cmd)
  if (cmd == nil) then
    -- print the list of commands, alphabetically
    local sorted = {}
    for name in pairs(chatActions) do
      table.insert(sorted, name)
    end
    table.sort(sorted)
    local str = Script.GetName() .. ' commands: '
    for _,name in ipairs(sorted) do
      str = str .. '  ' .. name
    end
    Spring.Echo(str)
    if (isSyncedCode) then
      SendToUnsynced(playerID, "help")
    end
  else
    local callInfoList = chatActions[cmd]
    if (not callInfoList) then
      if (not isSyncedCode) then
        Spring.Echo('unknown command:  ' .. cmd)
      end
    else
      for i,callInfo in ipairs(callInfoList) do
        if (callInfo.help) then
          EchoLines(cmd .. callInfo.help)
          return
        end
      end
    end
    if (isSyncedCode) then
      SendToUnsynced(playerID, "help " .. cmd)
    end
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function GotChatMsg(msg, playerID)
  local words = MakeWords(msg)
  local cmd = words[1]
  if (cmd == nil) then
    return false
  end

  local callInfoList = chatActions[cmd]
  if (callInfoList == nil) then
    if (cmd == 'help') then
      Help(playerID, words[2])
      return true
    end
    return false
  end

  -- remove the command from the words list and the raw line
  table.remove(words, 1)
  local _,_,msg = string.find(msg, "[%s]*[^%s]+[%s]+(.*)")
  if (msg == nil) then
    msg = ""  -- no args
  end

  for i,callInfo in ipairs(callInfoList) do
    local func = callInfo[1]
    -- local gadget = callInfo[2]
    if (func(cmd, msg, words, playerID)) then
      return true
    end
  end

  return false
end


local function RecvFromSynced(...)
  local arg1, arg2 = ...
  if (type(arg1) == 'string') then
    -- a raw sync msg
    local callInfoList = syncActions[arg1]
    if (callInfoList == nil) then
      return false
    end
    
    for i,callInfo in ipairs(callInfoList) do
      local func = callInfo[1]
      -- local gadget = callInfo[2]
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

local AH = {}

actionHandler = AH  -- set the global

AH.GotChatMsg     = GotChatMsg
AH.RecvFromSynced = RecvFromSynced

AH.AddChatAction    = AddChatAction
AH.AddSyncAction    = AddSyncAction
AH.RemoveChatAction = RemoveChatAction
AH.RemoveSyncAction = RemoveSyncAction

AH.RemoveGadgetActions = RemoveGadgetActions

AH.HaveChatAction = function() return (next(chatActions) ~= nil) end
AH.HaveSyncAction = function() return (next(syncActions) ~= nil) end

return AH


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
