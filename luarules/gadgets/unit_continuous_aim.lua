local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Continuous Aim",
		desc = "Applies lower 'reaimTime for continuous aim'",
		author = "Doo, Beherith",
		date = "April 2018",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true, -- When we will move on 105 :)
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local spSetUnitWeaponState = Spring.SetUnitWeaponState

-- customparams.reaimtime is the reaim time in frames (engine default is 15)
-- customparams.reaim_spam additionally degrades the reaim time as a team keeps building the unit
local convertedUnits = {} --{unitDefID = reaimTime}
local spamUnitsTeams = {} --{unitDefID = {teamID = totalcreated,...}}
local spamUnitsTeamsReaimTimes = {} --{unitDefID = {teamID = currentReAimTime,...}}
local unitWeapons = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	local reaimTime = tonumber(unitDef.customParams.reaimtime)
	if reaimTime and #unitDef.weapons > 0 then
		convertedUnits[unitDefID] = reaimTime
		unitWeapons[unitDefID] = {}
		for id, _ in pairs(unitDef.weapons) do
			unitWeapons[unitDefID][id] = true -- no need to store weapondefid
		end
		if unitDef.customParams.reaim_spam then
			spamUnitsTeams[unitDefID] = {}
			spamUnitsTeamsReaimTimes[unitDefID] = {}
		end
	end
end

-- for every spamThreshold'th spammable unit type built by this team, increase reaimtime by 1 for that team
local spamThreshold = 100
local maxReAimTime = 15

function gadget:UnitCreated(unitID, unitDefID, teamID)
	if convertedUnits[unitDefID] then
		local currentReaimTime = convertedUnits[unitDefID]

		if spamUnitsTeams[unitDefID] then
			if not spamUnitsTeams[unitDefID][teamID] then
				-- initialize for this team at base defaults
				spamUnitsTeams[unitDefID][teamID] = 1
				spamUnitsTeamsReaimTimes[unitDefID][teamID] = convertedUnits[unitDefID]
			else
				local spamCount = spamUnitsTeams[unitDefID][teamID] + 1
				spamUnitsTeams[unitDefID][teamID] = spamCount
				currentReaimTime = spamUnitsTeamsReaimTimes[unitDefID][teamID]
				if spamCount % spamThreshold == 0 and currentReaimTime < maxReAimTime then
					spamUnitsTeamsReaimTimes[unitDefID][teamID] = currentReaimTime + 1
					--Spring.Echo("Unit type", unitDefID,'has been built', spamCount, 'times by team', teamID,'increasing reaimtime to ', currentReaimTime + 1)
				end
			end
		end
		if currentReaimTime < 15 then
			for id, _ in pairs(unitWeapons[unitDefID]) do
				-- NOTE: this will prevent unit from firing if it does not IMMEDIATELY return from AimWeapon (no sleeps, not wait for turns!)
				-- So you have to manually check in script if it is at the desired heading
				-- https://springrts.com/phpbb/viewtopic.php?t=36654
				spSetUnitWeaponState(unitID, id, "reaimTime", currentReaimTime)
			end
		end
	end
end
