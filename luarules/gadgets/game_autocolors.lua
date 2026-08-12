local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "AutoColorPicker",
		desc = "Automatically assigns colors to teams",
		author = "Damgam, Born2Crawl (color palette)",
		date = "2021",
		license = "GNU GPL, v2 or later",
		layer = -100,
		enabled = true,
	}
end

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
local gaiaTeamID = Spring.GetGaiaTeamID()
local teamList = Spring.GetTeamList()
local allyTeamList = Spring.GetAllyTeamList()
local allyTeamCount = #allyTeamList - 1
local isSurvival = BAR.Utilities.Gametype.IsPvE()

local survivalColorNum = 1 -- Starting from color #1
local survivalColorVariation = 0 -- Current color variation
local allyTeamNum = 0
local teamSizes = {}

local myAllyTeamID, myTeamID
if not gadgetHandler:IsSyncedCode() then
	myAllyTeamID = Spring.GetLocalAllyTeamID()
	myTeamID = Spring.GetLocalTeamID()
end

-- Team color palettes and their name annotations live in a shared config,
-- so UI code (e.g. gui_advplayerslist color tooltip) can look up the same colors
local teamColorConfig = VFS.Include("common/configs/team_colors.lua")

local armBlueColor = teamColorConfig.specialColors.armBlue -- Armada Blue
local corRedColor = teamColorConfig.specialColors.corRed -- Cortex Red
local scavPurpColor = teamColorConfig.specialColors.scavPurp -- Scav Purple
local raptorOrangeColor = teamColorConfig.specialColors.raptorOrange -- Raptor Orange
local gaiaGrayColor = teamColorConfig.specialColors.gaiaGray -- Gaia Grey
local legGreenColor = teamColorConfig.specialColors.legGreen -- Legion Green

local ffaColors = teamColorConfig.ffaColors
local survivalColors = teamColorConfig.survivalColors
local teamColors = teamColorConfig.teamColors

-- delete excess so a table shuffe won't use the colors added on the bottom
if #ffaColors > #teamList - 1 then
	for i = #teamList, #ffaColors do
		ffaColors[i] = nil
	end
end

local r = math.random(1, 100000)
math.randomseed(1) -- make sure the next sequence of randoms can be reproduced
local teamRandoms = {}
for i = 1, #teamList do
	teamRandoms[teamList[i]] = { math.random(), math.random(), math.random() }
end
math.randomseed(r)

local iconDevModeColors = {
	armblue = armBlueColor,
	corred = corRedColor,
	scavpurp = scavPurpColor,
	raptororange = raptorOrangeColor,
	gaiagray = gaiaGrayColor,
	leggren = legGreenColor,
}
local iconDevMode = Spring.GetModOptions().teamcolors_icon_dev_mode
local iconDevModeColor = iconDevModeColors[iconDevMode]

local function shuffleTable(Table)
	local originalTable = {}
	table.append(originalTable, Table)
	local shuffledTable = {}
	if #originalTable > 0 then
		repeat
			local r = math.random(#originalTable)
			table.insert(shuffledTable, originalTable[r])
			table.remove(originalTable, r)
		until #originalTable == 0
	else
		shuffledTable = originalTable
	end
	return shuffledTable
end

local function shuffleAllColors()
	ffaColors = shuffleTable(ffaColors)
	survivalColors = shuffleTable(survivalColors)
	for i = 1, #teamColors do
		for j = 1, #teamColors[i] do
			teamColors[i][j] = shuffleTable(teamColors[i][j])
		end
	end
end

local function hex2RGB(hex)
	hex = hex:gsub("#", "")
	return { tonumber("0x" .. hex:sub(1, 2)), tonumber("0x" .. hex:sub(3, 4)), tonumber("0x" .. hex:sub(5, 6)) }
end

-- we don't want to use FFA colors for TeamFFA, because we want each team to have its own color theme
local useFFAColors = BAR.Utilities.Gametype.IsFFA() and not BAR.Utilities.Gametype.IsTeams()
if not useFFAColors and not teamColors[allyTeamCount] and not isSurvival then -- Edge case for TeamFFA with more than supported number of teams
	useFFAColors = true
end

local teamColorsTable = {}
local trueTeamColorsTable = {} -- run first as if we were specs so when we become specs, we can restore the true intended team colors
local trueFfaColors = table.copy(ffaColors) -- run first as if we were specs so when we become specs, we can restore the true intended ffa colors
local trueSurvivalColors = table.copy(survivalColors) -- run first as if we were specs so when we become specs, we can restore the true intended survival colors

local function setupTeamColor(teamID, allyTeamID, isAI, localRun)
	if iconDevModeColor then
		teamColorsTable[teamID] = {
			r = hex2RGB(iconDevModeColor)[1],
			g = hex2RGB(iconDevModeColor)[2],
			b = hex2RGB(iconDevModeColor)[3],
		}

	-- Simple Team Colors
	elseif
		localRun
		and (
			Spring.GetConfigInt("SimpleTeamColors", 0) == 1
			or (anonymousMode == "allred" and not Spring.GetSpectatingState())
		)
	then
		local brightnessVariation = 0
		local maxColorVariation = 0
		if Spring.GetConfigInt("SimpleTeamColorsUseGradient", 0) == 1 then
			local totalEnemyDimmingCount = 0
			for allyTeamID, count in pairs(dimmingCount) do
				if allyTeamID ~= myAllyTeamID then
					totalEnemyDimmingCount = totalEnemyDimmingCount + count
				end
			end
			brightnessVariation = (0.7 - ((1 / #Spring.GetTeamList(allyTeamID)) * dimmingCount[allyTeamID])) * 255
			brightnessVariation = brightnessVariation * math.min((#Spring.GetTeamList(allyTeamID) * 0.8) - 1, 1) -- dont change brightness too much in tiny teams
			maxColorVariation = 60
		end
		local color = hex2RGB(ffaColors[allyTeamID + 1] or "#333333")
		if Spring.GetConfigInt("SimpleTeamColorsFactionSpecific", 0) == 1 then
			if isAI and string.find(isAI, "Scavenger") then
				color = hex2RGB(scavPurpColor)
			elseif isAI and string.find(isAI, "Raptor") then
				color = hex2RGB(raptorOrangeColor)
			elseif teamID == gaiaTeamID then
				color = hex2RGB(gaiaGrayColor)
			elseif Spring.GetTeamRulesParam(teamID, "startUnit") and anonymousMode ~= "allred" then
				local side = string.sub(UnitDefs[Spring.GetTeamRulesParam(teamID, "startUnit")].name, 1, 3)
				if side == "arm" then
					color = hex2RGB(armBlueColor)
				elseif side == "cor" then
					color = hex2RGB(corRedColor)
				elseif side == "leg" then
					color = hex2RGB(legGreenColor)
				end
			end
		elseif teamID == gaiaTeamID then
			brightnessVariation = 0
			maxColorVariation = 0
			color = hex2RGB(gaiaGrayColor)
		elseif teamID == myTeamID then
			brightnessVariation = 0
			maxColorVariation = 0
			color = {
				Spring.GetConfigInt("SimpleTeamColorsPlayerR", 0),
				Spring.GetConfigInt("SimpleTeamColorsPlayerG", 77),
				Spring.GetConfigInt("SimpleTeamColorsPlayerB", 255),
			}
		elseif allyTeamID == myAllyTeamID then
			color = {
				Spring.GetConfigInt("SimpleTeamColorsAllyR", 0),
				Spring.GetConfigInt("SimpleTeamColorsAllyG", 255),
				Spring.GetConfigInt("SimpleTeamColorsAllyB", 0),
			}
		elseif allyTeamID ~= myAllyTeamID then
			color = {
				Spring.GetConfigInt("SimpleTeamColorsEnemyR", 255),
				Spring.GetConfigInt("SimpleTeamColorsEnemyG", 16),
				Spring.GetConfigInt("SimpleTeamColorsEnemyB", 5),
			}
		end
		color[1] = math.min(color[1] + brightnessVariation, 255)
			+ ((teamRandoms[teamID][1] * (maxColorVariation * 2)) - maxColorVariation)
		color[2] = math.min(color[2] + brightnessVariation, 255)
			+ ((teamRandoms[teamID][2] * (maxColorVariation * 2)) - maxColorVariation)
		color[3] = math.min(color[3] + brightnessVariation, 255)
			+ ((teamRandoms[teamID][3] * (maxColorVariation * 2)) - maxColorVariation)
		teamColorsTable[teamID] = {
			r = color[1],
			g = color[2],
			b = color[3],
		}
	elseif isAI and string.find(isAI, "Scavenger") then
		teamColorsTable[teamID] = {
			r = hex2RGB(scavPurpColor)[1],
			g = hex2RGB(scavPurpColor)[2],
			b = hex2RGB(scavPurpColor)[3],
		}
	elseif isAI and string.find(isAI, "Raptor") then
		teamColorsTable[teamID] = {
			r = hex2RGB(raptorOrangeColor)[1],
			g = hex2RGB(raptorOrangeColor)[2],
			b = hex2RGB(raptorOrangeColor)[3],
		}
	elseif teamID == gaiaTeamID then
		teamColorsTable[teamID] = {
			r = hex2RGB(gaiaGrayColor)[1],
			g = hex2RGB(gaiaGrayColor)[2],
			b = hex2RGB(gaiaGrayColor)[3],
		}
	elseif isSurvival and survivalColors[(#Spring.GetTeamList()) - 2] then
		teamColorsTable[teamID] = {
			r = hex2RGB(survivalColors[survivalColorNum])[1]
				+ math.random(-survivalColorVariation, survivalColorVariation),
			g = hex2RGB(survivalColors[survivalColorNum])[2]
				+ math.random(-survivalColorVariation, survivalColorVariation),
			b = hex2RGB(survivalColors[survivalColorNum])[3]
				+ math.random(-survivalColorVariation, survivalColorVariation),
		}
		survivalColorNum = survivalColorNum + 1 -- Will start from the next color next time

	-- auto ffa gradient colored for huge player games
	elseif
		useFFAColors
		or (#Spring.GetTeamList(allyTeamCount - 1) > 1 and (not teamColors[allyTeamCount] or not teamColors[allyTeamCount][1][#Spring.GetTeamList(
			allyTeamCount - 1
		)]))
		or #Spring.GetTeamList() > 30
		or (#Spring.GetTeamList(allyTeamCount - 1) == 1 and not ffaColors[allyTeamCount])
	then
		local color = hex2RGB(ffaColors[allyTeamID + 1] or "#333333")
		local maxIterations = math.floor((#teamList - 1) / #ffaColors)
		local brightnessVariation = (0.6 - ((1 / #Spring.GetTeamList(allyTeamID)) * dimmingCount[allyTeamID])) * 255
		brightnessVariation = brightnessVariation * math.min((#Spring.GetTeamList(allyTeamID) * 0.7) - 1, 1) -- dont change brightness too much in tiny teams
		local maxColorVariation = (120 / math.max(1, allyTeamCount - 1))
		if #Spring.GetTeamList(allyTeamID) == 1 then
			brightnessVariation = 0
			maxColorVariation = 0
		end

		if maxIterations > 1 then
			local iteration = 1 + math.floor((allyTeamID + 1) / #ffaColors)
			local ffaColor = (allyTeamID + 1) - (#ffaColors * (iteration - 1)) + 1
			if iteration ~= 1 then
				color = hex2RGB(ffaColors[ffaColor])
			end
			if iteration == 1 then
				color[1] = color[1] + 40
				color[2] = color[2] + 40
				color[3] = color[3] + 40
			elseif iteration == 2 then
				color[1] = color[1] - 70
				color[2] = color[2] - 70
				color[3] = color[3] - 70
			elseif iteration == 3 then
				color[1] = color[1] + 130
				color[2] = color[2] + 130
				color[3] = color[3] + 130
			end
		end
		if teamID == gaiaTeamID then
			brightnessVariation = 0
			maxColorVariation = 0
			color = hex2RGB(gaiaGrayColor)
		end
		color[1] = math.clamp(
			math.floor(
				color[1]
					+ brightnessVariation
					+ ((teamRandoms[teamID][1] * (maxColorVariation * 2)) - maxColorVariation)
			),
			0,
			255
		)
		color[2] = math.clamp(
			math.floor(
				color[2]
					+ brightnessVariation
					+ ((teamRandoms[teamID][2] * (maxColorVariation * 2)) - maxColorVariation)
			),
			0,
			255
		)
		color[3] = math.clamp(
			math.floor(
				color[3]
					+ brightnessVariation
					+ ((teamRandoms[teamID][3] * (maxColorVariation * 2)) - maxColorVariation)
			),
			0,
			255
		)
		teamColorsTable[teamID] = {
			r = color[1],
			g = color[2],
			b = color[3],
		}
	else
		if not teamSizes[allyTeamID] then
			allyTeamNum = allyTeamNum + 1
			teamSizes[allyTeamID] = { allyTeamNum, 1, 0 } -- Team number, Starting color number, Color variation
		end

		if
			teamColors[allyTeamCount] -- If we have the color set for this number of teams
			and teamColors[allyTeamCount][teamSizes[allyTeamID][1]]
		then -- And this team number exists in the color set
			if not teamColors[allyTeamCount][teamSizes[allyTeamID][1]][teamSizes[allyTeamID][2]] then -- If we have no color for this player anymore
				teamSizes[allyTeamID][2] = 1 -- Starting from the first color again..
			end

			-- Assigning R,G,B values with specified color variations
			teamColorsTable[teamID] = {
				r = hex2RGB(teamColors[allyTeamCount][teamSizes[allyTeamID][1]][teamSizes[allyTeamID][2]])[1]
					+ math.random(-teamSizes[allyTeamID][3], teamSizes[allyTeamID][3]),
				g = hex2RGB(teamColors[allyTeamCount][teamSizes[allyTeamID][1]][teamSizes[allyTeamID][2]])[2]
					+ math.random(-teamSizes[allyTeamID][3], teamSizes[allyTeamID][3]),
				b = hex2RGB(teamColors[allyTeamCount][teamSizes[allyTeamID][1]][teamSizes[allyTeamID][2]])[3]
					+ math.random(-teamSizes[allyTeamID][3], teamSizes[allyTeamID][3]),
			}
			teamSizes[allyTeamID][2] = teamSizes[allyTeamID][2] + 1 -- Will start from the next color next time
		else
			Spring.Echo("[AUTOCOLORS] Error: Team Colors Table is broken or missing for this allyteam set")
			teamColorsTable[teamID] = {
				r = 255,
				g = 255,
				b = 255,
			}
		end
	end
end

local function setupAllTeamColors(localRun)
	survivalColorNum = 1 -- Starting from color #1
	survivalColorVariation = 0 -- Current color variation
	allyTeamNum = 0
	teamSizes = {}

	dimmingCount = {}
	for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		dimmingCount[allyTeamID] = 0
	end
	for i = 1, #teamList do
		local teamID = teamList[i]
		local allyTeamID = select(6, Spring.GetTeamInfo(teamID))
		dimmingCount[allyTeamID] = dimmingCount[allyTeamID] + 1
		local isAI = Spring.GetTeamLuaAI(teamID)
		setupTeamColor(teamID, allyTeamID, isAI, localRun)
	end
end
setupAllTeamColors(false)
trueTeamColorsTable = table.copy(teamColorsTable) -- store the true team colors so we can restore them when we become a spec

if gadgetHandler:IsSyncedCode() then --- NOTE: STUFF DONE IN SYNCED IS FOR REPLAY WEBSITE
	local AutoColors = {}
	for i = 1, #teamList do
		local teamID = teamList[i]
		AutoColors[i] = {
			teamID = teamID,
			r = trueTeamColorsTable[teamID].r,
			g = trueTeamColorsTable[teamID].g,
			b = trueTeamColorsTable[teamID].b,
		}
	end
	Spring.SendLuaRulesMsg("AutoColors" .. Json.encode(AutoColors))
else -- UNSYNCED
	local myPlayerID = Spring.GetLocalPlayerID()
	local mySpecState = Spring.GetSpectatingState()

	if anonymousMode == "local" and not mySpecState then
		shuffleAllColors()
	end
	if (anonymousMode == "local" and not mySpecState) or Spring.GetConfigInt("SimpleTeamColors", 0) == 1 then
		setupAllTeamColors(true)
	end

	local function isDiscoEnabled()
		return anonymousMode == "disco" and not mySpecState
	end

	-- shuffle colors for all teams except ourselves
	local function discoShuffle(myTeamID)
		-- store own color and do regular shuffle
		local myColor = teamColorsTable[myTeamID]
		shuffleAllColors()
		setupAllTeamColors(true)

		-- swap color with any team that might have been assigned own color
		local teamIDToSwapWith = nil
		for teamID, color in pairs(teamColorsTable) do
			if myColor.r == color.r and myColor.g == color.g and myColor.b == color.b then
				teamIDToSwapWith = teamID
				break
			end
		end
		if teamIDToSwapWith ~= nil then
			teamColorsTable[teamIDToSwapWith] = teamColorsTable[myTeamID]
		end

		-- restore own color
		teamColorsTable[myTeamID] = myColor
	end

	local function updateTeamColors()
		if isDiscoEnabled() then
			discoShuffle(Spring.GetLocalTeamID())
		end
		for teamID, color in pairs(teamColorsTable) do
			Spring.SetTeamColor(teamID, color.r / 255, color.g / 255, color.b / 255)
		end
	end
	updateTeamColors()

	local discoTimer = 0
	local discoTimerThreshold = 2 * 60 -- shuffle every 2 minutes with disco mode enabled
	function gadget:Update()
		if isDiscoEnabled() then
			discoTimer = discoTimer + Spring.GetLastUpdateSeconds()
			if discoTimer > discoTimerThreshold then
				discoTimer = 0
				updateTeamColors()
			end
		elseif Spring.GetConfigInt("UpdateTeamColors", 0) == 1 then
			setupAllTeamColors(true)
			updateTeamColors()
			Spring.SetConfigInt("UpdateTeamColors", 0)
			Spring.SetConfigInt("SimpleTeamColors_Reset", 0)
		elseif
			Spring.GetConfigInt("SimpleTeamColors", 0) == 1
			and Spring.GetConfigInt("SimpleTeamColorsFactionSpecific", 0) == 1
			and Spring.GetGameFrame() < 300
		then
			Spring.SetConfigInt("UpdateTeamColors", 1)
		end
	end

	function gadget:PlayerChanged(playerID)
		if playerID ~= myPlayerID then
			return
		end
		myAllyTeamID = Spring.GetLocalAllyTeamID()
		local prevMyTeamID = myTeamID
		myTeamID = Spring.GetLocalTeamID()
		if mySpecState and prevMyTeamID ~= myTeamID and Spring.GetConfigInt("SimpleTeamColors", 0) == 1 then
			Spring.SetConfigInt("UpdateTeamColors", 1)
		end
		if mySpecState ~= Spring.GetSpectatingState() then
			mySpecState = Spring.GetSpectatingState()
			teamColorsTable = table.copy(trueTeamColorsTable)
			ffaColors = table.copy(trueFfaColors)
			survivalColors = table.copy(trueSurvivalColors)
			updateTeamColors() -- apply true colors directly; avoids setupAllTeamColors(true) re-computing with live game state
		end
	end
end
