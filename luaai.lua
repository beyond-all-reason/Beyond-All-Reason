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
		DAIlist[#DAIlist+1] = { name = "DAI "..smodeName, desc = 'Shard by AF for Spring (Lua), '..smodeName, version = "" }
	end
end

local DamgamAIList = {}
local DamgamAIVersions = VFS.SubDirs("luarules/gadgets/damgamai/")
for i,lmodeName in pairs(DamgamAIVersions) do
	local smodeName = string.sub(lmodeName, string.len("luarules/gadgets/damgamai/") + 1, string.len(lmodeName) - 1)
	DamgamAIList[#DamgamAIList+1] = { name = "DamgamAI "..smodeName, desc = 'DamgamAI - Experimental, dont use in normal play yet. '..smodeName, version = ""}
end
	

local prelist = {
  {
    name = 'ScavengersAI',
    desc = 'Infinite Games',
	version = ""
  },
  {
    name = 'Chicken: Very Easy',
    desc = 'Trivial Games',
	version = ""
  },
  {
    name = 'Chicken: Easy',
    desc = 'Normal Games',
	version = ""
  },
  {
    name = 'Chicken: Normal',
    desc = 'Average Games',
	version = ""
  },
  {
    name = 'Chicken: Hard',
    desc = 'Large Games',
	version = ""
  },
  {
    name = 'Chicken: Very Hard',
    desc = 'Hardcore Games',
	version = ""
  },
  {
    name = 'Chicken: Epic!',
    desc = 'Extreme Survival Games',
	version = ""
  },
  {
    name = 'Chicken: Custom',
    desc = 'Settings in ModOptions',
	version = ""
  },
  {
    name = 'Chicken: Survival',
    desc = 'Infinite Games',
	version = ""
  },

}

local function union( a, b )
    local result = {}
    for k,v in pairs ( a ) do
        table.insert( result, v )
    end
    for k,v in pairs ( b ) do
         table.insert( result, v )
    end
    return result
end


finalList = union(DAIlist,DamgamAIList)

for i,data in pairs(prelist) do
	finalList[#finalList + 1] = data
end

return finalList


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
