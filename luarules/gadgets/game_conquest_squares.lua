function gadget:GetInfo()
	return {
		name = "Unit In Square Tracker",
		desc = "Cuts the map into squares and tracks which squares units are in",
		author = "SethDGamre",
		date = "2025.02.08",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true,

	}
end

if  not gadgetHandler:IsSyncedCode() then return false end

--configs
local debugmode = false
local MAX_PROGRESS = 100 --how much progress a square can have
local PROGRESS_INCREMENT = 3 --how much progress a square gains per frame

--localized functions
local sqrt = math.sqrt
local floor = math.floor
local max = math.max
local min = math.min
local spGetGroundHeight = Spring.GetGroundHeight
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ


-- constants
local SQUARE_BOUNDARY = 128 -- how many elmos closer to the center of the scum than the actual edge of the scum the unit must be to be considered on the scum
local GRID_SIZE = 1024 -- the size of the squares in elmos
local FINISHED_BUILDING = 1
local NO_OWNER = -1
local FRAME_MODULO = Game.gameSpeed * 3


--variables
local initialized = false
local scavengerTeamID = 999
local raptorsTeamID = 999
local gaiaTeamID = Spring.GetGaiaTeamID()
local teams = Spring.GetTeamList()
local allyTeamsWatch = {}

--tables
local exemptTeams = {}
local unitWatchDefs = {}
local captureGrid = {}

exemptTeams[gaiaTeamID] = true

--start-up
for _, teamID in ipairs(teams) do --first figure out which teams are exempt
	Spring.Echo("A Team: ", teamID)
	local luaAI = Spring.GetTeamLuaAI(teamID)
	if luaAI and luaAI ~= "" then
		if string.sub(luaAI, 1, 12) == 'ScavengersAI' then
			scavengerTeamID = teamID
			exemptTeams[teamID] = true
		elseif  string.sub(luaAI, 1, 12) == 'RaptorsAI' then
			raptorsTeamID = teamID
			exemptTeams[teamID] = true
		end
	end
end
for _, teamID in ipairs(teams) do --then figure out what all teams should be watched
	if not exemptTeams[teamID] then
		Spring.Echo("not exempt Team: " , teamID)
		local allyTeam = select(6, Spring.GetTeamInfo(teamID))
		Spring.Echo("not exemptAlly team: ", allyTeam, " team: ", teamID)
		allyTeamsWatch[allyTeam] = allyTeamsWatch[allyTeam] or {}
		allyTeamsWatch[allyTeam][teamID] = true
	end
end

for defID, def in pairs(UnitDefs) do
	local defData

	if def.power then
		defData = {power = def.power}
		if def.speed == 0 then
			defData.isStatic = true
		end
	end
	unitWatchDefs[defID] = defData
end

--custom functions

local function generateCaptureGrid()
	local points = {}
	local numSquaresX = math.ceil(mapSizeX / GRID_SIZE)
	local numSquaresZ = math.ceil(mapSizeZ / GRID_SIZE)
	
	for x = 0, numSquaresX - 1 do
		for z = 0, numSquaresZ - 1 do
			local originX = x * GRID_SIZE
			local originZ = z * GRID_SIZE
			points[#points + 1] = {x = originX, z = originZ, allyOwner = NO_OWNER, progress = 50}
		end
	end
	return points

end


function gadget:UnitCreated(unitID, unitDefID, unitTeam)
end


function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
end

function gadget:GameFrame(frame)
	if frame % 60 == 0 then
		--Spring.Echo("Map Size X: " .. mapSizeX)
		--Spring.Echo("Map Size Z: " .. mapSizeZ)
		

		for i, origin in ipairs(captureGrid) do
			local units = spGetUnitsInRectangle(origin.x, origin.z, origin.x + GRID_SIZE, origin.z + GRID_SIZE)
			local allyPowers = {} 
			local allyProgressBlockers = {}-- Track power per ally team

			for _, unitID in ipairs(units) do
				local isFinishedBuilding = select(5, spGetUnitHealth(unitID)) == FINISHED_BUILDING
				if isFinishedBuilding then
					local unitDefID = spGetUnitDefID(unitID)
					local unitData = unitWatchDefs[unitDefID]
					local allyTeam = spGetUnitAllyTeam(unitID)
					
					if unitData and unitData.power and allyTeamsWatch[allyTeam] then
						-- Accumulate power for the unit's ally team
						allyPowers[allyTeam] = (allyPowers[allyTeam] or 0) + unitData.power
						if unitWatchDefs[unitDefID].isStatic then
							allyProgressBlockers[allyTeam] = true
							Spring.Echo("allyProgressBlockers: ", allyTeam, UnitDefs[unitDefID].name)
						end
					end
				end
			end

			-- Find which ally team has the highest power in this square
			local winningAllyTeam
			local secondPlaceAllyTeam
			local sortedTeams = {}
			for team, power in pairs(allyPowers) do
				table.insert(sortedTeams, {team = team, power = power})
			end
			table.sort(sortedTeams, function(a,b) return a.power > b.power end)
			winningAllyTeam = sortedTeams[1] and sortedTeams[1].team
			secondPlaceAllyTeam = sortedTeams[2] and sortedTeams[2].team

			local powerRatio = 1
			if winningAllyTeam and secondPlaceAllyTeam then

				powerRatio = math.abs(allyPowers[secondPlaceAllyTeam] / allyPowers[winningAllyTeam] - 1) --need a value between 0 and 1
				Spring.Echo("custom Calc powerRatio: ", powerRatio)
			end
			local currentOwner = captureGrid[i].allyOwner
			
			local blockProgress --the winningAllyTeam is blocked from making progress by enemy static units
			if next(allyProgressBlockers) then
				for allyBlockerID, _ in pairs(allyProgressBlockers) do
					if allyBlockerID ~= winningAllyTeam then
						blockProgress = true
						break
					end
				end
			end

			if winningAllyTeam and not blockProgress then
				if currentOwner == winningAllyTeam then

					-- Increment progress for current owner
					captureGrid[i].progress = math.min(captureGrid[i].progress + PROGRESS_INCREMENT * powerRatio, MAX_PROGRESS)
				else
					captureGrid[i].progress = captureGrid[i].progress - (powerRatio * PROGRESS_INCREMENT)

					-- Check if we need to flip ownership
					if captureGrid[i].progress < 0 then
						captureGrid[i].allyOwner = winningAllyTeam
						captureGrid[i].progress = math.abs(captureGrid[i].progress)
					end
				end
			
				Spring.Echo(string.format("AllyTeam %d dominates square %d,%d with %d progress", 
				captureGrid[i].allyOwner,
				origin.x, origin.z, captureGrid[i].progress))
			end

			Spring.SpawnCEG("scaspawn-trail", origin.x, Spring.GetGroundHeight(origin.x, origin.z), origin.z, 0,0,0)
			Spring.SpawnCEG("scav-spawnexplo", origin.x, Spring.GetGroundHeight(origin.x, origin.z), origin.z, 0,0,0)
		end
	end
end

function gadget:Initialize()
	captureGrid = generateCaptureGrid()
end

