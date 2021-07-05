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

function GetClosestUncapturedPoint(unitID)
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

local AITeamTurn = 0
function gadget:GameFrame(n)
    if n%300 == 0 then
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
                    local rawPos = GetClosestUncapturedPoint(units[i])
                    local posx = rawPos.x
                    local posy = rawPos.y
                    local posz = rawPos.z
                    Spring.GiveOrderToUnit(units[i], CMD.FIGHT,  {posx+math.random(-capturePointRadius,capturePointRadius), posy, posz+math.random(-capturePointRadius,capturePointRadius)}, {"alt", "ctrl"})
                end
            end
        end
    end
end

