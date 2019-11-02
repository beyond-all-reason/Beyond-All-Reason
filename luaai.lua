--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  LuaAI.lua
--
--    List of LuaAIs supported by the mod.
--
--

local function checkAImode(modeName)
	local path = "luarules/gadgets/ai/byar/"..modeName.."/"
	if VFS.FileExists(path.."modules.lua") and VFS.FileExists(path.."behaviourfactory.lua") then
		return true
	end
	return false
end

local DAIlist = {}
local DAIModes = VFS.SubDirs("luarules/gadgets/ai/byar/")
for i,lmodeName in pairs(DAIModes) do
	local smodeName = string.sub(lmodeName, string.len("luarules/gadgets/ai/byar/") + 1, string.len(lmodeName) - 1)
	if checkAImode(smodeName) == true then
		DAIlist[#DAIlist+1] = { name = "DAI "..smodeName, desc = 'Shard by AF for Spring (Lua), '..smodeName }
	end
end

local prelist = {
  
  {
    name = 'Chicken: Very Easy',
    desc = 'Trivial Games'
  },
  {
    name = 'Chicken: Easy',
    desc = 'Normal Games'
  },
  {
    name = 'Chicken: Normal',
    desc = 'Average Games'
  },
  {
    name = 'Chicken: Hard',
    desc = 'Large Games'
  },
  {
    name = 'Chicken: Very Hard',
    desc = 'Hardcore Games'
  },
  {
    name = 'Chicken: Epic!',
    desc = 'Extreme Survival Games'
  },
  {
    name = 'Chicken: Custom',
    desc = 'Settings in ModOptions'
  },
  {
    name = 'Chicken: Survival',
    desc = 'Infinite Games'
  },
}

local finalList = DAIlist
for i,data in pairs(prelist) do
	finalList[#finalList + 1] = data
end

return finalList


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
