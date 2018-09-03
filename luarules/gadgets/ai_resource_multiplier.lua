function gadget:GetInfo()
	return {
		name = "AI Resource Multiplier",
		desc = "Hmm",
		author = "Damgam, used parts of code from resource gifts gadget by lurker (Dylan Petonke) and Google Frog",
		date = "18 May 2018",
		license = "GPL",
		layer = 1,
		enabled = true
	}
end

local aiResourceMultiplier = tonumber(Spring.GetModOptions().ai_incomemultiplier) or 1

local UDC = Spring.GetTeamUnitDefCount
local UDN = UnitDefNames

if (not gadgetHandler:IsSyncedCode()) then
	return -- No Unsynced
end

-- Initialise ally teams
local allyTeamInfo = {} -- list of players and mexes on a team

local allyTeamList = Spring.GetAllyTeamList()
local allyTeams = #allyTeamList

do
	for i=1,allyTeams do
		local allyTeamID = allyTeamList[i]
		local teamList = Spring.GetTeamList(allyTeamID)
		allyTeamInfo[allyTeamID] = {
			teams = 0,
			team = {},
			mexes = 0,
			mex = {},
			mexIndex = {},
		}
		for j=1,#teamList do
			local teamID = teamList[j]
			allyTeamInfo[allyTeamID].teams = allyTeamInfo[allyTeamID].teams + 1
			allyTeamInfo[allyTeamID].team[allyTeamInfo[allyTeamID].teams] = teamID
		end
	end
end

function gadget:Initialize(n)
	
end
	
function gadget:GameFrame(n)
	-- check if team is controled by AI
	if n%60 == 4 then
		for _,TeamID in ipairs(Spring.GetTeamList()) do
			local isAiTeam = select(4, Spring.GetTeamInfo(TeamID))
			if isAiTeam then
				
				-- get resource income
				local mc, ms, mp, mi, me = Spring.GetTeamResources(TeamID, "metal")
				local ec, es, ep, ei, ee = Spring.GetTeamResources(TeamID, "energy")	
				-- give resources
				if aiResourceMultiplier > 1 then
					Spring.AddTeamResource(TeamID,"m", (aiResourceMultiplier - 1) * mi * 2 )
					Spring.AddTeamResource(TeamID,"e", (aiResourceMultiplier - 1) * ei * 2 )
				end
				-- if n > 1 then
					-- local seconds = n / 30
					-- local resourcecheat = seconds * 0.00020
					-- local metalcheat = resourcecheat * mi * 2
					-- local energycheat = resourcecheat * ei * 2
					-- Spring.AddTeamResource(TeamID,"m", metalcheat * aiResourceMultiplier)
					-- Spring.AddTeamResource(TeamID,"e", energycheat * aiResourceMultiplier)
				-- end
			end
		end
	end
end
