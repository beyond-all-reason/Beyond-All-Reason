local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Scav Lootbox Collector",
		desc = "Send transports to collect lone lootboxes and drop them somewhere in friendly area",
		author = "Damgam",
		date = "2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if (not gadgetHandler:IsSyncedCode()) or (not Spring.Utilities.Gametype.IsScavengers()) or Spring.GetModOptions().unit_restrictions_noair then
	return false
elseif Spring.Utilities.Gametype.IsRaptors() then
    return false
end

function SetCount(set)
    local count = 0
    for k in pairs(set) do
        count = count + 1
    end
    return count
end

-- number represents maximum tier of lootbox that can be picked up
local transportsList = {}

for unitDefName, tier in pairs({armatlas_scav = 1, corvalk_scav = 1, legatrans_scav = 1, armdfly_scav = 2, corseah_scav = 2, legstronghold_scav = 2}) do
	if UnitDefNames[unitDefName] then 
		transportsList[UnitDefNames[unitDefName].id] = tier
	end
end


local lootboxList = {}

for unitDefName, tier in pairs({lootboxbronze_scav = 1, lootboxsilver_scav  = 1, lootboxgold_scav = 2, lootboxplatinum_scav = 2}) do
	if UnitDefNames[unitDefName] then 
		lootboxList[UnitDefNames[unitDefName].id] = tier
	end
end

local spawnerList = {}
if UnitDefNames["scavbeacon_t1_scav"] then 
	spawnerList[UnitDefNames["scavbeacon_t1_scav"].id] = true
    spawnerList[UnitDefNames["scavbeacon_t2_scav"].id] = true
    spawnerList[UnitDefNames["scavbeacon_t3_scav"].id] = true
    spawnerList[UnitDefNames["scavbeacon_t4_scav"].id] = true
end

local teams = Spring.GetTeamList()
for _, teamID in ipairs(teams) do
    local teamLuaAI = Spring.GetTeamLuaAI(teamID)
    if (teamLuaAI and string.find(teamLuaAI, "Scavengers")) then
        scavTeamID = teamID
        scavAllyTeamID = select(6, Spring.GetTeamInfo(scavTeamID))
        break
    end
end

local aliveLootboxes = {}
local aliveLootboxesCount = 0
local aliveSpawners = {}
local aliveSpawnersCount = 0
local lastTransportSentFrame = 0
local handledLootboxesList = {}
local RaptorStartboxXMin, RaptorStartboxZMin, RaptorStartboxXMax, RaptorStartboxZMax = Spring.GetAllyTeamStartBox(scavAllyTeamID)

local config = VFS.Include('LuaRules/Configs/scav_spawn_defs.lua')

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if lootboxList[unitDefID] then
        aliveLootboxes[unitID] = lootboxList[unitDefID]
        aliveLootboxesCount = aliveLootboxesCount + 1
    end

    if spawnerList[unitDefID] then
        aliveSpawners[unitID] = true
        aliveSpawnersCount = aliveSpawnersCount + 1
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
    if aliveLootboxes[unitID] then
        aliveLootboxes[unitID] = nil
        aliveLootboxesCount = aliveLootboxesCount - 1
    end

    if aliveSpawners[unitID] then
        aliveSpawners[unitID] = nil
        aliveSpawnersCount = aliveSpawnersCount - 1
    end
end

function gadget:GameFrame(frame)
    if frame%30 == 12 and Spring.GetGameRulesParam("scavBossAnger") >= 1 and Spring.GetGameRulesParam("scavTechAnger") >= config.airStartAnger then
        if aliveLootboxesCount > 0 and aliveSpawnersCount > 0 then
            if SetCount(handledLootboxesList) > 0 then
                handledLootboxesList = {}
            end
            if frame-math.ceil(18000/aliveLootboxesCount) > lastTransportSentFrame then -- 10 minutes for 1 lootbox alive
                local targetLootboxID = -1
                local loopCount = 0
                local success = false
                for lootboxID, lootboxTier in pairs(aliveLootboxes) do
                    local lootboxPosX, lootboxPosY, lootboxPosZ = Spring.GetUnitPosition(lootboxID)
                    if (lootboxPosX) and not GG.IsPosInRaptorScum(lootboxPosX, lootboxPosY, lootboxPosZ) then
                        if math.random(0,aliveLootboxesCount) == 0 and not handledLootboxesList[lootboxID] then
                            for transportDefID, transportTier in pairs(transportsList) do
                                if math.random(0,SetCount(transportsList)) == 0 and transportTier == lootboxTier and not handledLootboxesList[lootboxID] then
                                    for spawnerID, _ in pairs(aliveSpawners) do
                                        if math.random(0,SetCount(aliveSpawners)) == 0 and not handledLootboxesList[lootboxID] then
                                            targetLootboxID = lootboxID
                                            local spawnerPosX, spawnerPosY, spawnerPosZ = Spring.GetUnitPosition(spawnerID)
                                            for j = 1,5 do
                                                if math.random() <= config.spawnChance then
                                                    local transportID = Spring.CreateUnit(transportDefID, spawnerPosX+math.random(-1024, 1024), spawnerPosY+100, spawnerPosZ+math.random(-1024, 1024), math.random(0,3), scavTeamID)
                                                    if transportID then
                                                        handledLootboxesList[targetLootboxID] = true
                                                        success = true
                                                        lastTransportSentFrame = frame
                                                        Spring.GiveOrderToUnit(transportID, CMD.LOAD_UNITS, {targetLootboxID}, {"shift"})
                                                        for i = 1,100 do
                                                            local randomX = math.random(0, Game.mapSizeX)
                                                            local randomZ = math.random(0, Game.mapSizeZ)
                                                            local randomY = math.max(0, Spring.GetGroundHeight(randomX, randomZ))
                                                            if GG.IsPosInRaptorScum(randomX, randomY, randomZ) then
                                                                Spring.GiveOrderToUnit(transportID, CMD.UNLOAD_UNITS, {randomX, randomY, randomZ, 1024}, {"shift"})
                                                            end
                                                            if i == 100 then
                                                                Spring.GiveOrderToUnit(transportID, CMD.MOVE, {randomX+math.random(-256,256), randomY, randomZ+math.random(-256,256)}, {"shift"})
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                        if success == true then
                                            break
                                        end
                                    end
                                end
                                if success == true then
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end