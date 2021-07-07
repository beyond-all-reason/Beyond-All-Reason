if not gadgetHandler:IsSyncedCode() then
    return
end

local gadgetEnabled

if Spring.GetModOptions and (Spring.GetModOptions().scoremode or "disabled") ~= "disabled" then
    gadgetEnabled = true
else
    gadgetEnabled = false
end

local chickensEnabled = false
local teams = Spring.GetTeamList()
controlAITeams = {}
local controlAIExists = false
for i = 1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI ~= "" then
		if luaAI == "Chicken: Very Easy" or
			luaAI == "Chicken: Easy" or
			luaAI == "Chicken: Normal" or
			luaAI == "Chicken: Hard" or
			luaAI == "Chicken: Very Hard" or
			luaAI == "Chicken: Epic!" or
			luaAI == "Chicken: Custom" or
			luaAI == "Chicken: Survival" or
			luaAI == "ScavengersAI" then
			chickensEnabled = true
		end
        if luaAI == "ControlModeAI" then
            controlAITeams[teams[i]] = true
            controlAIExists = true
        end
	end
end

if chickensEnabled then
	Spring.Echo("[ControlVictoryAI] Deactivated because Chickens or Scavengers are present!")
	gadgetEnabled = false
end

if controlAIExists == false then
	Spring.Echo("[ControlVictoryAI] Deactivated because there's no ControlAI present.")
	gadgetEnabled = false
end

function gadget:GetInfo()
    return {
      name      = "Control Victory Chess AI",
      desc      = "123",
      author    = "Damgam",
      date      = "2021",
      layer     = -100,
      enabled   = gadgetEnabled,
    }
end

local function distance(pos1,pos2)
	local xd = pos1.x-pos2.x
	local yd = pos1.z-pos2.z
	local dist = math.sqrt(xd*xd + yd*yd)
	return dist
end

local capturePointRadius = tonumber(Spring.GetModOptions().captureradius) or 250
local capturePointRadius = math.floor(capturePointRadius*0.75)
local AIMainAttackers = {}
local AIDiverseAttackers = {}
local AIDefenders = {}
local AIMainAttackersCount = {}
local AIDiverseAttackersCount = {}
local AIDefendersCount = {}
local AIBuilders = {}



function GetControlPoints()
	--if controlPoints then return controlPoints end
	controlPoints = {}
	if Script.LuaRules('ControlPoints') then
		local rawPoints = Script.LuaRules.ControlPoints() or {}
		for id = 1, #rawPoints do
			local rawPoint = rawPoints[id]
            local rawPoint = rawPoint
            local pointID = id
            local pointOwner = rawPoint.owner
            local pointPosition = {x=rawPoint.x, y=rawPoint.y, z=rawPoint.z}
            local point = {pointID=pointID, pointPosition=pointPosition, pointOwner=pointOwner}
			controlPoints[id] = point
		end
	end
	return controlPoints
end

function GetClosestAllyPoint(unitID)
	local pos
	local bestDistance
	local controlPoints = controlPointsList
    local unitAllyTeam = Spring.GetUnitAllyTeam(unitID)
    local unitPositionX, unitPositionY, unitPositionZ = Spring.GetUnitPosition(unitID)
    local position = {x=unitPositionX, y=unitPositionY, z=unitPositionZ}
	for i = 1, #controlPoints do
		local point = controlPoints[i]
		local pointAlly = controlPoints[i].pointOwner
		if pointAlly == unitAllyTeam then
			local pointPos = controlPoints[i].pointPosition
			local dist = distance(position, pointPos)
			if not bestDistance or dist < bestDistance then
				bestDistance = dist
				pos = pointPos
			end
		end
	end
	return pos
end

function GetClosestEnemyPoint(unitID)
	local pos
	local bestDistance
	local controlPoints = controlPointsList
    local unitAllyTeam = Spring.GetUnitAllyTeam(unitID)
    local unitPositionX, unitPositionY, unitPositionZ = Spring.GetUnitPosition(unitID)
    local position = {x=unitPositionX, y=unitPositionY, z=unitPositionZ}
	for i = 1, #controlPoints do
		local point = controlPoints[i]
		local pointAlly = controlPoints[i].pointOwner
		if pointAlly ~= unitAllyTeam then
			local pointPos = controlPoints[i].pointPosition
			local dist = distance(position, pointPos)
			if not bestDistance or dist < bestDistance then
				bestDistance = dist
				pos = pointPos
			end
		end
	end
	return pos
end

function GetRandomAllyPoint(unitID)
	local pos
	local controlPoints = controlPointsList
	local unitAllyTeam = Spring.GetUnitAllyTeam(unitID)
    local unitPositionX, unitPositionY, unitPositionZ = Spring.GetUnitPosition(unitID)
	local position = {x=unitPositionX, y=unitPositionY, z=unitPositionZ}
	for i = 1,100 do 
		local r = math.random(1,#controlPoints)
		local point = controlPoints[r]
		local pointAlly = controlPoints[r].pointOwner
		if pointAlly == unitAllyTeam then
			pos = controlPoints[r].pointPosition
			break
		end
	end
	return pos
end

function GetRandomEnemyPoint(unitID)
	local pos
	local controlPoints = controlPointsList
	local unitAllyTeam = Spring.GetUnitAllyTeam(unitID)
    local unitPositionX, unitPositionY, unitPositionZ = Spring.GetUnitPosition(unitID)
	local position = {x=unitPositionX, y=unitPositionY, z=unitPositionZ}
	for i = 1,100 do 
		local r = math.random(1,#controlPoints)
		local point = controlPoints[r]
		local pointAlly = controlPoints[r].pointOwner
		if pointAlly ~= unitAllyTeam then
			pos = controlPoints[r].pointPosition
			break
		end
	end
	return pos
end

local AITeamTurn = 0
function gadget:GameFrame(n)
    if n%30 == 0 then
        controlPointsList = GetControlPoints()
    end
    if n%30 == 0 then
        if AITeamTurn > teams[#teams] then
            AITeamTurn = 0
        else
            AITeamTurn = AITeamTurn + 1
        end
        for i = 1,#teams do
            if controlAITeams[teams[i]] and teams[i] == AITeamTurn then
                local teamID = teams[i]
                local units = Spring.GetTeamUnits(teamID)
                for i = 1,#units do
                    local unitID = units[i]
					if AIMainAttackers[unitID] then
						local rawPos = GetClosestEnemyPoint(unitID)
						if rawPos then
							local posx = rawPos.x
							local posz = rawPos.z
							local posy = Spring.GetGroundHeight(posx, posz)
							if posx then
								Spring.GiveOrderToUnit(unitID, CMD.FIGHT,  {posx+math.random(-capturePointRadius,capturePointRadius), posy, posz+math.random(-capturePointRadius,capturePointRadius)}, {"alt", "ctrl"})
							end
						end
					end
					if AIDiverseAttackers[unitID] and Spring.GetCommandQueue(unitID, 0) <= 0 then
						local rawPos = GetRandomEnemyPoint(unitID)
						if rawPos then
							local posx = rawPos.x
							local posz = rawPos.z
							local posy = Spring.GetGroundHeight(posx, posz)
							if posx then
								Spring.GiveOrderToUnit(unitID, CMD.FIGHT,  {posx-(capturePointRadius*0.8), posy, posz-(capturePointRadius*0.8)}, {"alt", "ctrl"})
								Spring.GiveOrderToUnit(unitID, CMD.PATROL,  {posx, posy, posz-(capturePointRadius*0.95)}, {"shift", "alt", "ctrl"})
								Spring.GiveOrderToUnit(unitID, CMD.PATROL,  {posx+(capturePointRadius*0.8), posy, posz-(capturePointRadius*0.8)}, {"shift", "alt", "ctrl"})
								Spring.GiveOrderToUnit(unitID, CMD.PATROL,  {posx+(capturePointRadius*0.95), posy, posz}, {"shift", "alt", "ctrl"})
								Spring.GiveOrderToUnit(unitID, CMD.PATROL,  {posx+(capturePointRadius*0.8), posy, posz+(capturePointRadius*0.8)}, {"shift", "alt", "ctrl"})
								Spring.GiveOrderToUnit(unitID, CMD.PATROL,  {posx, posy, posz+(capturePointRadius*0.95)}, {"shift", "alt", "ctrl"})
								Spring.GiveOrderToUnit(unitID, CMD.PATROL,  {posx-(capturePointRadius*0.8), posy, posz+(capturePointRadius*0.8)}, {"shift", "alt", "ctrl"})
								Spring.GiveOrderToUnit(unitID, CMD.PATROL,  {posx-(capturePointRadius*0.95), posy, posz}, {"shift", "alt", "ctrl"})
							end
						end
					end
					if AIDefenders[unitID] and Spring.GetCommandQueue(unitID, 0) <= 0 then
						local rawPos = GetRandomAllyPoint(unitID)
						if rawPos then
							local posx = rawPos.x
							local posz = rawPos.z
							local posy = Spring.GetGroundHeight(posx, posz)
							if posx then
								Spring.GiveOrderToUnit(unitID, CMD.FIGHT,  {posx-(capturePointRadius*0.8), posy, posz-(capturePointRadius*0.8)}, {"alt", "ctrl"})
								Spring.GiveOrderToUnit(unitID, CMD.PATROL,  {posx, posy, posz-(capturePointRadius*0.95)}, {"shift", "alt", "ctrl"})
								Spring.GiveOrderToUnit(unitID, CMD.PATROL,  {posx+(capturePointRadius*0.8), posy, posz-(capturePointRadius*0.8)}, {"shift", "alt", "ctrl"})
								Spring.GiveOrderToUnit(unitID, CMD.PATROL,  {posx+(capturePointRadius*0.95), posy, posz}, {"shift", "alt", "ctrl"})
								Spring.GiveOrderToUnit(unitID, CMD.PATROL,  {posx+(capturePointRadius*0.8), posy, posz+(capturePointRadius*0.8)}, {"shift", "alt", "ctrl"})
								Spring.GiveOrderToUnit(unitID, CMD.PATROL,  {posx, posy, posz+(capturePointRadius*0.95)}, {"shift", "alt", "ctrl"})
								Spring.GiveOrderToUnit(unitID, CMD.PATROL,  {posx-(capturePointRadius*0.8), posy, posz+(capturePointRadius*0.8)}, {"shift", "alt", "ctrl"})
								Spring.GiveOrderToUnit(unitID, CMD.PATROL,  {posx-(capturePointRadius*0.95), posy, posz}, {"shift", "alt", "ctrl"})
							end
						end
					end
                end
            end
        end
    end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	--if UnitDefs[unitDefID].canmove then
		
		if controlAITeams[unitTeam] then
			if not AIMainAttackersCount[unitTeam] then AIMainAttackersCount[unitTeam] = 0 end
			if not AIDefendersCount[unitTeam] then AIDefendersCount[unitTeam] = 0 end
			if not AIDiverseAttackersCount[unitTeam] then AIDiverseAttackersCount[unitTeam] = 0 end
			
			
			if AIMainAttackersCount[unitTeam] < AIDiverseAttackersCount[unitTeam]*2 then -- and AIMainAttackersCount[unitTeam] < AIDefendersCount[unitTeam]
				AIMainAttackers[unitID] = true
				AIMainAttackersCount[unitTeam] = AIMainAttackersCount[unitTeam] + 1
			-- elseif AIDefendersCount[unitTeam] < AIDiverseAttackersCount[unitTeam] and GetRandomAllyPoint(unitID) then
			-- 	AIDefenders[unitID] = true
			-- 	AIDefendersCount[unitTeam] = AIDefendersCount[unitTeam] + 1
			else
				AIDiverseAttackers[unitID] = true
				AIDiverseAttackersCount[unitTeam] = AIDiverseAttackersCount[unitTeam] + 1
			end
		end
	--end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if AIMainAttackers[unitID] then
		AIMainAttackers[unitID] = nil
		AIMainAttackersCount[unitTeam] = AIMainAttackersCount[unitTeam] - 1
	end
	if AIDefenders[unitID] then
		AIDefenders[unitID] = nil
		AIDefendersCount[unitTeam] = AIDefendersCount[unitTeam] - 1
	end
	if AIDiverseAttackers[unitID] then
		AIDiverseAttackers[unitID] = nil
		AIDiverseAttackersCount[unitTeam] = AIDiverseAttackersCount[unitTeam] - 1
	end
	
	if controlAITeams[unitTeam] then

	end
end
