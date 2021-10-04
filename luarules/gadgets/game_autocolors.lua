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

if gadgetHandler:IsSyncedCode() then
    local ffaColors = {
        [1] =  "#004DFF", -- Armada Blue
        [2] =  "#FF1005", -- Cortex Red
        [3] =  "#0CE818", -- Green
        [4] =  "#FFD70D", -- Yellow
        [5] =  "#FF00DB", -- Fuchsia
        [6] =  "#0CC4E8", -- Turquoise
        [7] =  "#FF6B00", -- Orange
        [8] =  "#00FF9E", -- Turquoise Green
        [9] =  "#F6BB56", -- Light Brown
        [10] = "#68B900", -- Dark Lime
        [11] = "#6697FF", -- Very Light Blue
        [12] = "#FF6058", -- Light Red
        [13] = "#8DF492", -- Light Green
        [14] = "#FFF2AE", -- Very Light Yellow
        [15] = "#FFAAF3", -- Very Light Fuchsia
        [16] = "#90E5F5", -- Light Turquoise
        [17] = "#FF9055", -- Light Orange
        [18] = "#00AA69", -- Dark Turquoise Green
        [19] = "#9B6408", -- Dark Brown
        [20] = "#C4FF79", -- Light Lime
        [21] = "#3475FF", -- Light Blue
        [22] = "#AD0800", -- Dark Red
        [23] = "#089B10", -- Dark Green
        [24] = "#FFE874", -- Light Yellow
        [25] = "#FF68EA", -- Light Fuchsia
        [26] = "#08839B", -- Dark Turquoise
        [27] = "#FFC8AA", -- Very Light Orange
        [28] = "#86FFD1", -- Light Turquoise Green
        [29] = "#DB8E0E", -- Brown
        [30] = "#9FFF25", -- Lime
    }

    local teamColors = {
        [2] = { -- Two Teams
            [1] = { -- First Team (Cool)
                [1]  = "#004DFF", -- Armada Blue
                [2]  = "#0CE818", -- Green
                [3]  = "#0CC4E8", -- Turquoise
                [4]  = "#00FF9E", -- Turquoise Green
                [5]  = "#68B900", -- Dark Lime
                [6]  = "#6697FF", -- Very Light Blue
                [7]  = "#8DF492", -- Light Green
                [8]  = "#90E5F5", -- Light Turquoise
                [9]  = "#00AA69", -- Dark Turquoise Green
                [10] = "#C4FF79", -- Light Lime
                [11] = "#3475FF", -- Light Blue
                [12] = "#089B10", -- Dark Green
                [13] = "#08839B", -- Dark Turquoise
                [14] = "#86FFD1", -- Light Turquoise Green
                [15] = "#9FFF25", -- Lime
            },
            [2] = { -- Second Team (Warm)
                [1]  = "#FF1005", -- Cortex Red
                [2]  = "#FFD70D", -- Yellow
                [3]  = "#FF00DB", -- Fuchsia
                [4]  = "#FF6B00", -- Orange
                [5]  = "#F6BB56", -- Light Brown
                [6]  = "#FF6058", -- Light Red
                [7]  = "#FFF2AE", -- Very Light Yellow
                [8]  = "#FFAAF3", -- Very Light Fuchsia
                [9]  = "#FF9055", -- Light Orange
                [10] = "#9B6408", -- Dark Brown
                [11] = "#AD0800", -- Dark Red
                [12] = "#FFE874", -- Light Yellow
                [13] = "#FF68EA", -- Light Fuchsia
                [14] = "#FFC8AA", -- Very Light Orange
                [15] = "#DB8E0E", -- Brown
            },
        },
        
        [3] = { -- Three Teams
            [1] = { -- First Team (Blue)
                [1] = "#004DFF", -- Armada Blue
                [2] = "#0CC4E8", -- Turquoise
                [3] = "#6697FF", -- Very Light Blue
                [4] = "#90E5F5", -- Light Turquoise
                [5] = "#3475FF", -- Light Blue
                [6] = "#08839B", -- Dark Turquoise
            },
            [2] = { -- Second Team (Red)
                [1] = "#FF1005", -- Cortex Red
                [2] = "#FFD70D", -- Yellow
                [3] = "#FF6B00", -- Orange
                [4] = "#FF6058", -- Light Red
                [5] = "#9B6408", -- Dark Brown
                [6] = "#FFF2AE", -- Very Light Yellow
            },
            [3] = { -- Third Team (Green)
                [1] = "#0CE818", -- Green
                [2] = "#00FF9E", -- Turquoise Green
                [3] = "#68B900", -- Dark Lime
                [4] = "#089B10", -- Dark Green
                [5] = "#8DF492", -- Light Green
                [6] = "#C4FF79", -- Light Lime
            },
        },

        [4] = { -- Four Teams
            [1] = { -- First Team (Blue)
                [1] = "#004DFF", -- Armada Blue
                [2] = "#0CC4E8", -- Turquoise
                [3] = "#6697FF", -- Very Light Blue
                [4] = "#90E5F5", -- Light Turquoise
                [5] = "#3475FF", -- Light Blue
                [6] = "#08839B", -- Dark Turquoise
            },
            [2] = { -- Second Team (Red)
                [1] = "#FF1005", -- Cortex Red
                [2] = "#FF6B00", -- Orange
                [3] = "#FF6058", -- Light Red
                [4] = "#FF9055", -- Light Orange
                [5] = "#AD0800", -- Dark Red
                [6] = "#FFC8AA", -- Very Light Orange
            },
            [3] = { -- Third Team (Green)
                [1] = "#0CE818", -- Green
                [2] = "#00FF9E", -- Turquoise Green
                [3] = "#68B900", -- Dark Lime
                [4] = "#089B10", -- Dark Green
                [5] = "#8DF492", -- Light Green
                [6] = "#C4FF79", -- Light Lime
            },
            [4] = { -- Fourth Team (Yellow)
                [1] = "#FFD70D", -- Yellow
                [2] = "#F6BB56", -- Light Brown
                [3] = "#FFE874", -- Light Yellow
                [4] = "#9B6408", -- Dark Brown
                [5] = "#FFF2AE", -- Very Light Yellow
                [6] = "#DB8E0E", -- Brown
            },
        },

        [5] = { -- Five Teams
            [1] = { -- First Team (Blue)
                [1] = "#004DFF", -- Armada Blue
                [2] = "#0CC4E8", -- Turquoise
                [3] = "#6697FF", -- Very Light Blue
                [4] = "#90E5F5", -- Light Turquoise
                [5] = "#3475FF", -- Light Blue
            },
            [2] = { -- Second Team (Red)
                [1] = "#FF1005", -- Cortex Red
                [2] = "#FF6B00", -- Orange
                [3] = "#FF6058", -- Light Red
                [4] = "#FF9055", -- Light Orange
                [5] = "#AD0800", -- Dark Red
            },
            [3] = { -- Third Team (Green)
                [1] = "#0CE818", -- Green
                [2] = "#00FF9E", -- Turquoise Green
                [3] = "#68B900", -- Dark Lime
                [4] = "#089B10", -- Dark Green
                [5] = "#8DF492", -- Light Green
            },
            [4] = { -- Fourth Team (Yellow)
                [1] = "#FFD70D", -- Yellow
                [2] = "#F6BB56", -- Light Brown
                [3] = "#FFE874", -- Light Yellow
                [4] = "#9B6408", -- Dark Brown
                [5] = "#FFF2AE", -- Very Light Yellow
            },
            [5] = { -- Fifth Team (Fuchsia)
                [1] = "#FF00DB", -- Fuchsia
                [2] = "#FF68EA", -- Light Fuchsia
                [3] = "#FFAAF3", -- Very Light Fuchsia
                [4] = "#AA0092", -- Dark Fuchsia
                [5] = "#650057", -- Very Dark Fuchsia
            },
        },

        [6] = { -- Six Teams
            [1] = { -- First Team (Blue)
                [1] = "#004DFF", -- Armada Blue
                [2] = "#0CC4E8", -- Turquoise
                [3] = "#6697FF", -- Very Light Blue
                [4] = "#90E5F5", -- Light Turquoise
            },
            [2] = { -- Second Team (Red)
                [1] = "#FF1005", -- Cortex Red
                [2] = "#FF6058", -- Light Red
                [3] = "#FFAFAC", -- Very Light Red
                [4] = "#AD0800", -- Dark Red
            },
            [3] = { -- Third Team (Green)
                [1] = "#0CE818", -- Green
                [2] = "#00FF9E", -- Turquoise Green
                [3] = "#68B900", -- Dark Lime
                [4] = "#089B10", -- Dark Green
            },
            [4] = { -- Fourth Team (Yellow)
                [1] = "#FFD70D", -- Yellow
                [2] = "#F6BB56", -- Light Brown
                [3] = "#FFE874", -- Light Yellow
                [4] = "#9B6408", -- Dark Brown
            },
            [5] = { -- Fifth Team (Fuchsia)
                [1] = "#FF00DB", -- Fuchsia
                [2] = "#FF68EA", -- Light Fuchsia
                [3] = "#FFAAF3", -- Very Light Fuchsia
                [4] = "#AA0092", -- Dark Fuchsia
            },
            [6] = { -- Sixth Team (Orange)
                [1] = "#FF6B00", -- Orange
                [2] = "#FF9055", -- Light Orange
                [3] = "#FFC8AA", -- Very Light Orange
                [4] = "#AA4B00", -- Dark Orange
            },
        },
    }

    local scavColor = "#612461" -- Scav Purple
    local gaiaColor = "#7F7F7F" -- Gaia Grey

    local teamList = Spring.GetTeamList()
    local allyTeamList = Spring.GetAllyTeamList()
    local teamCount = #teamList - 1
    local allyTeamCount = #allyTeamList - 1

    if #teamList == #allyTeamList and teamCount > 2 then
        isFFA = true
    elseif not teamColors[allyTeamCount] then
        isFFA = true
    end

    local ffaColorNum = 1 -- Starting from color #1
    local ffaColorVariation = 0 -- Current color variation
    local colorVariationDelta = 128 -- Delta for color variation
    local allyTeamNum = 0
    local teamSizes = {}

    local function hex2RGB(hex)
        hex = hex:gsub("#","")
        return {tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))}
    end

    local function setUpTeamColor(teamID, allyTeamID, isAI)
        if isAI and string.find(isAI, "Scavenger") then
            Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", hex2RGB(scavColor)[1])
            Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", hex2RGB(scavColor)[2])
            Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", hex2RGB(scavColor)[3])
        elseif teamID == Spring.GetGaiaTeamID() then
            Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", hex2RGB(gaiaColor)[1])
            Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", hex2RGB(gaiaColor)[2])
            Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", hex2RGB(gaiaColor)[3])
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

    local spGetTeamInfo = Spring.GetTeamInfo
    local spGetTeamLuaAI = Spring.GetTeamLuaAI
    for i = 1,#teamList do
        local teamID = teamList[i]
        local _, leader, isDead, isAiTeam, side, allyTeamID, incomeMultiplier, customTeamKeys = spGetTeamInfo(teamID)
        local isAI = spGetTeamLuaAI(teamID)
        setUpTeamColor(teamID, allyTeamID, isAI)
    end
    return
end

local anonymousModeEnabledModoption = Spring.GetModOptions().teamcolors_anonymous_mode
local gaiaColor = "#7F7F7F" -- Gaia Grey

local iconDevModeEnabledModoption = Spring.GetModOptions().teamcolors_icon_dev_mode
local iconDevModeColors = {
  armblue       = "#004DFF", -- Armada Blue
  corred        = "#FF1005", -- Cortex Red
  scavpurp      = "#612461", -- Scav Purple
  chickenorange = "#FF7D20", -- Chicken Orange
  gaiagray      = "#7F7F7F", -- Gaia Grey
}
local iconDevModeColor = iconDevModeColors[iconDevModeEnabledModoption]

local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamList = Spring.GetTeamList
local spGetAllyTeamList= Spring.GetAllyTeamList
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spSetTeamColor = Spring.SetTeamColor
local spGetTeamLuaAI = Spring.GetTeamLuaAI
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetConfigInt = Spring.GetConfigInt
local spGetLastUpdateSeconds = Spring.GetLastUpdateSeconds

local myPlayerID = Spring.GetMyPlayerID()
local teamList = spGetTeamList()

local function updateTeamColors()
    local myTeamID = spGetMyTeamID()
    local myAllyTeamID = spGetMyAllyTeamID()
    for i = 1,#teamList do
        local teamID = teamList[i]
        local r = Spring.GetTeamRulesParam(teamID, "AutoTeamColorRed")/255
        local g = Spring.GetTeamRulesParam(teamID, "AutoTeamColorGreen")/255
        local b = Spring.GetTeamRulesParam(teamID, "AutoTeamColorBlue")/255
        
        if iconDevModeColor then
            spSetTeamColor(teamID, hex2RGB(iconDevModeColor)[1]/255, hex2RGB(iconDevModeColor)[2]/255, hex2RGB(iconDevModeColor)[3]/255)
        elseif anonymousModeEnabledModoption then
            local _, leader, isDead, isAiTeam, side, allyTeamID, incomeMultiplier, customTeamKeys = spGetTeamInfo(teamID)
            if allyTeamID == myAllyTeamID or spGetSpectatingState() then
                spSetTeamColor(teamID, r, g, b)
            else
                spSetTeamColor(teamID, hex2RGB(gaiaColor)[1]/255, hex2RGB(gaiaColor)[2]/255, hex2RGB(gaiaColor)[3]/255)
            end
        else
            spSetTeamColor(teamID, r, g, b)
        end
    end
end

updateTeamColors()

function gadget:Update()
    if math.random(0,60) == 0 then
        updateTeamColors()
    end
end
