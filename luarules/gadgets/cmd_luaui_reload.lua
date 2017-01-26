function gadget:GetInfo()
  return {
    name      = "LuaUI Reload",
    desc      = "Implements /luarules reloadluaui (because luaui cannot reload itself)",
    author    = "Bluestone",
    date      = "Feb 2015",
    license   = "Round Objects",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

if (gadgetHandler:IsSyncedCode()) then
	return
end

function LuaUIReload(cmd, line, words, playerID)
    if playerID and playerID==Spring.GetMyPlayerID() then
        Spring.SendCommands("luaui reload")
    end
end
    

function gadget:Initialize()
	gadgetHandler:AddChatAction('reloadluaui', LuaUIReload, "")
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction('reloadluaui')
end




--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
