function gadget:GetInfo()
    return {
        name = "Raptor Area Healers",
        desc = "Area Heal raptors around raptor healers - healers don't heal each other.",
        author = "Damgam",
        date = "2023",
        license = "GNU GPL, v2 or later",
        layer = 0,
        enabled = true -- we don't need it for now, but might need it later.
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

if Spring.Utilities.Gametype.IsRaptors() then
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Raptor Defense Spawner Activated!")
elseif Spring.Utilities.Gametype.IsScavengers() then
    Spring.Log(gadget:GetInfo().name, LOG.INFO, "Scav Defense Spawner Activated!")
else
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Defense Spawner Deactivated!")
	return false
end

local spGetUnitHealth = Spring.GetUnitHealth
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitsInSphere = Spring.GetUnitsInSphere

local gaiaTeamID = Spring.GetGaiaTeamID()

local unitTeams = {}

local scavengerAITeamID = 999
local raptorsAITeamID = 999
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
		scavengerAITeamID = i - 1
		break
	end
end
for i = 1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'RaptorsAI' then
		raptorsAITeamID = i - 1
		break
	end
end

local aliveHealers = {}
local healersTable = {}
if Spring.Utilities.Gametype.IsRaptors() then
    healersTable[UnitDefNames["raptor_land_swarmer_heal_t1_v1"].id] = {
        healingpower = UnitDefNames["raptor_land_swarmer_heal_t1_v1"].repairSpeed,
        healingrange = UnitDefNames["raptor_land_swarmer_heal_t1_v1"].buildDistance*2,
        canbehealed = false,
    }
    healersTable[UnitDefNames["raptor_land_swarmer_heal_t2_v1"].id] = {
        healingpower = UnitDefNames["raptor_land_swarmer_heal_t2_v1"].repairSpeed,
        healingrange = UnitDefNames["raptor_land_swarmer_heal_t2_v1"].buildDistance*2,
        canbehealed = false,
    }
    healersTable[UnitDefNames["raptor_land_swarmer_heal_t3_v1"].id] = {
        healingpower = UnitDefNames["raptor_land_swarmer_heal_t3_v1"].repairSpeed,
        healingrange = UnitDefNames["raptor_land_swarmer_heal_t3_v1"].buildDistance*2,
        canbehealed = false,
    }
    healersTable[UnitDefNames["raptor_land_swarmer_heal_t4_v1"].id] = {
        healingpower = UnitDefNames["raptor_land_swarmer_heal_t4_v1"].repairSpeed,
        healingrange = UnitDefNames["raptor_land_swarmer_heal_t4_v1"].buildDistance*2,
        canbehealed = false,
    }
    healersTable[UnitDefNames["raptor_matriarch_healer"].id] = {
        healingpower = UnitDefNames["raptor_matriarch_healer"].repairSpeed,
        healingrange = UnitDefNames["raptor_matriarch_healer"].buildDistance*2,
        canbehealed = false,
    }
end

local unitBuildtime = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.isscavenger and unitDef.canRepair and unitDef.repairSpeed and unitDef.buildDistance then
		healersTable[unitDefID] = {
			healingpower = unitDef.repairSpeed*0.1,
			healingrange = unitDef.buildDistance*2,
			canbehealed = true,
		}
	end
	unitBuildtime[unitDefID] = unitDef.buildTime
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if healersTable[unitDefID] then
        aliveHealers[unitID] = {
			teamID = unitTeam,
            healingpower = healersTable[unitDefID].healingpower,
            healingrange = healersTable[unitDefID].healingrange,
            canbehealed = healersTable[unitDefID].canbehealed,
        }
    end
	unitTeams[unitID] = unitTeam
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
	aliveHealers[unitID] = nil
	unitTeams[unitID] = nil
end

function gadget:GameFrame(frame)
	local x,y,z,surroundingUnits,healedUnitID
    for unitID, statsTable in pairs(aliveHealers) do
        if unitID % 30 == frame % 30 and (statsTable.teamID == scavengerAITeamID or statsTable.teamID == raptorsAITeamID) then
            x,y,z = spGetUnitPosition(unitID)
            surroundingUnits = spGetUnitsInSphere(x, y, z, statsTable.healingrange)
            for i = 1, #surroundingUnits do
                healedUnitID = surroundingUnits[i]
                if not aliveHealers[healedUnitID] or (aliveHealers[healedUnitID].canbehealed and unitID ~= healedUnitID) then
                    if spAreTeamsAllied(statsTable.teamID, unitTeams[healedUnitID]) then
                        local oldHP, maxHP = spGetUnitHealth(healedUnitID)
                        if oldHP < maxHP then
                            local x2, y2, z2 = spGetUnitPosition(healedUnitID)
                            local surroundingUnits2 = spGetUnitsInSphere(x2, y2, z2, math.ceil(statsTable.healingrange))
                            local enemiesNearby = false
                            for i = 1, #surroundingUnits2 do
                                if unitTeams[surroundingUnits2[i]] ~= statsTable.teamID and unitTeams[surroundingUnits2[i]] ~= gaiaTeamID then
                                    enemiesNearby = true
                                    break
                                end
                            end
                            if not enemiesNearby then
                                local healedUnitBuildTime = unitBuildtime[Spring.GetUnitDefID(healedUnitID)].buildTime
                                local healValue = (maxHP/healedUnitBuildTime)*statsTable.healingpower
                                Spring.SetUnitHealth(healedUnitID, oldHP+healValue)
                                Spring.SpawnCEG("heal", x2, y2+10, z2, 0,1,0)
                            end
                        end
                    end
                end
            end
        end
    end
end
