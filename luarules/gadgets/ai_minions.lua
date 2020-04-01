if (Spring.GetModOptions and (tonumber(Spring.GetModOptions().minions) or 0) ~= 0) then
	enableMinions = true
else
	enableMinions = false
end

function gadget:GetInfo()
	return {
	name      = "Minions Spawner",
	desc      = "AAA",
	author    = "Damgam",
	date      = "2020",
	license   = "do whatever your want to do with it",
	layer     = 0,
	enabled   = enableMinions, --enabled by default
	}
end

local minions = {
"minionak",
"minionak",
"minionak",
"minionak",
"minionak",
"minionak",
"minionak",
"minionak",
"minionak",
"minionak",
"minionstorm",
"minionthud",
}

local minionTimer = 0
local minionCooldown = 30
local minionMax = 5
local spawnedMinions = 0
local aliveMinions = {}

if gadgetHandler:IsSyncedCode() then

function gadget:GameFrame(n)
	if n%30 == 0 then
		minionTimer = minionTimer + 1
		if minionTimer > minionCooldown then
			local choosenMinion = minions[math.random(1,#minions)]
			local allUnits = Spring.GetAllUnits()
			for i = 1,#allUnits do
				local unitID = allUnits[i]
				local unitDefID = Spring.GetUnitDefID(unitID)
				local unitName = UnitDefs[unitDefID].name
				if unitName == "corcom" or unitName == "armcom" then
					local comPosX,comPosY,comPosZ = Spring.GetUnitPosition(unitID)
					local comTeam = Spring.GetUnitTeam(unitID)
					local r = math.random(0,3)
					if r == 0 then
						Spring.CreateUnit(choosenMinion,comPosX+32,comPosY,comPosZ,math.random(0,3),comTeam)
					elseif r == 1 then
						Spring.CreateUnit(choosenMinion,comPosX-32,comPosY,comPosZ,math.random(0,3),comTeam)
					elseif r == 2 then
						Spring.CreateUnit(choosenMinion,comPosX,comPosY,comPosZ+32,math.random(0,3),comTeam)
					else
						Spring.CreateUnit(choosenMinion,comPosX,comPosY,comPosZ-32,math.random(0,3),comTeam)
					end
				end
				for x = 1,#minions do
					if unitName == minions[x] then
						local minionEnemy = Spring.GetUnitNearestEnemy(unitID,999999,false)
						if minionEnemy then
							local eX,eY,eZ = Spring.GetUnitPosition(minionEnemy)
							Spring.GiveOrderToUnit(unitID, CMD.FIGHT,{eX+math.random(-100,100),eY,eZ+math.random(-100,100)}, { "alt", "ctrl"})
						end
					end
				end
			end
		end
		if minionTimer > minionCooldown + minionMax-1 then
			minionTimer = 0
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local unitName = UnitDefs[unitDefID].name
	for i = 1,#minions do
		if unitName == minions[i] then
			aliveMinions[unitID] = true
			Spring.SetUnitNoSelect(unitID, true)
			Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 2 }, 0)
			Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 2 }, 0)
			local minionEnemy = Spring.GetUnitNearestEnemy(unitID,999999,false)
			if minionEnemy then
			local eX,eY,eZ = Spring.GetUnitPosition(minionEnemy)
				Spring.GiveOrderToUnit(unitID, CMD.FIGHT,{eX+math.random(-100,100),eY,eZ+math.random(-100,100)}, { "alt", "ctrl"})
			end
			
			break
		end
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	local unitName = UnitDefs[unitDefID].name
	for i = 1,#minions do
		if unitName == minions[i] then
			aliveMinions[unitID] = nil
			
			
			break
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	local unitName = UnitDefs[unitDefID].name
	for i = 1,#minions do
		if unitName == minions[i] then
			aliveMinions[unitID] = nil
			
			
			break
		end
	end
end












end