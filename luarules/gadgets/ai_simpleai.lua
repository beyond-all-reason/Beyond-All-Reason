local enabled = false
local teams = Spring.GetTeamList()
local SimpleAITeamIDs = {}
local SimpleAITeamIDsCount = 0
local SimpleCheaterAITeamIDs = {}
local SimpleCheaterAITeamIDsCount = 0

for i = 1,#teams do
	local teamID = teams[i]
	local luaAI = Spring.GetTeamLuaAI(teamID)
	if luaAI and luaAI ~= "" and (string.sub(luaAI, 1, 8) == 'SimpleAI' or string.sub(luaAI, 1, 15) == 'SimpleCheaterAI') then
		enabled = true
		SimpleAITeamIDsCount = SimpleAITeamIDsCount + 1
		SimpleAITeamIDs[SimpleAITeamIDsCount] = teamID
		if string.sub(luaAI, 1, 15) == 'SimpleCheaterAI' then
			SimpleCheaterAITeamIDsCount = SimpleCheaterAITeamIDsCount + 1
			SimpleCheaterAITeamIDs[SimpleCheaterAITeamIDsCount] = teamID
		end
	end
end

function gadget:GetInfo()
  return {
    name      = "SimpleAI",
    desc      = "123",
    author    = "Damgam",
    date      = "2020",
    layer     = -100,
    enabled   = enabled,
  }
end

-- lists

-- Arm
	local nameCommanderArm = "armcom"

-- Core
	local nameCommanderCor = "corcom"






















function gadget:GameOver()
	gadgetHandler:RemoveGadget(self)
end

if gadgetHandler:IsSyncedCode() then
	
	function gadget:GameFrame(n)
		if n%30 == 0 then
			for i = 1,#SimpleAITeamIDs do
				local teamID = SimpleAITeamIDs[i]
				local _,_,isDead,_,faction,allyTeamID = Spring.GetTeamInfo(teamID)
				--if not isDead then
					local mcurrent, mstorage, _, mincome, mexpense = Spring.GetTeamResources(teamID, "metal")
					local ecurrent, estorage, _, eincome, eexpense = Spring.GetTeamResources(teamID, "energy")
					for j = 1,#SimpleCheaterAITeamIDs do
						if teamID == SimpleCheaterAITeamIDs[j] then
							-- cheats
								Spring.SetTeamResource(teamID, "m", mstorage*0.5)
								Spring.SetTeamResource(teamID, "e", estorage*0.5)
						end
					end
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					local units = Spring.GetTeamUnits(teamID)
					for k = 1,#units do
						local unitID = units[k]
						local unitDefID = Spring.GetUnitDefID(unitID)
						local unitName = UnitDefs[unitDefID].name
						local unitHealth,unitMaxHealth,_,_,unitBuildProgress = Spring.GetUnitHealth(unitID)
						-- unitHealthPercentage = (unitHealth/unitMaxHealth)*100
						local unitMaxRange = Spring.GetUnitMaxRange(unitID)
						local unitCommands = Spring.GetCommandQueue(unitID, 0)
						local unitposx, unitposy, unitposz = Spring.GetUnitPosition(unitID)
						--Spring.Echo(faction)
						--if faction == "ARM" then
							
							-- builders
							if unitCommands == 0 then
								if unitName == "armcom" then
									Spring.GiveOrderToUnit(unitID, CMD.MOVE,{unitposx+math.random(-500,500),5000,unitposz+math.random(-500,500)}, {"shift", "alt", "ctrl"})
									break
								end
							end
							-- army
						--elseif faction == "CORE" then
							-- builders
							if unitCommands == 0 then
								if unitName == "corcom" then
									Spring.GiveOrderToUnit(unitID, CMD.MOVE,{unitposx+math.random(-500,500),5000,unitposz+math.random(-500,500)}, {"shift", "alt", "ctrl"})
									break
								end
							end
							-- army
						--end
					end
				--end
			end
		end
	end
end