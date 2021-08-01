local scavengersAIEnabled = Spring.Utilities.Gametype.IsScavengers()

if not scavengersAIEnabled and not (Spring.GetModOptions and (tonumber(Spring.GetModOptions().scavengers) or 0) ~= 0) then
	return
end

function widget:GetInfo()
	return {
		name    = "Scavenger Stats Panel",
		desc    = "",
		author  = "Damgam",
		date    = "2021",
		layer   = -1,
		enabled = true,
	}
end

local spGetGameRulesParam = Spring.GetGameRulesParam

local function RefreshStats()
    statsScavCommanders             = spGetGameRulesParam("scavStatsScavCommanders") or 0
    statsScavSpawners               = spGetGameRulesParam("scavStatsScavSpawners") or 0
    statsScavUnits                  = spGetGameRulesParam("scavStatsScavUnits") or 0
    statsScavUnitsKilled            = spGetGameRulesParam("scavStatsScavUnitsKilled") or 0
    statsGlobalScore                = spGetGameRulesParam("scavStatsGlobalScore") or 0
    statsTechLevel                  = spGetGameRulesParam("scavStatsTechLevel") or "Null"
    statsTechPercentage             = spGetGameRulesParam("scavStatsTechPercentage") or 0

    statsBossFightCountdownStarted  = spGetGameRulesParam("scavStatsBossFightCountdownStarted") or 0
    statsBossFightCountdown         = spGetGameRulesParam("scavStatsBossFightCountdown") or 0
    
    statsBossSpawned                = spGetGameRulesParam("scavStatsBossSpawned") or 0
    statsBossMaxHealth              = spGetGameRulesParam("scavStatsBossMaxHealth") or 0
    statsBossHealth                 = spGetGameRulesParam("scavStatsBossHealth") or 0

    statsDifficulty                 = spGetGameRulesParam("scavStatsDifficulty") or "Null"
end

function widget:GameFrame(n)
    if n%30 == 0 then
        RefreshStats()
    end
end

function widget:Update()


end