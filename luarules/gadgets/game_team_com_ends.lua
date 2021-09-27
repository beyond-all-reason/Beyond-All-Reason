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

local destroyQueue = {}
local aliveComCount = {}

local GetTeamList = Spring.GetTeamList
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetTeamInfo = Spring.GetTeamInfo

local gaiaTeamID = Spring.GetGaiaTeamID()
local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID))
local allyTeamList = Spring.GetAllyTeamList()

local deadAllyTeams = {
	[gaiaAllyTeamID] = true
}

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

local blowUpWhenEmptyAllyTeam = false -- disabled for now because other gadget already seems to handle this
--local blowUpWhenEmptyAllyTeam = true
--if Spring.GetModOptions().ffa_mode then
--	blowUpWhenEmptyAllyTeam = false
--end
--if teamCount == 2 then
--	blowUpWhenEmptyAllyTeam = false -- let player quit & rejoin in 1v1
--end


function gadget:Initialize()
	if Spring.GetModOptions().deathmode ~= 'com' then
		if not blowUpWhenEmptyAllyTeam then
			gadgetHandler:RemoveGadget(self) -- in particular, this gadget is removed if deathmode is "killall" or "none"
		end
	end
	for _,t in ipairs(Spring.GetAllyTeamList()) do
		aliveComCount[t] = 0
	end
end


-- blow up an allyteam when it has no players left
--if blowUpWhenEmptyAllyTeam then

	function gadget:GameFrame(gf)

		if gf % 15 == 0 then
			for _,allyTeamID in ipairs(allyTeamList) do
				if not deadAllyTeams[allyTeamID] then
					local deadAllyTeam = true
					local teamsList = GetTeamList(allyTeamID)
					for _,teamID in ipairs(teamsList) do
						if select(4,GetTeamInfo(teamID,false)) or teamID == gaiaTeamID then
							deadAllyTeam = false
						else
							local playersList = Spring.GetPlayerList(teamID,true)
							for _,playerID in ipairs(playersList) do
								local name,_,isSpec = Spring.GetPlayerInfo(playerID,false)
								if name ~= nil and not isSpec then
									deadAllyTeam = false
								end
							end
						end
					end
					if deadAllyTeam then
						destroyQueue[allyTeamID] = {x=0, y=0, z=0}
						aliveComCount[allyTeamID] = 0
						deadAllyTeams[allyTeamID] = true
						for _,teamID in ipairs(teamsList) do
							GG.wipeoutTeam(teamID)
							Spring.KillTeam(teamID)
						end
						break
					end
				end
			end
		end
	end
--end

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

local function commanderDeath(teamID, unitID)
	local allyTeam = GetUnitAllyTeam(unitID)
	aliveComCount[allyTeam] = aliveComCount[allyTeam] - 1
	if aliveComCount[allyTeam] <= 0 then
		local x,y,z = Spring.GetUnitPosition(unitID)

		GG.wipeoutTeam(teamID, x, z, unitID)
		Spring.KillTeam(teamID)

		-- xmas gadget uses this
		if not _G.destroyingTeam then _G.destroyingTeam = {} end
		_G.destroyingTeam[GetUnitAllyTeam(unitID)] = true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if isCommander[unitDefID] and unitTeam ~= gaiaTeamID then
		commanderDeath(unitTeam, unitID)
	end
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if isCommander[unitDefID] and unitTeam ~= gaiaTeamID then
		commanderDeath(unitTeam, unitID)
	end
end
