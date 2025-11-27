local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Continuous Aim",
		desc = "Applies lower 'reaimTime for continuous aim'",
		author = "Doo, Beherith",
		date = "April 2018",
		license = "GNU GPL, v2 or later",
		layer = 0, -- after game_dynamic_maxunits for accurate unit caps
		enabled = tonumber(Engine.versionMajor) >= 105,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local reaimTimeMax = 0.5 ---@type number Caps dynamic reaim times and filters unitDefs. In seconds.
local spamRatingBase = 400 ---@type integer Team reaim time increases by 1 frame each X units made.
local spamRatingMax = 1000 ---@type integer Sets the minimum performance penalty for spammed units.
local unitCapDefault = 2400 ---@type integer The per-team unit cap we assume in these spam ratings.

local math_floor = math.floor
local math_max = math.max
local math_clamp = math.clamp

local spGetTeamMaxUnits = Spring.GetTeamMaxUnits
local spSetUnitWeaponState = Spring.SetUnitWeaponState

local reaimFramesMax = math.round(reaimTimeMax * Game.gameSpeed)
local unitCapReference = math_max(Spring.GetModOptions().maxunits, unitCapDefault)
local unitCapNonPlayer = math.min(unitCapReference, unitCapDefault * 2) * 4 -- for one team vs. many

local unitReaimTimes = {}
local unitSpamRating = {}
local unitWeaponCount = {}

-- Unit scripts have to manually check in script if it is at the desired heading.
-- See: https://springrts.com/phpbb/viewtopic.php?t=36654
for unitDefID, unitDef in pairs(UnitDefs) do
	if #unitDef.weapons >= 1 then
		if tonumber(unitDef.customParams.continuous_aim_time) then
			local reaimTime = tonumber(unitDef.customParams.continuous_aim_time)
			local reaimFrames = math_max(math.round(reaimTime * Game.gameSpeed), 1)
			if reaimFrames < reaimFramesMax then
				unitReaimTimes[unitDefID] = reaimFrames
				unitWeaponCount[unitDefID] = #unitDef.weapons
			end
		end
		local spamCount = tonumber(unitDef.customParams.continuous_aim_spam) or spamRatingBase
		local spamScore = 1 / math.clamp(spamCount, 1, spamRatingMax) -- as reaimTime per unit
		unitSpamRating[unitDefID] = spamScore * unitCapDefault -- as reaimTime/unit/max units
	end
end

local teamMaxUnits = {}
local teamReaimTimes = {}
local pveTeamID = Spring.Utilities.GetRaptorTeamID() or Spring.Utilities.GetScavTeamID()

local function getTeamMaxUnits(teamID)
	local actual = spGetTeamMaxUnits(teamID)
	local reference = teamID == pveTeamID and unitCapNonPlayer or unitCapReference
	return actual and (math_max(actual, reference) + reference) * 0.5 or reference
end

function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
	local unitReaimTime = unitReaimTimes[unitDefID]

	if unitReaimTime then
		local teamReaimTime = teamReaimTimes[unitTeam]
		local addSpamRating = unitSpamRating[unitDefID] / teamMaxUnits[unitTeam]

		teamReaimTime = teamReaimTime + addSpamRating
		teamReaimTimes[unitTeam] = teamReaimTime
		unitReaimTime = math_clamp(math_floor(unitReaimTime + teamReaimTime), 1, reaimFramesMax)

		for weaponNum = 1, unitWeaponCount[unitDefID] do
			-- NOTE: this will prevent unit from firing if it does not IMMEDIATELY return from AimWeapon (no sleeps, not wait for turns!)
			-- So you have to manually check in script if it is at the desired heading
			spSetUnitWeaponState(unitID, weaponNum, "reaimTime", unitReaimTime)
		end
	end
end

function gadget:MetaUnitRemoved(unitID, unitDefID, teamID)
	if unitSpamRating[unitDefID] then
		teamReaimTimes[teamID] = teamReaimTimes[teamID] - unitSpamRating[unitDefID]
	end
end

function gadget:TeamDied(deadTeamID)
	-- For now, this is our only source of TransferTeamMaxUnits after init.
	for _, teamID in pairs(Spring.GetTeamList()) do
		teamMaxUnits[teamID] = getTeamMaxUnits(teamID)
	end
end

function gadget:Initialize()
	teamMaxUnits = {}
	teamReaimTimes = {}

	for _, teamID in pairs(Spring.GetTeamList()) do
		teamMaxUnits[teamID] = getTeamMaxUnits(teamID)
		teamReaimTimes[teamID] = 0

		for _, unitID in pairs(Spring.GetTeamUnits(teamID)) do
			gadget:MetaUnitAdded(unitID, Spring.GetUnitDefID(unitID), teamID)
		end
	end
end
