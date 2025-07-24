local teams = Spring.GetTeamList()
mapsizeX = Game.mapSizeX
mapsizeZ = Game.mapSizeZ
local scavengerAITeamID = Spring.Utilities.GetScavTeamID()
local scavengerAllyTeamID = Spring.Utilities.GetScavAllyTeamID()

if Spring.Utilities.Gametype.IsScavengers() then
	scavengersAIEnabled = true
	ScavengerStartboxXMin, ScavengerStartboxZMin, ScavengerStartboxXMax, ScavengerStartboxZMax = Spring.GetAllyTeamStartBox(scavengerAllyTeamID)
	if ScavengerStartboxXMin == 0 and ScavengerStartboxZMin == 0 and ScavengerStartboxXMax == mapsizeX and ScavengerStartboxZMax == mapsizeZ then
		ScavengerStartboxExists = false
	else
		ScavengerStartboxExists = true
	end
end

if Spring.GetModOptions().lootboxes == "enabled" or (Spring.GetModOptions().lootboxes == "scav_only" and scavengersAIEnabled) then
	lootboxSpawnEnabled = true
	--Spring.Echo("LOOTBOXES ENABLED")
else
	lootboxSpawnEnabled = false
end


local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
      name      = "supply drops",
      desc      = "123",
      author    = "Damgam",
      date      = "2020",
	  license   = "GNU GPL, v2 or later",
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

local lootboxesListT1 = {}
local lootboxesListT2 = {}
local lootboxesListT3 = {}
local lootboxesListT4 = {}
if scavengersAIEnabled then
	lootboxesListT1[#lootboxesListT1+1] = "lootboxbronze_scav"
	lootboxesListT2[#lootboxesListT2+1] = "lootboxsilver_scav"
	lootboxesListT3[#lootboxesListT3+1] = "lootboxgold_scav"
	lootboxesListT4[#lootboxesListT4+1] = "lootboxplatinum_scav"
else
	lootboxesListT1[#lootboxesListT1+1] = "lootboxbronze"
	lootboxesListT2[#lootboxesListT2+1] = "lootboxsilver"
	lootboxesListT3[#lootboxesListT3+1] = "lootboxgold"
	lootboxesListT4[#lootboxesListT4+1] = "lootboxplatinum"
end


-- locals
local mapsizeX              = Game.mapSizeX
local mapsizeZ              = Game.mapSizeZ
local xBorder               = math.floor(mapsizeX/10)
local zBorder               = math.floor(mapsizeZ/10)
local math_random           = math.random
local spGroundHeight        = Spring.GetGroundHeight
local spGaiaTeam            = Spring.GetGaiaTeamID()
local spGaiaAllyTeam        = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID()))
local spCreateUnit          = Spring.CreateUnit

local aliveLootboxes        = {}
local aliveLootboxesCount   = 0

local aliveLootboxesT1        = {}
local aliveLootboxesCountT1   = 0
local aliveLootboxesT2        = {}
local aliveLootboxesCountT2   = 0
local aliveLootboxesT3        = {}
local aliveLootboxesCountT3   = 0
local aliveLootboxesT4        = {}
local aliveLootboxesCountT4   = 0
local aliveLootboxCaptureDifficulty = {}

local LootboxesToSpawn = 0

local lootboxesDensity = Spring.GetModOptions().lootboxes_density
local lootboxDensityMultiplier = 1
if lootboxesDensity == "veryrare" then
	lootboxDensityMultiplier = 0.2
elseif lootboxesDensity == "rare" then
	lootboxDensityMultiplier = 0.5
elseif lootboxesDensity == "normal" then
	lootboxDensityMultiplier = 1
end

local SpawnChance = math.ceil((150/lootboxDensityMultiplier)/(#teams-1))

if scavengersAIEnabled then
	spGaiaTeam = scavengerAITeamID
	spGaiaAllyTeam = scavengerAllyTeamID
end

-- VFS.Include('luarules/gadgets/scavengers/API/poschecks.lua')
local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")
local nearbyCaptureLibrary = VFS.Include("luarules/utilities/damgam_lib/nearby_capture.lua")

-- local function posFriendlyCheckOnlyLos(posx, posy, posz, allyTeamID)
-- 	if scavengersAIEnabled == true then
-- 		return Spring.IsPosInLos(posx, posy, posz, allyTeamID)
-- 	else
-- 		return true
-- 	end
-- end


-- callins

local function SpawnLootbox(posx, posy, posz)
	if math.random() < math.min(0.8, (aliveLootboxesCountT3*0.4)/(#teams-1)) then
		lootboxToSpawn = lootboxesListT4[math_random(1,#lootboxesListT4)]
	elseif math.random() < math.min(0.8, (aliveLootboxesCountT2*0.4)/(#teams-1)) then
		lootboxToSpawn = lootboxesListT3[math_random(1,#lootboxesListT3)]
	elseif math.random() < math.min(0.8, (aliveLootboxesCountT1*0.4)/(#teams-1)) then
		lootboxToSpawn = lootboxesListT2[math_random(1,#lootboxesListT2)]
	else
		lootboxToSpawn = lootboxesListT1[math_random(1,#lootboxesListT1)]
	end
	local spawnedUnit = spCreateUnit(lootboxToSpawn, posx, posy, posz, math_random(0,3), spGaiaTeam)
	if scavengersAIEnabled then
		spCreateUnit("lootdroppod_gold_scav", posx, posy, posz, math_random(0,3), spGaiaTeam)
	else
		spCreateUnit("lootdroppod_gold", posx, posy, posz, math_random(0,3), spGaiaTeam)
	end
	if spawnedUnit then
		Spring.SetUnitNeutral(spawnedUnit, true)
		Spring.SetUnitAlwaysVisible(spawnedUnit, true)
		Spring.SpawnCEG("commander-spawn-alwaysvisible", posx, posy, posz, 0, 0, 0)
		Spring.PlaySoundFile("commanderspawn-mono", 1.0, posx, posy, posz, 0, 0, 0, "sfx")
		GG.ComSpawnDefoliate(posx, posy, posz)
	end
end

function gadget:GameFrame(n)

    if n%30 == 0 and n > 2 then
		if SpawnChance < 1 or math.random(0,SpawnChance) == 0 then
			LootboxesToSpawn = LootboxesToSpawn+0.1
			if LootboxesToSpawn < 0 then
				LootboxesToSpawn = 0
			end
		end

        if aliveLootboxesCount > 0 then
			for i = 1,#aliveLootboxes do --for lootboxID,_ in pairs(aliveLootboxes) do
				local lootboxID = aliveLootboxes[i]
				if lootboxID then
					nearbyCaptureLibrary.NearbyCapture(lootboxID, aliveLootboxCaptureDifficulty[lootboxID], 1024)
				end
			end
        end
        if LootboxesToSpawn >= 1 and lootboxSpawnEnabled then
			--Spring.Echo("LOOTBOXES ENABLED, We're Spawning!")
            for k = 1,20 do
                local posx = math.floor(math_random(xBorder,mapsizeX-xBorder)/16)*16
                local posz = math.floor(math_random(zBorder,mapsizeZ-zBorder)/16)*16
                local posy = spGroundHeight(posx, posz)
				local canSpawnLootbox = positionCheckLibrary.FlatAreaCheck(posx, posy, posz, 128)
				if canSpawnLootbox then
					canSpawnLootbox = positionCheckLibrary.OccupancyCheck(posx, posy, posz, 128)
				end
				if canSpawnLootbox then
					canSpawnLootbox = positionCheckLibrary.VisibilityCheckEnemy(posx, posy, posz, 32, spGaiaAllyTeam, true, true, false)
				end
                if canSpawnLootbox then
					SpawnLootbox(posx, posy, posz)
                    break
                end
            end
        end
    end
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    local UnitName = UnitDefs[unitDefID].name
	if isLootbox[unitDefID] then
		Spring.SetUnitNeutral(unitID, true)
		Spring.SetUnitAlwaysVisible(unitID, true)
		LootboxesToSpawn = LootboxesToSpawn-1
		aliveLootboxes[#aliveLootboxes+1] = unitID
		aliveLootboxesCount = aliveLootboxesCount + 1

		for i = 1,#lootboxesListT1 do
			if lootboxesListT1[i] == UnitName then
				aliveLootboxesT1[#aliveLootboxesT1+1] = unitID
				aliveLootboxesCountT1 = aliveLootboxesCountT1 + 1
				aliveLootboxCaptureDifficulty[unitID] = 2
				--Spring.PlaySoundFile("lootboxdetectedt1", 1)
				--Spring.Echo("A Tech 1 Lootbox has been detected!")
				break
			end
		end
		for i = 1,#lootboxesListT2 do
			if lootboxesListT2[i] == UnitName then
				aliveLootboxesT2[#aliveLootboxesT2+1] = unitID
				aliveLootboxesCountT2 = aliveLootboxesCountT2 + 1
				aliveLootboxCaptureDifficulty[unitID] = 4
				--Spring.PlaySoundFile("lootboxdetectedt2", 1)
				--Spring.Echo("A Tech 2 Lootbox has been detected!")
				break
			end
		end
		for i = 1,#lootboxesListT3 do
			if lootboxesListT3[i] == UnitName then
				aliveLootboxesT3[#aliveLootboxesT3+1] = unitID
				aliveLootboxesCountT3 = aliveLootboxesCountT3 + 1
				aliveLootboxCaptureDifficulty[unitID] = 8
				--Spring.PlaySoundFile("lootboxdetectedt3", 1)
				--Spring.Echo("A Tech 3 Lootbox has been detected!")
				break
			end
		end
		for i = 1,#lootboxesListT4 do
			if lootboxesListT4[i] == UnitName then
				aliveLootboxesT4[#aliveLootboxesT4+1] = unitID
				aliveLootboxesCountT4 = aliveLootboxesCountT4 + 1
				aliveLootboxCaptureDifficulty[unitID] = 16
				--PlaySoundFile("lootboxdetectedt4", 1)
				--Spring.Echo("A Tech 4 Lootbox has been detected!")
				break
			end
		end
	end
	if UnitName == "lootdroppod_gold" or UnitName == "lootdroppod_gold_scav" then
		Spring.SetUnitNeutral(unitID, true)
		Spring.SetUnitAlwaysVisible(unitID, true)
		Spring.GiveOrderToUnit(unitID, CMD.SELFD,{}, {"shift"})
	end
end


function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	for i = 1,#aliveLootboxes do
		if unitID == aliveLootboxes[i] then
			LootboxesToSpawn = LootboxesToSpawn+0.5
			table.remove(aliveLootboxes, i)
			aliveLootboxesCount = aliveLootboxesCount - 1
			aliveLootboxCaptureDifficulty[unitID] = nil
			break
		end
	end
	for i = 1,#aliveLootboxesT1 do
		if unitID == aliveLootboxesT1[i] then
			table.remove(aliveLootboxesT1, i)
			aliveLootboxesCountT1 = aliveLootboxesCountT1 - 1
			break
		end
	end
	for i = 1,#aliveLootboxesT2 do
		if unitID == aliveLootboxesT2[i] then
			table.remove(aliveLootboxesT2, i)
			aliveLootboxesCountT2 = aliveLootboxesCountT2 - 1
			break
		end
	end
	for i = 1,#aliveLootboxesT3 do
		if unitID == aliveLootboxesT3[i] then
			table.remove(aliveLootboxesT3, i)
			aliveLootboxesCountT3 = aliveLootboxesCountT3 - 1
			break
		end
	end
	for i = 1,#aliveLootboxesT4 do
		if unitID == aliveLootboxesT4[i] then
			table.remove(aliveLootboxesT4, i)
			aliveLootboxesCountT4 = aliveLootboxesCountT4 - 1
			break
		end
	end
	if string.find(UnitDefs[unitDefID].name, "scavbeacon") then
		if math.random() <= 0.33 then
			local posx, posy, posz = Spring.GetUnitPosition(unitID)
			SpawnLootbox(posx, posy, posz)
		else
			LootboxesToSpawn = LootboxesToSpawn+0.33
		end
	end
end

function gadget:UnitGiven(unitID, unitDefID, unitNewTeam, unitOldTeam)
	for i = 1,#aliveLootboxes do
		if unitID == aliveLootboxes[i] then
			Spring.SetUnitNeutral(unitID, true)
			Spring.SetUnitAlwaysVisible(unitID, true)
		end
	end
end
