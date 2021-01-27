local teams = Spring.GetTeamList()
for i = 1,#teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
		scavengersAIEnabled = true
		scavengerAITeamID = i - 1
		_,_,_,_,_,scavengerAllyTeamID = Spring.GetTeamInfo(scavengerAITeamID)
		break
	end
end

if (Spring.GetModOptions and (Spring.GetModOptions().lootboxes or "disabled") == "enabled") or (Spring.GetModOptions and (Spring.GetModOptions().scavonlylootboxes or "enabled") == "enabled" and scavengersAIEnabled == true) then
	lootboxSpawnEnabled = true
else
	lootboxSpawnEnabled = false
end

if scavengersAIEnabled then
	NameSuffix = "_scav"
else
	NameSuffix = ""
end

function gadget:GetInfo()
    return {
      name      = "supply drops",
      desc      = "123",
      author    = "Damgam",
      date      = "2020",
      layer     = -100,
      enabled   = true,
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end


local isLootbox = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if string.find(unitDef.name, "lootbox", nil, true) then
		isLootbox[unitDefID] = true
	end
end

local lootboxesListLow = {
    "lootboxbronze",
    "lootboxbronze",
	"lootboxbronze",
    "lootboxbronze",
	"lootboxnano_t1_var1",
	"lootboxnano_t1_var2",
	"lootboxnano_t1_var3",
	"lootboxnano_t1_var4",
}

local lootboxesListMid = {
    "lootboxbronze",
    "lootboxbronze",
	"lootboxbronze",
    "lootboxbronze",
    "lootboxsilver",
	"lootboxsilver",
	"lootboxsilver",
	"lootboxsilver",
	"lootboxnano_t1_var1",
	"lootboxnano_t1_var2",
	"lootboxnano_t1_var3",
	"lootboxnano_t1_var4",
	"lootboxnano_t2_var1",
	"lootboxnano_t2_var2",
	"lootboxnano_t2_var3",
	"lootboxnano_t2_var4",
}

local lootboxesListHigh = {
    "lootboxbronze",
    "lootboxbronze",
    "lootboxbronze",
	"lootboxbronze",
    "lootboxsilver",
    "lootboxsilver",
    "lootboxsilver",
    "lootboxsilver",
    "lootboxgold",
	"lootboxgold",
	"lootboxgold",
	"lootboxgold",
	"lootboxnano_t1_var1",
	"lootboxnano_t1_var2",
	"lootboxnano_t1_var3",
	"lootboxnano_t1_var4",
	"lootboxnano_t2_var1",
	"lootboxnano_t2_var2",
	"lootboxnano_t2_var3",
	"lootboxnano_t2_var4",
	"lootboxnano_t3_var1",
	"lootboxnano_t3_var2",
	"lootboxnano_t3_var3",
	"lootboxnano_t3_var4",
}

local lootboxesListTop = {
    "lootboxbronze",
	"lootboxbronze",
	"lootboxbronze",
	"lootboxbronze",
	"lootboxsilver",
    "lootboxsilver",
    "lootboxsilver",
    "lootboxsilver",
    "lootboxgold",
    "lootboxgold",
	"lootboxgold",
    "lootboxgold",
    "lootboxplatinum",
	"lootboxplatinum",
	"lootboxplatinum",
	"lootboxplatinum",
	"lootboxnano_t1_var1",
	"lootboxnano_t1_var2",
	"lootboxnano_t1_var3",
	"lootboxnano_t1_var4",
	"lootboxnano_t2_var1",
	"lootboxnano_t2_var2",
	"lootboxnano_t2_var3",
	"lootboxnano_t2_var4",
	"lootboxnano_t3_var1",
	"lootboxnano_t3_var2",
	"lootboxnano_t3_var3",
	"lootboxnano_t3_var4",
	"lootboxnano_t4_var1",
	"lootboxnano_t4_var2",
	"lootboxnano_t4_var3",
	"lootboxnano_t4_var4",
}


-- locals
local spGetUnitTeam         = Spring.GetUnitTeam
local spNearestEnemy        = Spring.GetUnitNearestEnemy
local spNearestAlly         = Spring.GetUnitNearestAlly
local spSeparation          = Spring.GetUnitSeparation
local spPosition            = Spring.GetUnitPosition
local spTransfer            = Spring.TransferUnit
local mapsizeX              = Game.mapSizeX
local mapsizeZ              = Game.mapSizeZ
local xBorder               = math.floor(mapsizeX/10)
local zBorder               = math.floor(mapsizeZ/10)
local math_random           = math.random
local spGroundHeight        = Spring.GetGroundHeight
local spGaiaTeam            = Spring.GetGaiaTeamID()
local spCreateUnit          = Spring.CreateUnit
local spGetCylinder			= Spring.GetUnitsInCylinder
local spGetUnitPosition 	= Spring.GetUnitPosition

local aliveLootboxes        = {}
local aliveLootboxesCount   = 0

local QueuedSpawns = {}
local QueuedSpawnsFrames = {}

local SpawnChance = 250
local TryToSpawn = false


-- functions

local function QueueSpawn(unitName, posx, posy, posz, facing, team, frame)
	local QueueSpawnCommand = {unitName, posx, posy, posz, facing, team}
	local QueueFrame = frame
	if #QueuedSpawnsFrames > 0 then
		for i = 1, #QueuedSpawnsFrames do
			local CurrentQueueFrame = QueuedSpawnsFrames[i]
			if (not(CurrentQueueFrame < QueueFrame)) or i == #QueuedSpawnsFrames then
				table.insert(QueuedSpawns, i, QueueSpawnCommand)
				table.insert(QueuedSpawnsFrames, i, QueueFrame)
				break
			end
		end
	else
		table.insert(QueuedSpawns, QueueSpawnCommand)
		table.insert(QueuedSpawnsFrames, QueueFrame)
	end
end

local function SpawnFromQueue(n)
	local QueuedSpawnsForNow = #QueuedSpawns
	if QueuedSpawnsForNow > 0 then
		for i = 1,QueuedSpawnsForNow do
			if n == QueuedSpawnsFrames[1] then
				local createSpawnCommand = QueuedSpawns[1]
				spCreateUnit(QueuedSpawns[1][1],QueuedSpawns[1][2],QueuedSpawns[1][3],QueuedSpawns[1][4],QueuedSpawns[1][5],QueuedSpawns[1][6])
				table.remove(QueuedSpawns, 1)
				table.remove(QueuedSpawnsFrames, 1)
			else
				break
			end
		end
	end
end

local function posFriendlyCheckOnlyLos(posx, posy, posz, allyTeamID)
	if scavengersAIEnabled == true then
		return Spring.IsPosInLos(posx, posy, posz, allyTeamID)
	else
		return true
	end
end


-- callins

function gadget:GameFrame(n)
    if n > 1 then
        SpawnFromQueue(n)
	end

    if n%30 == 0 and n > 2 then
		if math.random(0,SpawnChance) == 0 then
			TryToSpawn = true
		-- elseif #aliveLootboxes < math.ceil((n/30)/(SpawnChance*2)) then
			-- TryToSpawn = true
		end


        if aliveLootboxesCount > 0 then
            for unitID,_ in pairs(aliveLootboxes) do
                local unitTeam = spGetUnitTeam(unitID)
                local unitEnemy = spNearestEnemy(unitID, 128, false)
                if unitEnemy then
                    local enemyTeam = spGetUnitTeam(unitEnemy)
                    --if enemyTeam ~= spGaiaTeam then
                        local posx, posy, posz = spPosition(unitID)
                        Spring.MarkerErasePosition(posx, posy, posz)
                        spTransfer(unitID, enemyTeam, false)
						Spring.SetUnitNeutral(unitID, true)
                    --end
                end
            end
        end
        if TryToSpawn == true and lootboxSpawnEnabled then
            for k = 1,1000 do
                local posx = math.floor(math_random(xBorder,mapsizeX-xBorder)/16)*16
                local posz = math.floor(math_random(zBorder,mapsizeZ-zBorder)/16)*16
                local posy = spGroundHeight(posx, posz)
				local unitsCyl = spGetCylinder(posx, posz, 64)
				local scavLoS = posFriendlyCheckOnlyLos(posx, posy, posz, scavengerAllyTeamID)
                if #unitsCyl == 0 and scavLoS == true then
                    --QueueSpawn("lootdroppod_gold", posx, posy, posz, math_random(0,3),spGaiaTeam, n)
                    --QueueSpawn(lootboxesList[math_random(1,#lootboxesList)], posx, posy, posz, math_random(0,3),spGaiaTeam, n+600)
                    if aliveLootboxesCount < 2 then
						local spawnedUnit = spCreateUnit(lootboxesListLow[math_random(1,#lootboxesListLow)]..NameSuffix, posx, posy, posz, math_random(0,3), spGaiaTeam)
						Spring.SetUnitNeutral(spawnedUnit, true)
					elseif aliveLootboxesCount < 5 then
						local spawnedUnit = spCreateUnit(lootboxesListMid[math_random(1,#lootboxesListMid)]..NameSuffix, posx, posy, posz, math_random(0,3), spGaiaTeam)
						Spring.SetUnitNeutral(spawnedUnit, true)
					elseif aliveLootboxesCount < 8 then
						local spawnedUnit = spCreateUnit(lootboxesListHigh[math_random(1,#lootboxesListHigh)]..NameSuffix, posx, posy, posz, math_random(0,3), spGaiaTeam)
						Spring.SetUnitNeutral(spawnedUnit, true)
					else
						local spawnedUnit = spCreateUnit(lootboxesListTop[math_random(1,#lootboxesListTop)]..NameSuffix, posx, posy, posz, math_random(0,3), spGaiaTeam)
						Spring.SetUnitNeutral(spawnedUnit, true)
					end
					spCreateUnit("lootdroppod_gold"..NameSuffix, posx, posy, posz, math_random(0,3), spGaiaTeam)
					TryToSpawn = false
                    break
                end
            end
        end
    end
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    local UnitName = UnitDefs[unitDefID].name
	if isLootbox[unitDefID] then
		local uposx, uposy, uposz = spGetUnitPosition(unitID)
		aliveLootboxes[unitID] = true
		aliveLootboxesCount = aliveLootboxesCount + 1
	end
	if UnitName == "lootdroppod_gold" or UnitName == "lootdroppod_gold_scav" then
		Spring.SetUnitNeutral(unitID, true)
		Spring.GiveOrderToUnit(unitID, CMD.SELFD,{}, {"shift"})
	end
end


function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if aliveLootboxes[unitID] then
		aliveLootboxes[unitID] = nil
		aliveLootboxesCount = aliveLootboxesCount - 1
	end
end
