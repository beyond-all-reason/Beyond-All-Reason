--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name = "Minesweeper Detection",
		desc = "Shows mines around minesweepers",
		author = "Hornet, Cleaning: robert the pie",
		date = "May 25th, 2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local minesweeperRanges = {}
local minesweepers = {}

local mineIDs = {}
local revealedMines = {}

for udid, ud in pairs(UnitDefs) do
	if ud.customParams.minesweeper then
		minesweeperRanges[udid] = ud.customParams.minesweeper
	elseif ud.customParams.mine then
		mineIDs[udid] = true
	end
end
if table.count(minesweeperRanges) <= 0 or table.count(mineIDs) <= 0 then
	return false
end

local teamIDs = {}
for _, teamID in pairs(Spring.GetTeamList()) do
	local _, _, _, _, _, allyTeam = Spring.GetTeamInfo(teamID)
	teamIDs[teamID] = allyTeam
	revealedMines[teamID] = {}
	minesweepers[teamID] = {}
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if minesweeperRanges[unitDefID] then
		minesweepers[unitTeam][unitID] = unitDefID
	end
end

function gadget:UnitTaken(unitID, UnitDefID, oldTeam, newTeam)
	if minesweeperRanges[unitDefID] then
		minesweepers[oldTeam][unitID] = nil
		minesweepers[newTeam][unitID] = unitDefID
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if minesweeperRanges[unitDefID] and minesweepers[unitTeam][unitID] then
		minesweepers[unitTeam][unitID] = nil
	end
end

local function processesTeamsSweepers(currentTeam)
	local minesToReveal = {}

	for sweeper, sweeperDef in pairs(minesweepers[currentTeam])  do
		local x, y, z = Spring.GetUnitPosition(sweeper)
		if x and z then
			local nearUnits = Spring.GetUnitsInCylinder(x, z, minesweeperRanges[sweeperDef])
			for _, nearUnit in ipairs(nearUnits) do
				local nearUnitDefID = Spring.GetUnitDefID(nearUnit)
				if currentTeam ~= Spring.GetUnitTeam(nearUnit) then
					if mineIDs[nearUnitDefID] then
						minesToReveal[nearUnit] = true
					end
				end
			end
		end
	end

	for mineToReveal, _ in pairs(minesToReveal) do
		if revealedMines[currentTeam][mineToReveal] == nil then
			revealedMines[currentTeam][mineToReveal] = true
			--show in vision and radar, and prevent engine from immediately resseting that state
			Spring.Echo("revleaed", mineToReveal, "to", currentTeam)
			Spring.SetUnitLosState(mineToReveal, teamIDs[currentTeam], 3)
			Spring.SetUnitLosMask(mineToReveal, teamIDs[currentTeam], 3)
		end
	end
end

local function processRevealedMines(teamID)
	for revealedMine, _ in pairs(revealedMines[teamID]) do
		Spring.SetUnitLosMask(revealedMine, teamID, 0)
		revealedMines[teamID][revealedMine] = nil
	end
end

-- if we have more teams than frames per second we use a slightly slower method
local GAMESPEED = Game.gameSpeed
if #teamIDs + 1 >= GAMESPEED then
	function gadget:GameFrame(f)
		local loopedFrame = f % GAMESPEED
		for teamID in pairs(teamIDs) do
			if teamID % GAMESPEED == loopedFrame then
				processRevealedMines(teamID)
				processesTeamsSweepers(teamID)
			end
		end
	end
else
	function gadget:GameFrame(f)
		local currentTeam = f%GAMESPEED
		if currentTeam > #teamIDs then
			return
		end

		processRevealedMines(currentTeam)
		processesTeamsSweepers(currentTeam)
	end
end