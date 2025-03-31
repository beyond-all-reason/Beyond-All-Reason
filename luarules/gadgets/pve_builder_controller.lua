local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "PvE Builder Controller",
		desc = "Gives extra orders to scav and raptor builders",
		author = "Damgam",
		date = "2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
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

local scavengerAITeamID = 999
--local raptorsAITeamID = 999

local teams = Spring.GetTeamList()
for i = 1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
		scavengerAITeamID = i - 1
		break
	end
end
--for i = 1, #teams do
--	local luaAI = Spring.GetTeamLuaAI(teams[i])
--	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'RaptorsAI' then
--		raptorsAITeamID = i - 1
--		break
--	end
--end

local builderDefs = {}
for unitDefID, data in pairs(UnitDefs) do
	if data.buildOptions and #data.buildOptions > 0 and (not data.customParams.nopvebuilder) then
		builderDefs[unitDefID] = {
            range = data.builddistance or 256,
            buildOptions = data.buildOptions,
            unitDefID = unitDefID,
            unitDefName = data.name,
            isFactory = data.isFactory,
        }
	end
end

local aliveBuilders = {}

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    --if builderDefs[unitDefID] and (unitTeam == scavengerAITeamID or unitTeam == raptorsAITeamID) then
    if builderDefs[unitDefID] and (unitTeam == scavengerAITeamID) then
        aliveBuilders[unitID] = builderDefs[unitDefID]
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
    if aliveBuilders[unitID] then
        aliveBuilders[unitID] = nil
    end
end

local lastTurretFrame = 0
function gadget:GameFrame(frame)
    if frame > lastTurretFrame + 150 then
        if frame%30 == 9 then
            for unitID, data in pairs(aliveBuilders) do
                if (Spring.GetUnitNearestEnemy(unitID, data.range*5, true) and math.random(0,15) == 0) or (data.isFactory) then
                    --Spring.Echo(data.unitDefName, "NearestEnemyInRange")
					local unitCommands = not data.isFactory and Spring.GetUnitCommands(unitID, 1) or {}
                    if (data.isFactory and #Spring.GetFullBuildQueue(unitID) < 5) or (not data.isFactory and (not unitCommands[1] or (unitCommands[1] and unitCommands[1].id > 0 and unitCommands[1].id ~= CMD.REPAIR))) then
                        --Spring.Echo(data.unitDefName, "Isn't building anything")
                        local turretOptions = {}
                        for buildOptionIndex, buildOptionID in pairs(data.buildOptions) do
                            --Spring.Echo("buildOptionID", buildOptionID, UnitDefs[buildOptionID].name)
                            if buildOptionID and (((not UnitDefs[buildOptionID].canAssist) and (not UnitDefs[buildOptionID].isFactory)) or (math.random(1,20) == 1 and UnitDefs[buildOptionID].isFactory)) then
                                turretOptions[#turretOptions+1] = buildOptionID
                                --Spring.Echo(data.unitDefName, UnitDefs[buildOptionID].name, "Is a turret")
                            end
                        end
                        if #turretOptions > 1 then
                            local turret = turretOptions[math.random(1, #turretOptions)]
                            local x,y,z = Spring.GetUnitPosition(unitID)
                            Spring.GiveOrderToUnit(unitID, -turret, {x+math.random(-data.range, data.range), y, z+math.random(-data.range, data.range)}, {})
                            if data.isFactory then
                                for i = 1,math.random(1,5) do
                                    Spring.GiveOrderToUnit(unitID, -turret, {x+math.random(-data.range, data.range), y, z+math.random(-data.range, data.range)}, {})
                                end
                            else
                                lastTurretFrame = frame
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end
