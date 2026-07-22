-- Lua-side sent/received sharing stats via team rules params (engine keeps only excess; sent/received are conserved, tracked Lua-side per RecoilEngine#3032)

local ResourceTypes = VFS.Include("gamedata/resource_types.lua")
local METAL = ResourceTypes.METAL

local ShareStats = {}

local function suffix(resourceType)
	return resourceType == METAL and "m" or "e"
end

-- per-team rules-param keys: cumulative sent/received + last tick's send (top bar overflow indicator)
local function cumSentKey(rt)
	return "sharestat_" .. suffix(rt) .. "_sent"
end
local function cumRecvKey(rt)
	return "sharestat_" .. suffix(rt) .. "_received"
end
local function recentSentKey(rt)
	return "sharestat_" .. suffix(rt) .. "_sent_recent"
end
local function recentRecvKey(rt)
	return "sharestat_" .. suffix(rt) .. "_received_recent"
end

ShareStats.cumSentKey = cumSentKey
ShareStats.cumRecvKey = cumRecvKey
ShareStats.recentSentKey = recentSentKey
ShareStats.recentRecvKey = recentRecvKey

-- allies (and spectators) can read; matches the visibility of the engine stats it replaces
local RULES_ACCESS = { allied = true }

---Record one cadence tick of solver results into the per-team rules params.
---@param springRepo EngineSynced
---@param results EconomyTeamResult[]
function ShareStats.Publish(springRepo, results)
	for i = 1, #results do
		local r = results[i]
		local rt = r.resourceType
		local sent = (springRepo.GetTeamRulesParam(r.teamId, cumSentKey(rt)) or 0) + (r.sent or 0)
		local received = (springRepo.GetTeamRulesParam(r.teamId, cumRecvKey(rt)) or 0) + (r.received or 0)
		springRepo.SetTeamRulesParam(r.teamId, cumSentKey(rt), sent, RULES_ACCESS)
		springRepo.SetTeamRulesParam(r.teamId, cumRecvKey(rt), received, RULES_ACCESS)
		springRepo.SetTeamRulesParam(r.teamId, recentSentKey(rt), r.sent or 0, RULES_ACCESS)
		springRepo.SetTeamRulesParam(r.teamId, recentRecvKey(rt), r.received or 0, RULES_ACCESS)
	end
end

---Read a team's sharing stats for one resource. Fields are nil when no Lua stats have
---been published (e.g. vanilla / native sharing), letting callers fall back to engine values.
---@param springApi table Spring (or a synced-repo) exposing GetTeamRulesParam
---@param teamID number
---@param resourceType ResourceName
---@return { sent: number?, received: number?, sentRecent: number?, receivedRecent: number? }
function ShareStats.Read(springApi, teamID, resourceType)
	return {
		sent = springApi.GetTeamRulesParam(teamID, cumSentKey(resourceType)),
		received = springApi.GetTeamRulesParam(teamID, cumRecvKey(resourceType)),
		sentRecent = springApi.GetTeamRulesParam(teamID, recentSentKey(resourceType)),
		receivedRecent = springApi.GetTeamRulesParam(teamID, recentRecvKey(resourceType)),
	}
end

return ShareStats
