local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Raptor Defense Nuke Controller",
		desc = "Gives targets to raptor nuke launchers",
		author = "Damgam",
		date = "2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local difficulty = "normal"

if Spring.Utilities.Gametype.IsRaptors() then
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Raptor Defense Spawner Activated!")
    difficulty = Spring.GetModOptions().raptor_difficulty
elseif Spring.Utilities.Gametype.IsScavengers() then
    Spring.Log(gadget:GetInfo().name, LOG.INFO, "Scav Defense Spawner Activated!")
    difficulty = Spring.GetModOptions().scav_difficulty
else
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Defense Spawner Deactivated!")
	return false
end

local pveTeamID = Spring.Utilities.GetScavTeamID() or Spring.Utilities.GetRaptorTeamID()

local nukeDefs = {}
for unitDefID, def in ipairs(UnitDefs) do
	if def.weapons then
		for i = 1, #def.weapons do
			local wDef = WeaponDefs[def.weapons[i].weaponDef]
			if wDef.targetable == 1 then
				nukeDefs[unitDefID] = true
				break
			end
		end
	end
end

local aliveNukeLaunchers = {}

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if nukeDefs[unitDefID] and (unitTeam == pveTeamID) then
        aliveNukeLaunchers[unitID] = Spring.GetGameSeconds() + math.random(5,10)
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
    if aliveNukeLaunchers[unitID] then
        aliveNukeLaunchers[unitID] = nil
    end
end

local difficulties = {
	veryeasy = 1500,
	easy 	 = 1000,
	normal   = 800,
	hard     = 700,
	veryhard = 600,
	epic     = 500,
}

local gridSize = difficulties[difficulty]
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local targetGridCells = {}
local numOfCellsX = math.ceil(mapSizeX/gridSize)
local numOfCellsZ = math.ceil(mapSizeZ/gridSize)
local GetGameSeconds = Spring.GetGameSeconds

for cellX = 1, numOfCellsX do
    for cellZ = 1, numOfCellsZ do
        if not targetGridCells[cellX] then targetGridCells[cellX] = {} end
        targetGridCells[cellX][cellZ] = {
            -- xmin = (cellX-1)*gridSize,
            -- zmin = (cellZ-1)*gridSize,
            -- xmax = cellX*gridSize,
            -- zmax = cellZ*gridSize,
            locked = 0,
        }
    end
end

function checkTargetCell(posx, posz, nukeID)
    local cellX = math.ceil(posx/gridSize)
    local cellZ = math.ceil(posz/gridSize)
    local cellData = targetGridCells[cellX][cellZ]
    if cellData.locked < GetGameSeconds() then
        cellData.locked = GetGameSeconds() + math.random(180,300)
        return true
    end
    return false
end

function gadget:GameFrame(frame)
    if frame%30 == 17 then
        local allUnits = Spring.GetAllUnits()
        for nukeID, cooldown in pairs(aliveNukeLaunchers) do
            if cooldown <= GetGameSeconds() then
                local targetID = allUnits[math.random(1,#allUnits)]
                if Spring.GetUnitTeam(targetID) ~= Spring.GetUnitTeam(nukeID) then
                    local x,y,z = Spring.GetUnitPosition(targetID)
                    x = x + math.random(-1024,1024)
                    z = z + math.random(-1024,1024)
                    y = math.max(Spring.GetGroundHeight(x,z), 0)
                    if x and z and x > 0 and x < mapSizeX and z > 0 and z < mapSizeZ and checkTargetCell(x,z,nukeID) then
                        Spring.GiveOrderToUnit(nukeID, CMD.ATTACK, {x, y, z}, 0)
                        aliveNukeLaunchers[nukeID] = GetGameSeconds() + math.random(10,90)
                    end
                end
            end
        end
    end
end
