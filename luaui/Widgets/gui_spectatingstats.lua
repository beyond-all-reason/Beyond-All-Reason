local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Spectating Stats",
		desc      = "",
		author    = "Floris",
		date      = "April 2023",
		license   = "",
		layer     = 0,
		enabled   = false,
	}
end

local lastupdate = os.clock() - 10
local allyTeamList = Spring.GetAllyTeamList()
local numAllyTeams = #allyTeamList-1
local allyTeamName = {}
local textcolor = "\255\200\200\200"

local spGetUnitDefID = Spring.GetUnitDefID
local isSinglePlayer = Spring.Utilities.Gametype.IsSinglePlayer()

local ColorString = Spring.Utilities.Color.ToString

local unitdefMobileDps = {}
local unitdefStaticDps = {}
local unitdefBuildespeed = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local totalDps = 0
	local weapons = unitDef.weapons
	if not unitDef.customParams.iscommander then
		if #weapons > 0 then
			for i = 1, #weapons do
				local weaponDef = WeaponDefs[weapons[i].weaponDef]
				if weaponDef.damages then
					local maxDmg = 0
					for _, v in pairs(weaponDef.damages) do
						if v > maxDmg then
							maxDmg = v
						end
					end
					local dps = math.floor(maxDmg * weaponDef.salvoSize / weaponDef.reload)
					totalDps = totalDps + dps
				end
			end
			if totalDps > 0 then
				if unitDef.isBuilding then
					unitdefStaticDps[unitDefID] = totalDps
				else
					unitdefMobileDps[unitDefID] = totalDps
				end
			end
		end
	end
	if unitDef.buildSpeed > 0 then
		unitdefBuildespeed[unitDefID] = unitDef.buildSpeed
	end
end

function widget:Initialize()
	if not Spring.GetSpectatingState() and not isSinglePlayer then
		widgetHandler:RemoveWidget()
	end
end

local function GetAllyTeamStats(allyTeamID)
	local teamlist = Spring.GetTeamList(allyTeamID)
	local unitCount = 0
	local armyCount = 0
	local armyDps = 0
	local defenseCount = 0
	local defenseDps = 0
	local builders = 0
	local buildspeed = 0
	if not allyTeamName[allyTeamID] then
		local _, playerID, _, isAiTeam = Spring.GetTeamInfo(teamlist[1], false)
		allyTeamName[allyTeamID] = ColorString(Spring.GetTeamColor(teamlist[1]))..Spring.GetPlayerInfo(playerID, false)
	end
	for i, teamID in ipairs(teamlist) do
		local units = Spring.GetTeamUnits(teamID)
		unitCount = unitCount + #units
		for _, unitID in ipairs(units) do
			local unitDefID = spGetUnitDefID(unitID)
			if unitdefMobileDps[unitDefID] then
				armyCount = armyCount + 1
				armyDps = armyDps + unitdefMobileDps[unitDefID]
			elseif unitdefStaticDps[unitDefID] then
				defenseCount = defenseCount + 1
				defenseDps = defenseDps + unitdefStaticDps[unitDefID]
			end
			if unitdefBuildespeed[unitDefID] then
				builders = builders + 1
				buildspeed = buildspeed + unitdefBuildespeed[unitDefID]
			end
		end
	end
	return unitCount, armyCount, armyDps, defenseCount, defenseDps, builders, buildspeed
end

function widget:DrawScreen()
	if lastupdate + 1 < os.clock() then
		lastupdate = os.clock()
		for i, allyTeamID in ipairs(allyTeamList) do
			if i <= numAllyTeams then
				local unitCount, armyCount, armyDps, defenseCount, defenseDps, builders, buildspeed = GetAllyTeamStats(allyTeamID)
				local text = string.format(allyTeamName[allyTeamID]..textcolor..": %d units, %d army (%d DPS), defenses %d (%d DPS), builders %d (%d bp)", unitCount, armyCount, armyDps, defenseCount, defenseDps, builders, buildspeed)
				Spring.Echo(text)
			end
		end
	end
end

function widget:GetConfigData()
	return {
	}
end

function widget:SetConfigData(data)
end
