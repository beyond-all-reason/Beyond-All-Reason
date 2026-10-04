local gadget = gadget ---@type Gadget

function gadget:GetInfo()
  return {
    name      = "LuaUI Reload",
    desc      = "Implements /luarules reloadluaui (because luaui cannot reload itself)",
    author    = "Bluestone",
    date      = "Feb 2015",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
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
