if not gadgetHandler:IsSyncedCode() then
	return
end

local gadgetEnabled

if Spring.GetModOptions().scoremode ~= "disabled" and Spring.GetModOptions().scoremode_chess then
	gadgetEnabled = true
else
	gadgetEnabled = false
end

local pveEnabled = Spring.Utilities.Gametype.IsPvE()
local teams = Spring.GetTeamList()
controlAITeams = {}
local controlAIExists = false
for i = 1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI ~= "" then
		if luaAI == "ControlModeAI" then
			controlAITeams[teams[i]] = true
			controlAIExists = true
		end
	end
end

if pveEnabled then
	Spring.Echo("[ControlVictoryAI] Deactivated because Raptors or Scavengers are present!")
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
	  license   = "GNU GPL, v2 or later",
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

local capturePointRadius
if Spring.GetModOptions().usemexconfig then
	capturePointRadius = 100
else
	capturePointRadius = 150
end
local capturePointRadius = math.floor(capturePointRadius*0.75)
local AIMainAttackers = {}
local AIDiverseAttackers = {}
local AIDefenders = {}
local AIMainAttackersCount = {}
local AIDiverseAttackersCount = {}
local AIBuildersCount = {}
local AIDefendersCount = {}
local AIBuilders = {}
local AIBuilderBuildoptions = {}



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
	local unitDefID = Spring.GetUnitDefID(unitID)
	local unitPositionX, unitPositionY, unitPositionZ = Spring.GetUnitPosition(unitID)
	local position = {x=unitPositionX, y=unitPositionY, z=unitPositionZ}
	for i = 1, #controlPoints do
		local point = controlPoints[i]
		local pointAlly = controlPoints[i].pointOwner
		if pointAlly == unitAllyTeam then
			local pointPos = controlPoints[i].pointPosition
			local dist = distance(position, pointPos)
			local y = Spring.GetGroundHeight(pointPos.x, pointPos.z)
			local unreachable = true
			if (-(UnitDefs[unitDefID].minWaterDepth) > y) and (-(UnitDefs[unitDefID].maxWaterDepth) < y) or UnitDefs[unitDefID].canFly then
				unreachable = false
			end
			if unreachable == false and (not bestDistance or dist < bestDistance) then
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
	local unitDefID = Spring.GetUnitDefID(unitID)
	local unitPositionX, unitPositionY, unitPositionZ = Spring.GetUnitPosition(unitID)
	local position = {x=unitPositionX, y=unitPositionY, z=unitPositionZ}
	for i = 1, #controlPoints do
		local point = controlPoints[i]
		local pointAlly = controlPoints[i].pointOwner
		if pointAlly ~= unitAllyTeam then
			local pointPos = controlPoints[i].pointPosition
			local dist = distance(position, pointPos)
			local y = Spring.GetGroundHeight(pointPos.x, pointPos.z)
			local unreachable = true
			if (-(UnitDefs[unitDefID].minWaterDepth) > y) and (-(UnitDefs[unitDefID].maxWaterDepth) < y) or UnitDefs[unitDefID].canFly then
				unreachable = false
			end
			if unreachable == false and (not bestDistance or dist < bestDistance) then
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
	local unitDefID = Spring.GetUnitDefID(unitID)
	local unitPositionX, unitPositionY, unitPositionZ = Spring.GetUnitPosition(unitID)
	local position = {x=unitPositionX, y=unitPositionY, z=unitPositionZ}
	for i = 1,1000 do
		local r = math.random(1,#controlPoints)
		local point = controlPoints[r]
		local pointAlly = controlPoints[r].pointOwner
		local pointPos = controlPoints[r].pointPosition
		local y = Spring.GetGroundHeight(pointPos.x, pointPos.z)
		local unreachable = true
		if (-(UnitDefs[unitDefID].minWaterDepth) > y) and (-(UnitDefs[unitDefID].maxWaterDepth) < y) or UnitDefs[unitDefID].canFly then
			unreachable = false
		end
		if unreachable == false and pointAlly == unitAllyTeam then
			pos = pointPos
			break
		end
	end
	return pos
end

function GetRandomEnemyPoint(unitID)
	local pos
	local controlPoints = controlPointsList
	local unitAllyTeam = Spring.GetUnitAllyTeam(unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	local unitPositionX, unitPositionY, unitPositionZ = Spring.GetUnitPosition(unitID)
	local position = {x=unitPositionX, y=unitPositionY, z=unitPositionZ}
	for i = 1,1000 do
		local r = math.random(1,#controlPoints)
		local point = controlPoints[r]
		local pointAlly = controlPoints[r].pointOwner
		local pointPos = controlPoints[r].pointPosition
		local y = Spring.GetGroundHeight(pointPos.x, pointPos.z)
		local unreachable = true
		if (-(UnitDefs[unitDefID].minWaterDepth) > y) and (-(UnitDefs[unitDefID].maxWaterDepth) < y) or UnitDefs[unitDefID].canFly then
			unreachable = false
		end
		if unreachable == false and pointAlly ~= unitAllyTeam then
			pos = pointPos
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
								Spring.GiveOrderToUnit(unitID,CMD.MOVE_STATE,{2},0)
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
								Spring.GiveOrderToUnit(unitID,CMD.MOVE_STATE,{2},0)
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
								Spring.GiveOrderToUnit(unitID,CMD.MOVE_STATE,{2},0)
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
					if AIBuilders[unitID] and Spring.GetCommandQueue(unitID, 0) <= 5 then
						local rawPos = GetRandomAllyPoint(unitID)
						if rawPos then
							local posx = rawPos.x
							local posz = rawPos.z
							local posy = Spring.GetGroundHeight(posx, posz)
							if posx then
								local pickedBuilding = AIBuilderBuildoptions[unitID][math.random(1,#AIBuilderBuildoptions[unitID])]
								if UnitDefs[pickedBuilding].weapons and #UnitDefs[pickedBuilding].weapons > 0 then
									Spring.GiveOrderToUnit(unitID,CMD.MOVE_STATE,{2},0)
									Spring.GiveOrderToUnit(unitID, -pickedBuilding, {posx+math.random(-capturePointRadius*3,capturePointRadius*3), posy, posz+math.random(-capturePointRadius*3,capturePointRadius*3)}, {"shift", "alt", "ctrl"})
								end
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
			if not AIBuildersCount[unitTeam] then AIBuildersCount[unitTeam] = 0 end

			if UnitDefs[unitDefID].buildOptions and #UnitDefs[unitDefID].buildOptions > 0 then
				AIBuilders[unitID] = true
				AIBuilderBuildoptions[unitID] = UnitDefs[unitDefID].buildOptions
				AIBuildersCount[unitTeam] = AIBuildersCount[unitTeam] + 1
			end

			if not AIBuilders[unitID] then
				if AIMainAttackersCount[unitTeam] < AIDiverseAttackersCount[unitTeam]*5 then -- and AIMainAttackersCount[unitTeam] < AIDefendersCount[unitTeam]
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
	if UnitDefs[unitDefID].canbuild then
		AIBuilders[unitID] = nil
		AIBuilderBuildoptions[unitID] = nil
		AIBuildersCount[unitTeam] = AIBuildersCount[unitTeam] - 1
	end

	if controlAITeams[unitTeam] then

	end
end
