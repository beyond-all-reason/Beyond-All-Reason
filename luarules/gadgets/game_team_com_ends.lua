local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Team Com Ends",
		desc = "Implements com ends for allyteams",
		author = "KDR_11k (David Becker), Floris",
		date = "2008-02-04",
		license = "Public domain",
		layer = 1,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local GetTeamList = Spring.GetTeamList
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local gaiaTeamID = Spring.GetGaiaTeamID()

-- Exclude Gaia / Scavengers / Raptors
local ignoredTeams = {
	[gaiaTeamID] = true,
}
local teamCount = 0
local teamList = Spring.GetTeamList()
for i = 1, #teamList do
	local luaAI = Spring.GetTeamLuaAI(teamList[i])
	if luaAI and (luaAI:find("Raptors") or luaAI:find("Scavengers")) then
		ignoredTeams[teamList[i]] = true

		-- ignore all other teams in this allyteam as well
		--Spring.Echo(select(6, Spring.GetTeamInfo(teamList[i])))  -- somehow this echos "1, 1, <table>"
		local teamID, leader, isDead, isAiTeam, side, allyTeam, incomeMultiplier, customTeamKeys = Spring.GetTeamInfo(teamList[i])
		local teammates = Spring.GetTeamList(allyTeam)
		for j = 1, #teammates do
			ignoredTeams[teammates[j]] = true
		end
	end
	if teamList[i] ~= gaiaTeamID then
		teamCount = teamCount + 1
	end
end
teamList = nil

local aliveComCount = {}
local aliveTeamComCount = {}
local commanderDeathQueue = {}

local isCommander = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander or unitDef.customParams.isscavcommander or (Spring.GetModOptions().deathmode == "builders" and ((unitDef.buildOptions and #unitDef.buildOptions > 0) or unitDef.canResurrect == true)) then
		isCommander[unitDefID] = true
	end
end

local function commanderDeath(teamID, originX, originZ) -- optional: attackerUnitID, originX, originZ
	local allyTeamID = select(6, Spring.GetTeamInfo(teamID, false))
	aliveComCount[allyTeamID] = aliveComCount[allyTeamID] - 1
	aliveTeamComCount[teamID] = aliveTeamComCount[teamID] - 1
	if aliveComCount[allyTeamID] <= 0 then
		for _, teamID in ipairs(Spring.GetTeamList(allyTeamID)) do
			if not select(3, Spring.GetTeamInfo(teamID, false)) then
				Spring.KillTeam(teamID)
			end
		end
	end

	if Spring.GetModOptions().deathmode == "own_com" and aliveTeamComCount[teamID] <= 0 then
		if not select(3, Spring.GetTeamInfo(teamID, false)) then
			Spring.KillTeam(teamID)
		end
	end
end

function gadget:GameFrame(gf)
	-- execute 1 frame delayed destroyedunit (because a unit can be taken before its given which could make the game end)
	-- untested if this actually is the case
	for unitID, params in pairs(commanderDeathQueue) do
		commanderDeath(params[1], params[2], params[3])
		commanderDeathQueue[unitID] = nil
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if isCommander[unitDefID] and unitTeam ~= gaiaTeamID then
		local allyTeam = GetUnitAllyTeam(unitID)
		aliveComCount[allyTeam] = aliveComCount[allyTeam] + 1
		aliveTeamComCount[unitTeam] = aliveTeamComCount[unitTeam] + 1
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if isCommander[unitDefID] and not ignoredTeams[unitTeam] then
		local x,_,z = Spring.GetUnitPosition(unitID)
		commanderDeathQueue[unitID] = {unitTeam, x, z}
	end
end

local function transferCommander(unitID, unitTeam, newTeam)
	local allyTeamID = select(6, Spring.GetTeamInfo(unitTeam, false))
	local newAllyTeamID = select(6, Spring.GetTeamInfo(newTeam, false))
	if allyTeamID ~= newAllyTeamID then
		-- add to newTeam
		aliveComCount[newAllyTeamID] = aliveComCount[newAllyTeamID] + 1
		aliveTeamComCount[newTeam] = aliveTeamComCount[newTeam] + 1
		-- remove from unitTeam
		local x,_,z = Spring.GetUnitPosition(unitID)
		commanderDeathQueue[unitID] = {unitTeam, x, z}
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, unitTeam)
	if isCommander[unitDefID] and not ignoredTeams[unitTeam] then
		transferCommander(unitID, unitTeam, newTeam)
	end
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if isCommander[unitDefID] and not ignoredTeams[unitTeam] then
		transferCommander(unitID, unitTeam, newTeam)
	end
end

function gadget:Initialize()
	-- disable gadget when deathmode is "killall" or "none", or scoremode isnt regular
	if Spring.GetModOptions().deathmode ~= 'com' and Spring.GetModOptions().deathmode ~= 'own_com' and Spring.GetModOptions().deathmode ~= 'builders' then
		gadgetHandler:RemoveGadget(self)
	end

	for _,allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		aliveComCount[allyTeamID] = 0
	end
	for _,teamID in ipairs(Spring.GetTeamList()) do
		aliveTeamComCount[teamID] = 0
	end

	-- in case a luarules reload happens
	local units = Spring.GetAllUnits()
	for i = 1, #units do
		local unitID = units[i]
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end

	-- for debug purpose: destroy comless allyteams (usefull when team has no coms because of error and you do luarules reload)
	if Spring.GetGameFrame() > 1 then
		for allyTeamID, count in ipairs(aliveComCount) do
			if count <= 0 then
				for _,teamID in ipairs(GetTeamList(allyTeamID)) do
					commanderDeath(teamID)
				end
			end
		end
	end
end
