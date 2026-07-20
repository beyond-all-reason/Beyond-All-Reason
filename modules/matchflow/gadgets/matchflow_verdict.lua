local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "MatchFlow Verdict",
		desc = "Scripted-verdict path of the matchflow module: applies pending Victory/Defeat verdicts (demo-minimal; the game_end extraction comes later)",
		author = "Beyond All Reason",
		date = "July 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

-- DEMO-ONLY coexistence: game_end.lua still runs its own end conditions, the
-- same way missions coexist with it today (the scenariooptions path). This
-- gadget only ever ends the game when a mission scripted a verdict.

---@type integer[]|nil winning ally team ids; applied on the next GameFrame
local pendingWinners = nil

---@param allyTeamID integer
local function Victory(allyTeamID)
	pendingWinners = { allyTeamID }
end

---@param losers integer[]
local function Defeat(losers)
	local losing = {}
	for _, allyTeamID in ipairs(losers) do
		losing[allyTeamID] = true
	end
	local gaiaAllyTeam = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID(), false))
	local winners = {}
	for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		if not losing[allyTeamID] and allyTeamID ~= gaiaAllyTeam then
			winners[#winners + 1] = allyTeamID
		end
	end
	pendingWinners = winners
end

function gadget:Initialize()
	GG.MatchFlow = {
		Victory = Victory,
		Defeat = Defeat,
	}
end

function gadget:Shutdown()
	GG.MatchFlow = nil
end

function gadget:GameFrame()
	if pendingWinners ~= nil then
		local winners = pendingWinners
		pendingWinners = nil
		Spring.GameOver(winners)
	end
end
