local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = 'Team Resource Bonus Tax',
		desc = 'Prevent applying bonus upon bonus when sharing to players with bonus',
		author = 'Floris',
		date = 'April 2025',
		license = 'GNU GPL, v2 or later',
		layer = 999999,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local bonusTeams = {}
local teamDebt = {}

function gadget:Initialize()
	local teamList = Spring.GetTeamList()
	local bonusTeamCount = 0
	for i = 1, #teamList do
		local _, _, _, _, _, _, incomeMultiplier = Spring.GetTeamInfo(teamList[i], false)
		if incomeMultiplier > 1.01 then -- lets just not bother for 1% bonus
			bonusTeams[teamList[i]] = incomeMultiplier-1
			bonusTeamCount = bonusTeamCount + 1
		end
	end
	if bonusTeamCount == 0 then
		gadgetHandler:RemoveGadget()
		return
	end
end

function gadget:TeamDied(teamID)
	bonusTeams[teamID] = nil
	teamDebt[teamID] = nil
end

local function collectDebt(teamID, resourceType)
	local currentRes = Spring.GetTeamResources(teamID, resourceType == 'e' and 'energy' or 'metal')
	if currentRes > 0 then
		local newRes = currentRes - teamDebt[teamID][resourceType]
		if newRes <= -1 then
			teamDebt[teamID][resourceType] = math.abs(newRes)
			newRes = 0
		else
			teamDebt[teamID][resourceType] = nil
			if not teamDebt[teamID][resourceType == 'e' and 'm' or 'e'] then
				teamDebt[teamID] = nil
			end
		end
		Spring.SetTeamResource(teamID, resourceType, newRes)
	end
end

-- strip the bonus received from resource transfers
function gadget:AllowResourceTransfer(senderTeamID, receiverTeamID, resourceType, amount)
	if bonusTeams[receiverTeamID] then
		if not teamDebt[receiverTeamID] then
			teamDebt[receiverTeamID] = {}
		end
		teamDebt[receiverTeamID][resourceType] = math.ceil(amount * bonusTeams[receiverTeamID])
		collectDebt(receiverTeamID, resourceType)
	end
	return true
end

-- keep trying to collect any outstanding debt
function gadget:GameFrame(gf)
	for teamID, debt in pairs(teamDebt) do
		if debt.e then
			collectDebt(teamID, 'e', debt.e)
		end
		if debt.m then
			collectDebt(teamID, 'm', debt.m)
		end
	end
end
