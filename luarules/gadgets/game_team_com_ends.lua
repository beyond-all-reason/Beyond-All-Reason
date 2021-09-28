function gadget:GetInfo()
	return {
		name = "Team Com Ends + dead allyteam blowup",
		desc = "Implements com ends for allyteams + blows up team if no players left",
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

-- this acts just like Com Ends except instead of killing a player's units when
-- his com dies it acts on an allyteam level, if all coms in an allyteam are dead
-- the allyteam is out

local commanderDeathQueue = {}
local aliveComCount = {}
local gaiaTeamID = Spring.GetGaiaTeamID()

local GetTeamList = Spring.GetTeamList
local GetUnitAllyTeam = Spring.GetUnitAllyTeam

local isCommander = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander then
		isCommander[unitDefID] = true
	end
end

local teamCount = 0
for _,teamID in ipairs(GetTeamList()) do
	if teamID ~= gaiaTeamID then
		teamCount = teamCount + 1
	end
end

local function commanderDeath(teamID, unitID)
	local allyTeam = select(6, Spring.GetTeamInfo(teamID))
	aliveComCount[allyTeam] = aliveComCount[allyTeam] - 1
	if aliveComCount[allyTeam] <= 0 then
		local x,z
		if unitID then
			x,_,z = Spring.GetUnitPosition(unitID)
		end

		GG.wipeoutTeam(teamID, x, z, unitID)
		Spring.KillTeam(teamID)

		-- xmas gadget uses this
		if not _G.destroyingTeam then _G.destroyingTeam = {} end
		_G.destroyingTeam[allyTeam] = true
	end
end

function gadget:GameFrame(gf)

	-- execute 1 frame delayed destroyedunit (because a unit can be taken before its given which could make the game end)
	-- untested if this actually is the case
	for unitID, teamID in pairs(commanderDeathQueue) do
		commanderDeath(teamID, unitID)
	end
	commanderDeathQueue = {}
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if isCommander[unitDefID] and unitTeam ~= gaiaTeamID then
		local allyTeam = GetUnitAllyTeam(unitID)
		aliveComCount[allyTeam] = aliveComCount[allyTeam] + 1
	end
end

function gadget:UnitGiven(unitID, unitDefID, unitTeam)
	if isCommander[unitDefID] and unitTeam ~= gaiaTeamID then
		local allyTeam = GetUnitAllyTeam(unitID)
		aliveComCount[allyTeam] = aliveComCount[allyTeam] + 1
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if isCommander[unitDefID] and unitTeam ~= gaiaTeamID then
		commanderDeathQueue[unitID] = unitTeam
		--commanderDeath(unitTeam, unitID)
	end
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if isCommander[unitDefID] and unitTeam ~= gaiaTeamID then
		commanderDeathQueue[unitID] = unitTeam
		--commanderDeath(unitTeam, unitID)
	end
end

function gadget:Initialize()
	if Spring.GetModOptions().deathmode ~= 'com' then
		gadgetHandler:RemoveGadget(self) -- in particular, this gadget is removed if deathmode is "killall" or "none"
	end

	for _,allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		aliveComCount[allyTeamID] = 0
	end

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
