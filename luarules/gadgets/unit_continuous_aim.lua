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


local convertedUnitsNames = {
	-- value is reaimtime in frames, engine default is 15
	['armfav'] = 3,
	['armbeamer'] = 3,
	['armpw'] = 2,
	['armpwt4'] = 2,
	['armflea'] = 2,
	['armrock'] = 2,
	['armham'] = 2,
	['armwar'] = 6,
	['armjeth'] = 2,
	['corfav'] = 3,
	['corak'] = 2,
	['corthud'] = 2,
	['corstorm'] = 2,
	['corcrash'] = 5,
	['legkark'] = 2,
	['corkark'] = 2,
	['cordeadeye'] =2,
	['armsnipe'] = 2,
	['armfido'] = 3,
	['armfboy'] = 2,
	['armfast'] = 2,
	['armamph'] = 3,
	['armmav'] = 2,
	['armspid'] = 3,
	['armsptk'] = 5,
	['armzeus'] = 3,
	['coramph'] = 3,
	['corcan'] = 2,
	['corhrk'] = 5,
	['cormando'] = 2,
	['cormort'] = 2,
	['corpyro'] = 2,
	['cortermite'] = 2,
	['armraz'] = 1,
	['armmar'] = 3,
	['armbanth'] = 1,
	['corkorg'] = 1,
	['armvang'] = 3,
	['armcrus'] = 5,
	['corsala'] = 6,
	['corsiegebreaker'] = 5,
	['legerailtank'] = 9,

	-- the following units get a faster reaimtime to counteract their turret acceleration
	['armthor'] = 4,
	['armflash'] = 6,
	['corgator'] = 6,
	['armdecade'] = 6,
	['coresupp'] = 6,
	['corhlt'] = 5,
	['corfhlt'] = 5,
	['cordoom'] = 5,
	['corshiva'] = 5,
	['corcat'] = 5,
	['corkarg'] = 5,
	['corbhmth'] = 5,
	['armguard'] = 5,
	['armamb'] = 5,
	['corpun'] = 5,
	['cortoast'] = 5,
	['corbats'] = 5,
	['corblackhy'] = 6,
	['corscreamer'] = 5,
	['corcom'] = 5,
	['armcom'] = 5,
	['cordecom'] = 5,
	['armdecom'] = 5,
	['legcom'] = 5,
	['legdecom'] = 5,
	['legcomlvl2'] = 5,
	['legcomlvl3'] = 5,
	['legcomlvl4'] = 5,
	['legcomlvl5'] = 5,
	['legcomlvl6'] = 5,
	['legcomlvl7'] = 5,
	['legcomlvl8'] = 5,
	['legcomlvl9'] = 5,
	['legcomlvl10'] = 5,
	['legah'] = 5,
	['legbal'] = 5,
	['legbastion'] = 5,
	['legcen'] = 3,
	['legfloat'] = 5,
	['leggat'] = 5,
	['leggob'] = 5,
	['leginc'] = 1,
	['cordemon'] = 6,
	['corcrwh'] = 7,
	['leglob'] = 5,
	['legmos'] = 5,
	['leghades'] = 5,
	['leghelios'] = 5,
	['legheavydrone'] = 5,
	['legkeres'] = 5,
	['legrail'] = 5,
	['legbar'] = 5,
	['legcomoff'] = 5,
	['legcomt2off'] = 5,
	['legcomt2com'] = 5,
	['legstr'] = 3,
	['legamph'] = 4,
	['legbart'] = 5,
	['legmrv'] = 5,
	['legsco'] = 5,
	['leegmech'] = 5,
	['legionnaire'] = 5,
	['legafigdef'] = 5,
	['legvenator'] = 5,
    ['legmed'] = 5,
	['legaskirmtank'] = 5,
	['legaheattank'] = 3,
	['legeheatraymech'] = 1,
	['legbunk'] = 3,
	['legrwall'] = 4,
	['legjav'] = 1,
	['legeshotgunmech'] = 3,
	['legehovertank'] = 4,
}
--add entries for scavboss
local scavengerBossV4Table = {'scavengerbossv4_veryeasy', 'scavengerbossv4_easy', 'scavengerbossv4_normal', 'scavengerbossv4_hard', 'scavengerbossv4_veryhard', 'scavengerbossv4_epic',
 'scavengerbossv4_veryeasy_scav', 'scavengerbossv4_easy_scav', 'scavengerbossv4_normal_scav', 'scavengerbossv4_hard_scav', 'scavengerbossv4_veryhard_scav', 'scavengerbossv4_epic_scav'}
for _, name in pairs(scavengerBossV4Table) do
	convertedUnitsNames[name] = 4
end
--if Spring.GetModOptions().emprework then
	--convertedUnitsNames['armdfly'] = 50
--end
-- convert unitname -> unitDefID
local convertedUnits = {}
for name, params in pairs(convertedUnitsNames) do
	if UnitDefNames[name] then
		convertedUnits[UnitDefNames[name].id] = params
	end
end
convertedUnitsNames = nil


local spamUnitsTeamsNames = { --{unitDefID = {teamID = totalcreated,...}}
	['armpw'] = {},
	['armflea'] = {},
	['armfav'] = {},
	['corak'] = {},
	['corfav'] = {},
}
-- convert unitname -> unitDefID
local spamUnitsTeams = {}
for name, params in pairs(spamUnitsTeamsNames) do
	if UnitDefNames[name] then
		spamUnitsTeams[UnitDefNames[name].id] = params
	end
end
spamUnitsTeamsNames = nil


local spamUnitsTeamsReaimTimes = {} --{unitDefID = {teamID = currentReAimTime,...}}


-- for every spamThreshold'th spammable unit type built by this team, increase reaimtime by 1 for that team
local spamThreshold = 100
local maxReAimTime = 15

-- add for scavengers copies
local convertedUnitsCopy = table.copy(convertedUnits)
for id, v in pairs(convertedUnitsCopy) do
	if UnitDefNames[UnitDefs[id].name..'_scav'] then
		convertedUnits[UnitDefNames[UnitDefs[id].name..'_scav'].id] = v
	end
end

local spamUnitsTeamsCopy = table.copy(spamUnitsTeams)
for id,v in pairs(spamUnitsTeamsCopy) do
	if UnitDefNames[UnitDefs[id].name..'_scav'] then
		spamUnitsTeams[UnitDefNames[UnitDefs[id].name..'_scav'].id] = {}
	end
end

for unitDefID, _ in pairs(spamUnitsTeams) do
	spamUnitsTeamsReaimTimes[unitDefID] = {}
end

local unitWeapons = {}
for unitDefID, _ in pairs(convertedUnits) do
	local unitDef = UnitDefs[unitDefID]
	if unitDef then
		local weapons = unitDef.weapons
		if #weapons > 0 then
			unitWeapons[unitDefID] = {}
			for id, _ in pairs(weapons) do
				unitWeapons[unitDefID][id] = true	-- no need to store weapondefid
			end
		else
			-- units with no weapons shouldnt even be here
			convertedUnits[unitDefID] = nil
		end
	end
end

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
				Spring.SetUnitWeaponState(unitID, id, "reaimTime", currentReaimTime)
			end
		end
	end
end
