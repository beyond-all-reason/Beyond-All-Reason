function gadget:GetInfo()
	return {
		name = "AutoColorPicker",
		desc = "Automatically assigns colors to teams",
		author = "Damgam, Born2Crawl (color palette)",
		date = "2021",
		layer = -100,
		enabled = true,
	}
end

local function hex2RGB(hex)
    hex = hex:gsub("#","")
    return {tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))}
end

-- Special colors
local armBlueColor       = "#004DFF" -- Armada Blue
local corRedColor        = "#FF1005" -- Cortex Red
local scavPurpColor      = "#612461" -- Scav Purple
local chickenOrangeColor = "#CC8914" -- Chicken Orange
local gaiaGrayColor      = "#7F7F7F" -- Gaia Grey

if gadgetHandler:IsSyncedCode() then
	local ffaColors = {
		"#004DFF", -- Armada Blue
		"#FF1005", -- Cortex Red
		"#0CE818", -- Green
		"#FFD70D", -- Yellow
		"#FF00DB", -- Fuchsia
		"#0CC4E8", -- Turquoise
		"#FF6B00", -- Orange
		"#86FFD1", -- Light Turquoise Green
		"#F6BB56", -- Light Brown
		"#68B900", -- Dark Lime
		"#6697FF", -- Very Light Blue
		"#FF6058", -- Light Red
		"#8DF492", -- Light Green
		"#FFF2AE", -- Very Light Yellow
		"#FFAAF3", -- Very Light Fuchsia
		"#90E5F5", -- Light Turquoise
		"#FF9055", -- Light Orange
		"#00AA69", -- Dark Turquoise Green
		"#9B6408", -- Dark Brown
		"#C4FF79", -- Light Lime
		"#3475FF", -- Light Blue
		"#AD0800", -- Dark Red
		"#089B10", -- Dark Green
		"#FFE874", -- Light Yellow
		"#FF68EA", -- Light Fuchsia
		"#08839B", -- Dark Turquoise
		"#FFC8AA", -- Very Light Orange
		"#00FF9E", -- Turquoise Green
		"#DB8E0E", -- Brown
		"#9FFF25", -- Lime
	}

	local survivalColors = {
		"#004DFF", -- Armada Blue
		"#FF1005", -- Cortex Red
		"#0CE818", -- Green
		-- "#FFD70D", -- Yellow
		"#FF00DB", -- Fuchsia
		"#0CC4E8", -- Turquoise
		--"#FF6B00", -- Orange
		"#86FFD1", -- Light Turquoise Green
		-- "#F6BB56", -- Light Brown
		"#68B900", -- Dark Lime
		"#6697FF", -- Very Light Blue
		"#FF6058", -- Light Red
		"#8DF492", -- Light Green
		-- "#FFF2AE", -- Very Light Yellow
		"#FFAAF3", -- Very Light Fuchsia
		"#90E5F5", -- Light Turquoise
		--"#FF9055", -- Light Orange
		"#00AA69", -- Dark Turquoise Green
		"#9B6408", -- Dark Brown
		-- "#C4FF79", -- Light Lime
		"#3475FF", -- Light Blue
		"#AD0800", -- Dark Red
		"#089B10", -- Dark Green
		-- "#FFE874", -- Light Yellow
		"#FF68EA", -- Light Fuchsia
		"#08839B", -- Dark Turquoise
		-- "#FFC8AA", -- Very Light Orange
		"#00FF9E", -- Turquoise Green
		"#DB8E0E", -- Brown
		"#9FFF25", -- Lime
	}

	local teamColors = {
		{ -- One Team (not possible)
			{ -- First Team
				"#004DFF", -- Armada Blue
			},
		},

		{ -- Two Teams
			{ -- First Team (Cool)
				"#004DFF", -- Armada Blue
				"#0CE818", -- Green
				"#0CC4E8", -- Turquoise
				"#86FFD1", -- Light Turquoise Green
				"#68B900", -- Dark Lime
				"#6697FF", -- Very Light Blue
				"#8DF492", -- Light Green
				"#90E5F5", -- Light Turquoise
				"#00AA69", -- Dark Turquoise Green
				"#C4FF79", -- Light Lime
				"#3475FF", -- Light Blue
				"#089B10", -- Dark Green
				"#08839B", -- Dark Turquoise
				"#00FF9E", -- Turquoise Green
				"#9FFF25", -- Lime
			},
			{ -- Second Team (Warm)
				"#FF1005", -- Cortex Red
				"#FFD70D", -- Yellow
				"#FF00DB", -- Fuchsia
				"#FF6B00", -- Orange
				"#F6BB56", -- Light Brown
				"#FF6058", -- Light Red
				"#FFF2AE", -- Very Light Yellow
				"#FFAAF3", -- Very Light Fuchsia
				"#FF9055", -- Light Orange
				"#9B6408", -- Dark Brown
				"#AD0800", -- Dark Red
				"#FFE874", -- Light Yellow
				"#FF68EA", -- Light Fuchsia
				"#FFC8AA", -- Very Light Orange
				"#DB8E0E", -- Brown
			},
		},

		{ -- Three Teams
			{ -- First Team (Blue)
				"#004DFF", -- Armada Blue
				"#0CC4E8", -- Turquoise
				"#6697FF", -- Very Light Blue
				"#90E5F5", -- Light Turquoise
				"#3475FF", -- Light Blue
				"#08839B", -- Dark Turquoise
			},
			{ -- Second Team (Red)
				"#FF1005", -- Cortex Red
				"#FFD70D", -- Yellow
				"#FF6B00", -- Orange
				"#FF6058", -- Light Red
				"#9B6408", -- Dark Brown
				"#FFF2AE", -- Very Light Yellow
			},
			{ -- Third Team (Green)
				"#0CE818", -- Green
				"#86FFD1", -- Light Turquoise Green
				"#68B900", -- Dark Lime
				"#8DF492", -- Light Green
				"#00AA69", -- Dark Turquoise Green
				"#089B10", -- Dark Green
			},
		},

		{ -- Four Teams
			{ -- First Team (Blue)
				"#004DFF", -- Armada Blue
				"#0CC4E8", -- Turquoise
				"#6697FF", -- Very Light Blue
				"#90E5F5", -- Light Turquoise
				"#3475FF", -- Light Blue
				"#08839B", -- Dark Turquoise
			},
			{ -- Second Team (Red)
				"#FF1005", -- Cortex Red
				"#FF6B00", -- Orange
				"#FF6058", -- Light Red
				"#FF9055", -- Light Orange
				"#AD0800", -- Dark Red
				"#FFC8AA", -- Very Light Orange
			},
			{ -- Third Team (Green)
				"#0CE818", -- Green
				"#86FFD1", -- Light Turquoise Green
				"#68B900", -- Dark Lime
				"#8DF492", -- Light Green
				"#00AA69", -- Dark Turquoise Green
				"#089B10", -- Dark Green
			},
			{ -- Fourth Team (Yellow)
				"#FFD70D", -- Yellow
				"#F6BB56", -- Light Brown
				"#FFE874", -- Light Yellow
				"#9B6408", -- Dark Brown
				"#FFF2AE", -- Very Light Yellow
				"#DB8E0E", -- Brown
			},
		},

		{ -- Five Teams
			{ -- First Team (Blue)
				"#004DFF", -- Armada Blue
				"#0CC4E8", -- Turquoise
				"#6697FF", -- Very Light Blue
				"#90E5F5", -- Light Turquoise
				"#3475FF", -- Light Blue
			},
			{ -- Second Team (Red)
				"#FF1005", -- Cortex Red
				"#FF6B00", -- Orange
				"#FF6058", -- Light Red
				"#FF9055", -- Light Orange
				"#AD0800", -- Dark Red
			},
			{ -- Third Team (Green)
				"#0CE818", -- Green
				"#86FFD1", -- Light Turquoise Green
				"#68B900", -- Dark Lime
				"#8DF492", -- Light Green
				"#00AA69", -- Dark Turquoise Green
			},
			{ -- Fourth Team (Yellow)
				"#FFD70D", -- Yellow
				"#F6BB56", -- Light Brown
				"#FFE874", -- Light Yellow
				"#9B6408", -- Dark Brown
				"#FFF2AE", -- Very Light Yellow
			},
			{ -- Fifth Team (Fuchsia)
				"#FF00DB", -- Fuchsia
				"#FF68EA", -- Light Fuchsia
				"#FFAAF3", -- Very Light Fuchsia
				"#AA0092", -- Dark Fuchsia
				"#650057", -- Very Dark Fuchsia
			},
		},

		{ -- Six Teams
			{ -- First Team (Blue)
				"#004DFF", -- Armada Blue
				"#0CC4E8", -- Turquoise
				"#6697FF", -- Very Light Blue
				"#90E5F5", -- Light Turquoise
			},
			{ -- Second Team (Red)
				"#FF1005", -- Cortex Red
				"#FF6058", -- Light Red
				"#FFAFAC", -- Very Light Red
				"#AD0800", -- Dark Red
			},
			{ -- Third Team (Green)
				"#0CE818", -- Green
				"#86FFD1", -- Light Turquoise Green
				"#68B900", -- Dark Lime
				"#8DF492", -- Light Green
			},
			{ -- Fourth Team (Yellow)
				"#FFD70D", -- Yellow
				"#F6BB56", -- Light Brown
				"#FFE874", -- Light Yellow
				"#9B6408", -- Dark Brown
			},
			{ -- Fifth Team (Fuchsia)
				"#FF00DB", -- Fuchsia
				"#FF68EA", -- Light Fuchsia
				"#FFAAF3", -- Very Light Fuchsia
				"#AA0092", -- Dark Fuchsia
			},
			{ -- Sixth Team (Orange)
				"#FF6B00", -- Orange
				"#FF9055", -- Light Orange
				"#FFC8AA", -- Very Light Orange
				"#AA4B00", -- Dark Orange
			},
		},
	}

	local gaiaTeamID = Spring.GetGaiaTeamID()
	local teamList = Spring.GetTeamList()
	local allyTeamList = Spring.GetAllyTeamList()
	local teamCount = #teamList - 1
	local allyTeamCount = #allyTeamList - 1

	local isFFA = false
	if #teamList == #allyTeamList and teamCount > 2 then
		isFFA = true
	elseif not teamColors[allyTeamCount] then
		isFFA = true
	end
	local isSurvival = Spring.Utilities.Gametype.IsScavengers() or Spring.Utilities.Gametype.IsChickens()

	local survivalColorNum = 1 -- Starting from color #1
	local survivalColorVariation = 0 -- Current color variation
	local ffaColorNum = 1 -- Starting from color #1
	local ffaColorVariation = 0 -- Current color variation
	local colorVariationDelta = 128 -- Delta for color variation
	local allyTeamNum = 0
	local teamSizes = {}

	local function setUpTeamColor(teamID, allyTeamID, isAI)
		if isAI and string.find(isAI, "Scavenger") then
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", hex2RGB(scavPurpColor)[1])
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", hex2RGB(scavPurpColor)[2])
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", hex2RGB(scavPurpColor)[3])
		elseif isAI and string.find(isAI, "Chicken") then
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", hex2RGB(chickenOrangeColor)[1])
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", hex2RGB(chickenOrangeColor)[2])
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", hex2RGB(chickenOrangeColor)[3])
		elseif teamID == gaiaTeamID then
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", hex2RGB(gaiaGrayColor)[1])
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", hex2RGB(gaiaGrayColor)[2])
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", hex2RGB(gaiaGrayColor)[3])
		elseif isSurvival then
			if not survivalColors[survivalColorNum] then -- If we have no color for this team anymore
				survivalColorNum = 1 -- Starting from the first color again..
				survivalColorVariation = survivalColorVariation + colorVariationDelta -- ..but adding random color variations with increasing amplitude with every cycle
			end

			-- Assigning R,G,B values with specified color variations
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", hex2RGB(survivalColors[survivalColorNum])[1] + math.random(-survivalColorVariation, survivalColorVariation))
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", hex2RGB(survivalColors[survivalColorNum])[2] + math.random(-survivalColorVariation, survivalColorVariation))
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", hex2RGB(survivalColors[survivalColorNum])[3] + math.random(-survivalColorVariation, survivalColorVariation))
			survivalColorNum = survivalColorNum + 1 -- Will start from the next color next time
		elseif isFFA then
			if not ffaColors[ffaColorNum] then -- If we have no color for this team anymore
				ffaColorNum = 1 -- Starting from the first color again..
				ffaColorVariation = ffaColorVariation + colorVariationDelta -- ..but adding random color variations with increasing amplitude with every cycle
			end

			-- Assigning R,G,B values with specified color variations
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", hex2RGB(ffaColors[ffaColorNum])[1] + math.random(-ffaColorVariation, ffaColorVariation))
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", hex2RGB(ffaColors[ffaColorNum])[2] + math.random(-ffaColorVariation, ffaColorVariation))
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", hex2RGB(ffaColors[ffaColorNum])[3] + math.random(-ffaColorVariation, ffaColorVariation))
			ffaColorNum = ffaColorNum + 1 -- Will start from the next color next time

		else
			if not teamSizes[allyTeamID] then
				allyTeamNum = allyTeamNum + 1
				teamSizes[allyTeamID] = {allyTeamNum, 1, 0} -- Team number, Starting color number, Color variation
			end
			if teamColors[allyTeamCount] -- If we have the color set for this number of teams
				and teamColors[allyTeamCount][teamSizes[allyTeamID][1]] then -- And this team number exists in the color set
				if not teamColors[allyTeamCount][teamSizes[allyTeamID][1]][teamSizes[allyTeamID][2]] then -- If we have no color for this player anymore
					teamSizes[allyTeamID][2] = 1 -- Starting from the first color again..
					teamSizes[allyTeamID][3] = teamSizes[allyTeamID][3] + colorVariationDelta -- ..but adding random color variations with increasing amplitude with every cycle
				end

				-- Assigning R,G,B values with specified color variations
				Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", hex2RGB(teamColors[allyTeamCount][teamSizes[allyTeamID][1]][teamSizes[allyTeamID][2]])[1] + math.random(-teamSizes[allyTeamID][3], teamSizes[allyTeamID][3]))
				Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", hex2RGB(teamColors[allyTeamCount][teamSizes[allyTeamID][1]][teamSizes[allyTeamID][2]])[2] + math.random(-teamSizes[allyTeamID][3], teamSizes[allyTeamID][3]))
				Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", hex2RGB(teamColors[allyTeamCount][teamSizes[allyTeamID][1]][teamSizes[allyTeamID][2]])[3] + math.random(-teamSizes[allyTeamID][3], teamSizes[allyTeamID][3]))
				teamSizes[allyTeamID][2] = teamSizes[allyTeamID][2] + 1 -- Will start from the next color next time
			else
				Spring.Echo("[AUTOCOLORS] Error: Team Colors Table is broken or missing for this allyteam set")
				Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", 255)
				Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", 255)
				Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", 255)
			end
		end
	end

	local AutoColors = {}
	for i = 1,#teamList do
		local teamID = teamList[i]
		local allyTeamID = select(6, Spring.GetTeamInfo(teamID))
		local isAI = Spring.GetTeamLuaAI(teamID)
		setUpTeamColor(teamID, allyTeamID, isAI)

		local r = Spring.GetTeamRulesParam(teamID, "AutoTeamColorRed")
		local g = Spring.GetTeamRulesParam(teamID, "AutoTeamColorGreen")
		local b = Spring.GetTeamRulesParam(teamID, "AutoTeamColorBlue")

		AutoColors[i] = {
			teamID = teamID,
			r = r,
			g = g,
			b = b,
		}
	end

	Spring.SendLuaRulesMsg("AutoColors", Json.encode(AutoColors))


else	-- UNSYNCED


	local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode

	local iconDevModeColors = {
		armblue       = armBlueColor,
		corred        = corRedColor,
		scavpurp      = scavPurpColor,
		chickenorange = chickenOrangeColor,
		gaiagray      = gaiaGrayColor,
	}
	local iconDevMode = Spring.GetModOptions().teamcolors_icon_dev_mode
	local iconDevModeColor = iconDevModeColors[iconDevMode]

	local gaiaTeamID = Spring.GetGaiaTeamID()
	local teamList = Spring.GetTeamList()

	local function updateTeamColors()
		local myTeamID = Spring.GetMyTeamID()
		local myAllyTeamID = Spring.GetMyAllyTeamID()
		for i = 1, #teamList do
			local teamID = teamList[i]
			local r = Spring.GetTeamRulesParam(teamID, "AutoTeamColorRed")/255
			local g = Spring.GetTeamRulesParam(teamID, "AutoTeamColorGreen")/255
			local b = Spring.GetTeamRulesParam(teamID, "AutoTeamColorBlue")/255

			if iconDevModeColor then
				Spring.SetTeamColor(teamID, hex2RGB(iconDevModeColor)[1]/255, hex2RGB(iconDevModeColor)[2]/255, hex2RGB(iconDevModeColor)[3]/255)
			elseif Spring.GetConfigInt("SimpleTeamColors", 0) == 1 or (anonymousMode and not Spring.GetSpectatingState()) then
				local allyTeamID = select(6, Spring.GetTeamInfo(teamID))
				if teamID == myTeamID then
					Spring.SetTeamColor(teamID,
						Spring.GetConfigInt("SimpleTeamColorsPlayerR", 0)/255,
						Spring.GetConfigInt("SimpleTeamColorsPlayerG", 77)/255,
						Spring.GetConfigInt("SimpleTeamColorsPlayerB", 255)/255)
				elseif allyTeamID == myAllyTeamID then
					Spring.SetTeamColor(teamID,
						Spring.GetConfigInt("SimpleTeamColorsAllyR", 0)/255,
						Spring.GetConfigInt("SimpleTeamColorsAllyG", 255)/255,
						Spring.GetConfigInt("SimpleTeamColorsAllyB", 0)/255)
				elseif allyTeamID ~= myAllyTeamID and teamID ~= gaiaTeamID then
					Spring.SetTeamColor(teamID,
						Spring.GetConfigInt("SimpleTeamColorsEnemyR", 255)/255,
						Spring.GetConfigInt("SimpleTeamColorsEnemyG", 16)/255,
						Spring.GetConfigInt("SimpleTeamColorsEnemyB", 5)/255)
				else
					Spring.SetTeamColor(teamID, hex2RGB(gaiaGrayColor)[1]/255, hex2RGB(gaiaGrayColor)[2]/255, hex2RGB(gaiaGrayColor)[3]/255)
				end
			else
				Spring.SetTeamColor(teamID, r, g, b)
			end
		end
	end
	updateTeamColors()

	function gadget:Update()
		if math.random(0,60) == 0 then
			updateTeamColors()
		elseif Spring.GetConfigInt("UpdateTeamColors", 0) == 1 then
			updateTeamColors()
			Spring.SetConfigInt("UpdateTeamColors", 0)
			Spring.SetConfigInt("SimpleTeamColors_Reset", 0)
		end
	end
end
