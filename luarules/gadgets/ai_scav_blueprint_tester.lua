
local cmdname = 'scavblptest'
local blueprintspath = "luarules/gadgets/scavengers/Blueprints/BYAR/Blueprints/"
local enabled = Spring.Utilities.IsDevMode() -- only enable in test environment
local queue = {}
local mapsizeX = Game.mapSizeX
local blueprintpositions = {}

local radius
local line = 1

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
      name      = "Scav Blueprint Tester",
      desc      = "Utility to test scav blueprints",
      author    = "Damgam",
      date      = "2021",
	  license   = "GNU GPL, v2 or later",
      layer     = -100,
      enabled   = enabled,
    }
end

if gadgetHandler:IsSyncedCode() then

    function gadget:RecvLuaMsg(msg, playerID)


        if string.find(msg, "scavblptest") then
            local filename = string.gsub(msg, "scavblptest ", "")
            local blueprints = VFS.Include(blueprintspath..filename..".lua")
            local high_radius = 0
            local lastposX = 0
            local lastposZ = 0

            if #blueprints > 0 then
                for i = 1,#blueprints do
                    radius = blueprints[i]().radius
                    if high_radius < radius then
                        high_radius = radius
                    end
                end
                for i = 1,#blueprints do
                    if i == 1 then
                        blueprintpositions[1] = {posx = high_radius*2, posz = high_radius*2}
                        lastposX = high_radius*2
                        lastposZ = high_radius*2
                    else
                        if lastposX+high_radius*2 > mapsizeX then
                            line = line+1
                            lastposX = 0
                            lastposZ = high_radius*line*2
                        end
                        blueprintpositions[i] = {posx = lastposX+high_radius*2, posz = lastposZ}
                        lastposX = lastposX+high_radius*2
                        lastposZ = lastposZ
                    end
                    Spring.MarkerAddPoint(blueprintpositions[i].posx, Spring.GetGroundHeight(blueprintpositions[i].posx, blueprintpositions[i].posz), blueprintpositions[i].posz , "#"..i )
                end

                for i = 1,#blueprints do
                    for j = 1,#blueprints[i]().buildings do
                        local blueprintTable = blueprints[i]().buildings[j]
                        if blueprintTable then
                            blueprintTable.basePosX = blueprintpositions[i].posx
                            blueprintTable.basePosZ = blueprintpositions[i].posz
                            local unitAndPos = blueprintTable
                            table.insert(queue, unitAndPos)
                        end
                    end
                end
            end
            return true
        end
    end

    function gadget:GameFrame(n)
        if #queue > 0 then
            local unitDefID = queue[1].unitDefID
            if unitDefID then
                Spring.Echo("UnitDefID: "..unitDefID)
                local basePosX = queue[1].basePosX
                Spring.Echo("basePosX: "..basePosX)
                local basePosZ = queue[1].basePosZ
                Spring.Echo("basePosZ: "..basePosZ)
                local xOffset = queue[1].xOffset
                Spring.Echo("xOffset: "..xOffset)
                local zOffset = queue[1].zOffset
                Spring.Echo("zOffset: "..zOffset)
                local direction = queue[1].direction
                Spring.Echo("direction: "..direction)
                local nonscavname = string.gsub(UnitDefs[unitDefID].name, "_scav", "")
				if UnitDefNames[nonscavname] then
					local nonscavDefID = UnitDefNames[nonscavname].id
					Spring.CreateUnit(nonscavDefID, basePosX+xOffset, Spring.GetGroundHeight(basePosX+xOffset, basePosZ+zOffset), basePosZ+zOffset, direction, 0)
				end
            end
            table.remove(queue, 1)
        end
    end
else

    function gadget:Initialize()
		gadgetHandler:AddChatAction(cmdname, RequestScavTest)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction(cmdname)
	end

    function RequestScavTest(cmd, line, words, playerID)
        if words and #words == 1 then
            Spring.SendLuaRulesMsg("scavblptest "..words[1])
        else
            Spring.SendMessageToPlayer(playerID, "Please specify which file you want to spawn (Enter the filename only without .lua)")
        end
    end

end
