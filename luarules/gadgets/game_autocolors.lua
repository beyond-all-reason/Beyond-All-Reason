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
local isSurvival = Spring.Utilities.Gametype.IsPvE()

local survivalColorNum = 1 -- Starting from color #1
local survivalColorVariation = 0 -- Current color variation
local allyTeamNum = 0
local teamSizes = {}
local myAllyTeamID = Spring.GetMyAllyTeamID()
local myTeamID = Spring.GetMyTeamID()

-- Special colors
local armBlueColor = "#004DFF" -- Armada Blue
local corRedColor = "#FF1005" -- Cortex Red
local scavPurpColor = "#6809A1" -- Scav Purple
local raptorOrangeColor = "#CC8914" -- Raptor Orange
local gaiaGrayColor = "#7F7F7F" -- Gaia Grey
local legGreenColor = "#0CE818" -- Legion Green

-- NEW IceXuick Colors V6
local ffaColors = {
	"#004DFF", -- 1
	"#FF1005", -- 2
	"#0CE908", -- 3
	"#FFD200", -- 4
	"#F80889", -- 5
	"#09F5F5", -- 6
	"#FF6107", -- 7
	"#F190B3", -- 8
	"#097E1C", -- 9
	"#C88B2F", -- 10
	"#7CA1FF", -- 11
	"#9F0D05", -- 12
	"#3EFFA2", -- 13
	"#F5A200", -- 14
	"#C4A9FF", -- 15
	"#0B849B", -- 16
	"#B4FF39", -- 17
	"#FF68EA", -- 18
	"#D8EEFF", -- 19
	"#689E3D", -- 20
	"#B04523", -- 21
	"#FFBB7C", -- 22
	"#3475FF", -- 23
	"#DD783F", -- 24
	"#FFAAF3", -- 25
	"#4A4376", -- 26
	"#773A01", -- 27
	"#B7EA63", -- 28
	"#9F0D05", -- 29
	"#7EB900", -- 30
}
-- delete excess so a table shuffe wont use the colors added on the bottom
if #ffaColors > #teamList-1 then
	for i = #teamList, #ffaColors do
		ffaColors[i] = nil
	end
end


local survivalColors = {
	"#0B3EF3", -- 1
	"#FF1005", -- 2
	"#0CE908", -- 3
	"#ffab8c", -- 4
	"#09F5F5", -- 5
	"#FCEEA4", -- 6
	"#097E1C", -- 7
	"#F190B3", -- 8
	"#F80889", -- 9
	"#3EFFA2", -- 10
	"#911806", -- 11
	"#7CA1FF", -- 12
	"#3c7a74", -- 13
	"#B04523", -- 14
	"#B4FF39", -- 15
	"#773A01", -- 16
	"#D8EEFF", -- 17
	"#689E3D", -- 18
	"#0B849B", -- 19
	"#FFD200", -- 20
	"#971C48", -- 21
	"#4A4376", -- 22
	"#764A4A", -- 23
	"#4F2684", -- 24
}

local teamColors = {
	{ -- One Team (not possible)
		{ -- First Team
			"#004DFF", -- Armada Blue
		},
	},

	{ -- Two Teams
		{ -- First Team (Cool)
			"#0B3EF3", --1
			"#0CE908", --2
			"#00f5e5", --3
			"#6941f2", --4
			"#8fff94", --5
			"#1b702f", --6
			"#7cc2ff", --7
			"#a294ff", --8
			"#0B849B", --9
			"#689E3D", --10
			"#4F2684", --11
			"#2C32AC", --12
			"#6968A0", --13
			"#D8EEFF", --14
			"#3475FF", --15
			"#7EB900", --16
			"#4A4376", --17
			"#B7EA63", --18
			"#C4A9FF", --19
			"#37713A", --20
		},
		{ -- Second Team (Warm)
			"#FF1005", --1
			"#FFD200", --2
			"#FF6107", --3
			"#F80889", --4
			"#FCEEA4", --5
			"#8a2828", --6
			"#F190B3", --7
			"#C88B2F", --8
			"#B04523", --9
			"#FFBB7C", --10
			"#A35274", --11
			"#773A01", --12
			"#F5A200", --13
			"#BBA28B", --14
			"#971C48", --15
			"#FF68EA", --16
			"#DD783F", --17
			"#FFAAF3", --18
			"#764A4A", --19
			"#9F0D05", --20
		},
	},

	{ -- Three Teams
		{ -- First Team (Blue)
			"#004DFF", -- 1
			"#09F5F5", -- 2
			"#7CA1FF", -- 3
			"#2C32AC", -- 4
			"#D8EEFF", -- 5
			"#0B849B", -- 6
			"#3C7AFF", -- 7
			"#5F6492", -- 8
		},
		{ -- Second Team (Red)
			"#FF1005", -- 1
			"#FF6107", -- 2
			"#FFD200", -- 3
			"#FF6058", -- 4
			"#FFBB7C", -- 5
			"#C88B2F", -- 6
			"#F5A200", -- 7
			"#9F0D05", -- 8
		},
		{ -- Third Team (Green)
			"#0CE818", -- 1
			"#B4FF39", -- 2
			"#097E1C", -- 3
			"#3EFFA2", -- 4
			"#689E3D", -- 5
			"#7EB900", -- 6
			"#B7EA63", -- 7
			"#37713A", -- 8
		},
	},

	{ -- Four Teams
		{ -- First Team (Blue)
			"#004DFF", -- 1
			"#7CA1FF", -- 2
			"#D8EEFF", -- 3
			"#09F5F5", -- 4
			"#3475FF", -- 5
			"#0B849B", -- 6
		},
		{ -- Second Team (Red)
			"#FF1005", -- 1
			"#FF6107", -- 2
			"#FF6058", -- 3
			"#B04523", -- 4
			"#F80889", -- 5
			"#971C48", -- 6
		},
		{ -- Third Team (Green)
			"#0CE818", -- 1
			"#B4FF39", -- 2
			"#097E1C", -- 3
			"#3EFFA2", -- 4
			"#689E3D", -- 5
			"#7EB900", -- 6
		},
		{ -- Fourth Team (Yellow)
			"#FFD200", -- 1
			"#F5A200", -- 2
			"#FCEEA4", -- 3
			"#FFBB7C", -- 4
			"#BBA28B", -- 5
			"#C88B2F", -- 6
		},
	},

	{ -- Five Teams
		{ -- First Team (Blue)
			"#004DFF", -- 1
			"#7CA1FF", -- 2
			"#D8EEFF", -- 3
			"#09F5F5", -- 4
			"#3475FF", -- 5
		},
		{ -- Second Team (Red)
			"#FF1005", -- 1
			"#FF6107", -- 2
			"#FF6058", -- 3
			"#B04523", -- 4
			"#9F0D05", -- 5
		},
		{ -- Third Team (Green)
			"#0CE818", -- 1
			"#B4FF39", -- 2
			"#097E1C", -- 3
			"#3EFFA2", -- 4
			"#689E3D", -- 5
		},
		{ -- Fourth Team (Yellow)
			"#FFD200", -- 1
			"#F5A200", -- 2
			"#FCEEA4", -- 3
			"#FFBB7C", -- 4
			"#C88B2F", -- 5
		},
		{ -- Fifth Team (Fuchsia)
			"#F80889", -- 1
			"#FF68EA", -- 2
			"#FFAAF3", -- 3
			"#AA0092", -- 4
			"#701162", -- 5
		},
	},

	{ -- Six Teams
		{ -- First Team (Blue)
			"#004DFF", -- 1
			"#7CA1FF", -- 2
			"#D8EEFF", -- 3
			"#2C32AC", -- 4
		},
		{ -- Second Team (Red)
			"#FF1005", -- 1
			"#FF6058", -- 2
			"#B04523", -- 3
			"#9F0D05", -- 4
		},
		{ -- Third Team (Green)
			"#0CE818", -- 1
			"#B4FF39", -- 2
			"#097E1C", -- 3
			"#3EFFA2", -- 4
		},
		{ -- Fourth Team (Yellow)
			"#FFD200", -- 1
			"#F5A200", -- 2
			"#FCEEA4", -- 3
			"#9B6408", -- 4
		},
		{ -- Fifth Team (Fuchsia)
			"#F80889", -- 1
			"#FF68EA", -- 2
			"#FFAAF3", -- 3
			"#971C48", -- 4
		},
		{ -- Sixth Team (Orange)
			"#FF6107", -- 1
			"#FFBB7C", -- 2
			"#DD783F", -- 3
			"#773A01", -- 4
		},
	},

	{ -- Seven Teams
		{ -- First Team (Blue)
			"#004DFF", -- 1
			"#7CA1FF", -- 2
			"#2C32AC", -- 3
		},
		{ -- Second Team (Red)
			"#FF1005", -- 1
			"#FF6058", -- 2
			"#9F0D05", -- 3
		},
		{ -- Third Team (Green)
			"#0CE818", -- 1
			"#B4FF39", -- 2
			"#097E1C", -- 3
		},
		{ -- Fourth Team (Yellow)
			"#FFD200", -- 1
			"#F5A200", -- 2
			"#FCEEA4", -- 3
		},
		{ -- Fifth Team (Fuchsia)
			"#F80889", -- 1
			"#FF68EA", -- 2
			"#FFAAF3", -- 3
		},
		{ -- Sixth Team (Orange)
			"#FF6107", -- 1
			"#FFBB7C", -- 2
			"#DD783F", -- 3
		},
		{ -- Seventh Team (Cyan)
			"#09F5F5", -- 1
			"#0B849B", -- 2
			"#D8EEFF", -- 3
		},
	},

	{ -- Eight Teams
		{ -- First Team (Blue)
			"#004DFF", -- 1
			"#7CA1FF", -- 2
			"#2C32AC", -- 3
		},
		{ -- Second Team (Red)
			"#FF1005", -- 1
			"#FF6058", -- 2
			"#9F0D05", -- 3
		},
		{ -- Third Team (Green)
			"#0CE818", -- 1
			"#B4FF39", -- 2
			"#097E1C", -- 3
		},
		{ -- Fourth Team (Yellow)
			"#FFD200", -- 1
			"#F5A200", -- 2
			"#FCEEA4", -- 3
		},
		{ -- Fifth Team (Fuchsia)
			"#F80889", -- 1
			"#FF68EA", -- 2
			"#971C48", -- 3
		},
		{ -- Sixth Team (Orange)
			"#FF6107", -- 1
			"#FFBB7C", -- 2
			"#DD783F", -- 3
		},
		{ -- Seventh Team (Cyan)
			"#09F5F5", -- 1
			"#0B849B", -- 2
			"#D8EEFF", -- 3
		},
		{ -- Eigth Team (Purple)
			"#872DFA", -- 1
			"#6809A1", -- 2
			"#C4A9FF", -- 3
		},
	},
}

local r = math.random(1,100000)
math.randomseed(1)	-- make sure the next sequence of randoms can be reproduced
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
local useFFAColors = Spring.Utilities.Gametype.IsFFA() and not Spring.Utilities.Gametype.IsTeams()
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
	elseif localRun and
		(Spring.GetConfigInt("SimpleTeamColors", 0) == 1 or (anonymousMode == "allred" and not mySpecState))
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
			brightnessVariation = brightnessVariation * math.min((#Spring.GetTeamList(allyTeamID) * 0.8)-1, 1)	-- dont change brightness too much in tiny teams
			maxColorVariation = 60
		end
		local color = hex2RGB(ffaColors[allyTeamID+1] or '#333333')
		if teamID == gaiaTeamID then
			brightnessVariation = 0
			maxColorVariation = 0
			color = hex2RGB(gaiaGrayColor)
		elseif teamID == myTeamID then
			brightnessVariation = 0
			maxColorVariation = 0
			color = {Spring.GetConfigInt("SimpleTeamColorsPlayerR", 0), Spring.GetConfigInt("SimpleTeamColorsPlayerG", 77), Spring.GetConfigInt("SimpleTeamColorsPlayerB", 255)}
		elseif allyTeamID == myAllyTeamID then
			color = {Spring.GetConfigInt("SimpleTeamColorsAllyR", 0), Spring.GetConfigInt("SimpleTeamColorsAllyG", 255), Spring.GetConfigInt("SimpleTeamColorsAllyB", 0)}
		elseif allyTeamID ~= myAllyTeamID then
			color = {Spring.GetConfigInt("SimpleTeamColorsEnemyR", 255), Spring.GetConfigInt("SimpleTeamColorsEnemyG", 16), Spring.GetConfigInt("SimpleTeamColorsEnemyB", 5)}
		end
		color[1] = math.min(color[1] + brightnessVariation, 255) + ((teamRandoms[teamID][1] * (maxColorVariation * 2)) - maxColorVariation)
		color[2] = math.min(color[2] + brightnessVariation, 255) + ((teamRandoms[teamID][2] * (maxColorVariation * 2)) - maxColorVariation)
		color[3] = math.min(color[3] + brightnessVariation, 255) + ((teamRandoms[teamID][3] * (maxColorVariation * 2)) - maxColorVariation)
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

	elseif isSurvival and survivalColors[#Spring.GetTeamList()-2] then
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
	elseif useFFAColors or
		(#Spring.GetTeamList(allyTeamCount-1) > 1 and (not teamColors[allyTeamCount] or not teamColors[allyTeamCount][1][#Spring.GetTeamList(allyTeamCount-1)]))
		or #Spring.GetTeamList() > 30
		or (#Spring.GetTeamList(allyTeamCount-1) == 1 and not ffaColors[allyTeamCount])
	then
		local color = hex2RGB(ffaColors[allyTeamID+1] or '#333333')
		local maxIterations =  1 + math.floor((#teamList-1) / #ffaColors)
		local brightnessVariation = (0.7 - ((1 / #Spring.GetTeamList(allyTeamID)) * dimmingCount[allyTeamID])) * 255
		brightnessVariation = brightnessVariation * math.min((#Spring.GetTeamList(allyTeamID) * 0.8)-1, 1)	-- dont change brightness too much in tiny teams
		local maxColorVariation = (120 / math.max(1, allyTeamCount-1))
		if maxIterations > 1 then
			local iteration = 1 + math.floor((allyTeamID+1)/(#ffaColors))
			local ffaColor = (allyTeamID+1) - (#ffaColors*(iteration-1)) + 1
			if iteration ~= 1 then
				color = hex2RGB(ffaColors[ffaColor])
			end
			if iteration == 1 then
				color[1] = math.min(color[1] + 40, 255)
				color[2] = math.min(color[2] + 40, 255)
				color[3] = math.min(color[3] + 40, 255)
			elseif iteration == 2 then
				color[1] = math.max(color[1] - 70, 0)
				color[2] = math.max(color[2] - 70, 0)
				color[3] = math.max(color[3] - 70, 0)
			elseif iteration == 3 then
				color[1] = math.min(color[1] + 130, 255)
				color[2] = math.min(color[2] + 130, 255)
				color[3] = math.min(color[3] + 130, 255)
			end
		end
		if teamID == gaiaTeamID then
			brightnessVariation = 0
			maxColorVariation = 0
			color = hex2RGB(gaiaGrayColor)
		end
		color[1] = math.min(color[1] + brightnessVariation, 255) + ((teamRandoms[teamID][1] * (maxColorVariation * 2)) - maxColorVariation)
		color[2] = math.min(color[2] + brightnessVariation, 255) + ((teamRandoms[teamID][2] * (maxColorVariation * 2)) - maxColorVariation)
		color[3] = math.min(color[3] + brightnessVariation, 255) + ((teamRandoms[teamID][3] * (maxColorVariation * 2)) - maxColorVariation)
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

		if teamColors[allyTeamCount] -- If we have the color set for this number of teams
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


if gadgetHandler:IsSyncedCode() then	--- NOTE: STUFF DONE IN SYNCED IS FOR REPLAY WEBSITE

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


else	-- UNSYNCED

	local myPlayerID = Spring.GetLocalPlayerID()
	local mySpecState = Spring.GetSpectatingState()

	if anonymousMode == "local" then
		shuffleAllColors()
	end
	if anonymousMode == "local" or Spring.GetConfigInt("SimpleTeamColors", 0) == 1 then
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
			discoShuffle(Spring.GetMyTeamID())
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
		end
	end

	function gadget:PlayerChanged(playerID)
		if playerID ~= myPlayerID then
			return
		end
		myAllyTeamID = Spring.GetMyAllyTeamID()
		local prevMyTeamID = myTeamID
		myTeamID = Spring.GetMyTeamID()
		if mySpecState and prevMyTeamID ~= myTeamID and Spring.GetConfigInt("SimpleTeamColors", 0) == 1 then
			Spring.SetConfigInt("UpdateTeamColors", 1)
  		end
		if mySpecState ~= Spring.GetSpectatingState() then
			mySpecState = Spring.GetSpectatingState()
			teamColorsTable = table.copy(trueTeamColorsTable)
			ffaColors = table.copy(trueFfaColors)
			survivalColors = table.copy(trueSurvivalColors)
			Spring.SetConfigInt("UpdateTeamColors", 1)
		end
	end
end
