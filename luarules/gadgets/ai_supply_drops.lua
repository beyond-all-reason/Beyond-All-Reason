if (Spring.GetModOptions and (tonumber(Spring.GetModOptions().lootboxes) or 0) ~= 0) then
    lootboxSpawnEnabled = true
else
    lootboxSpawnEnabled = false
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

if (not gadgetHandler:IsSyncedCode()) then
	return false
end

local lootboxesListLow = {
    "lootboxbronze",
    "lootboxbronze",
}

local lootboxesListMid = {
    "lootboxbronze",
    "lootboxbronze",
    "lootboxsilver",
}

local lootboxesListHigh = {
    "lootboxbronze",
    "lootboxbronze",
    "lootboxbronze",
    "lootboxsilver",
    "lootboxsilver",
    "lootboxsilver",
    "lootboxgold",
}

local lootboxesListTop = {
    "lootboxsilver",
    "lootboxsilver",
    "lootboxsilver",
    "lootboxsilver",
    "lootboxsilver",
    "lootboxgold",
    "lootboxgold",
	"lootboxgold",
    "lootboxgold",
    "lootboxplatinum",
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
local xBorder               = math.floor(mapsizeX/5)
local zBorder               = math.floor(mapsizeZ/5)
local math_random           = math.random
local spGroundHeight        = Spring.GetGroundHeight
local spGaiaTeam            = Spring.GetGaiaTeamID()
local spCreateUnit          = Spring.CreateUnit
local spGetCylinder			= Spring.GetUnitsInCylinder

local aliveLootboxes        = {}
local aliveLootboxesCount   = 0

local QueuedSpawns = {}
local QueuedSpawnsFrames = {}






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






-- callins

function gadget:GameFrame(n)
    if n > 1 then
        SpawnFromQueue(n)
	end
    
    if n%30 == 0 and n > 2 then
        
        if #aliveLootboxes > 0 then
            for j = 1,#aliveLootboxes do 
                local unitID            = aliveLootboxes[j]
                local unitTeam          = spGetUnitTeam(unitID)
                local unitEnemy         = spNearestEnemy(unitID, 128, false)
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
        if math_random(0,300) == 0 and lootboxSpawnEnabled then
            for k = 1,1000 do
                local posx = math.floor(math_random(xBorder,mapsizeX-xBorder)/16)*16
                local posz = math.floor(math_random(zBorder,mapsizeZ-zBorder)/16)*16
                local posy = spGroundHeight(posx, posz)
				local unitsCyl = spGetCylinder(posx, posz, 128)
                if #unitsCyl == 0 then
                    --QueueSpawn("lootdroppod_gold", posx, posy, posz, math_random(0,3),spGaiaTeam, n)
                    --QueueSpawn(lootboxesList[math_random(1,#lootboxesList)], posx, posy, posz, math_random(0,3),spGaiaTeam, n+600)
                    if aliveLootboxesCount < 2 then
						spCreateUnit(lootboxesListLow[math_random(1,#lootboxesListLow)], posx, posy, posz, math_random(0,3), spGaiaTeam)
						--Spring.MarkerAddPoint(posx, posy, posz, "Resource Generator Detected", true)
					elseif aliveLootboxesCount < 4 then
						spCreateUnit(lootboxesListMid[math_random(1,#lootboxesListMid)], posx, posy, posz, math_random(0,3), spGaiaTeam)
						--Spring.MarkerAddPoint(posx, posy, posz, "Resource Generator Detected", true)
					elseif aliveLootboxesCount < 6 then
						spCreateUnit(lootboxesListHigh[math_random(1,#lootboxesListHigh)], posx, posy, posz, math_random(0,3), spGaiaTeam)
						--Spring.MarkerAddPoint(posx, posy, posz, "Resource Generator Detected", true)
					else
						spCreateUnit(lootboxesListTop[math_random(1,#lootboxesListTop)], posx, posy, posz, math_random(0,3), spGaiaTeam)
						--Spring.MarkerAddPoint(posx, posy, posz, "Resource Generator Detected", true)
					end
                    
                    break
                end
            end
        end
    end
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    local unitName = UnitDefs[unitDefID].name
    if string.find(unitName, "lootbox") then
        table.insert(aliveLootboxes,unitID)
		aliveLootboxesCount = aliveLootboxesCount + 1
        Spring.SetUnitNeutral(unitID, true)
    end
end


function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
    local unitName = UnitDefs[unitDefID].name
    if string.find(unitName, "lootbox") then
        for i = 1,#aliveLootboxes do
            if unitID == aliveLootboxes[i] then
				aliveLootboxesCount = aliveLootboxesCount - 1
                table.remove(aliveLootboxes,i)
                break
            end
        end
    end
end