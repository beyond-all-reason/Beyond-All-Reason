function gadget:GetInfo()
	return {
		name = "AutoColorPicker",
		desc = "Automatically assigns colors to teams",
		author = "Damgam",
		date = "2021",
		layer = -100,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
    
    local FFAColors = {
        [1] = {0,       80,     255 },    
        [2] = {255,     16,     5   },    
        [3] = {10,      232,    18  },  
        [4] = {255,     232,    22  }, 
        [5] = {147,     226,    251 },    
        [6] = {255,     125,    32  },  
        [7] = {41,      166,    176 },
        [8] = {229,     18,     120 }, 
        [9] = {191,     169,    255 },
        [10] ={255,     243,    135 }, 
        [11] ={0,       170,    99  },
        [12] ={72,      9,      24  },
        [13] ={117,     253,    147 }, 
        [14] ={251,     167,    120 },
        [15] ={39,      63,     84  },
        [16] ={118,     39,     6   },
        [17] ={127,     170,    255 },
        [18] ={165,     0,      0   },
        [19] ={0,       106,    127 },
        [20] ={130,     130,    0   },
        [21] ={40,      165,    0   },
        [22] ={171,     90,     0   },
        [23] ={0,       38,     117 },
        [24] ={165,     0,      138 },
    }

    local TeamColors = {
        
        [2] = { -- Two Teams
            [1] = { -- First Team Blue
                -- Blue
                [1] = {0,       80,     255 },  -- Armada Blue #0050ff
                [2] = {102,     150,    255 },  -- Lighter Blue #6696ff
                [3] = {179,     203,    255 },  -- Very Light Blue #b3cbff
                [4] = {0,       57,     179 },  -- Dark Blue #0039b3
                -- Green    
                [5] = {0,       255,    0   },  -- Normal Green #00ff00
                [6] = {102,     255,    102 },  -- Lighter Green #66ff66
                [7] = {179,     255,    179 },  -- Very Light Green #b3ffb3
                [8] = {0,       153,    0   },  -- Dark Green #009900
                -- Aqua 
                [9] = {0,       255,    255 },  -- Normal Aqua #00ffff
                [10]= {128,     255,    255 },  -- Lighter Aqua #80ffff
                [11]= {179,     255,    255 },  -- Very Light Aqua #b3ffff
                [12]= {0,       153,    153 },  -- Dark Aqua #009999
                -- Purple (can't go full spectrum because of Scavengers)
                [13]= {153,     102,    255 },  -- Lighter Purple #9966ff
                [14]= {204,     179,    255 },  -- Very Light Purple #ccb3ff
            },  
            [2] = { -- Second Team Red  
                -- Red  
                [1] = {255,     16,     5   },  -- Cortex Red #ff0f06
                [2] = {255,     107,    102 },  -- Lighter Red #ff6b66
                [3] = {255,     181,    179 },  -- Very Light Red #ffb5b3
                [4] = {153,     5,      0   },  -- Dark Red #990500
                -- Yellow   
                [5] = {255,     255,    0   },  -- Normal Yellow #ffff00
                [6] = {255,     255,    102 },  -- Lighter Yellow #ffff66
                [7] = {255,     255,    179 },  -- Very Light Yellow #ffffb3
                [8] = {204,     204,    0   },  -- Dark Yellow #cccc00
                -- Orange   
                [9] = {255,     153,    0   },  -- Normal Orange #ff9900
                [10]= {255,     184,    77  },  -- Lighter Orange #ffc266
                [11]= {255,     224,    179 },  -- Very Light Orange #ffe0b3
                [12]= {179,     107,    0   },  -- Dark Orange/Brown #b36b00
                -- Pink
                [13]= {255,     0,      128 },  -- Pink #ff0080
                [14]= {255,     102,    179 },  -- Lighter Pink #ff66b3
                [15]= {179,     0,      89  },  -- Dark Pink #b30059
            },
        },
        
        [3] = { -- Three Teams
            [1] = { -- First Team Blue
                [1] = {82,      151,    255  },
                [2] = {47,      66,     238  },
                [3] = {147,     226,    251  },
                [4] = {8,       37,     190  },
                [5] = {35,      11,     129  },
            },
            [2] = { -- Second Team Red
                [1] = {231,     0,      0   },
                [2] = {255,     125,    32  },
                [3] = {255,     232,    22  },
                [4] = {166,     14,     5   },
                [5] = {118,     39,     6   },
            },
            [3] = { -- Third Team Green
                [1] = {10,      232,    32  },
                [2] = {10,      142,    7   },
                [3] = {117,     253,    147 },
                [4] = {5,       84,     13  },
                [5] = {45,      57,     9   },
            },
        },

        [4] = { -- Four Teams
            [1] = { -- First Team Blue
                [1] = {82,      151,    255  },
                [2] = {47,      66,     238  },
                [3] = {147,     226,    251  },
                [4] = {8,       37,     190  },
            },
            [2] = { -- Second Team Red
                [1] = {231,     0,      0   },
                [2] = {255,     125,    32  },
                [3] = {255,     232,    22  },
                [4] = {166,     14,     5   },
            },
            [3] = { -- Third Team Green
                [1] = {10,      232,    32  },
                [2] = {10,      142,    7   },
                [3] = {117,     253,    147 },
                [4] = {5,       84,     13  },
            },
            [4] = { -- Fourth Team Purple
                [1] = {200,     102,    246 },
                [2] = {134,     10,     232 },
                [3] = {191,     169,    255 },
                [4] = {94,      9,      178 },
            },
        },

        [5] = { -- Five Teams
            [1] = { -- First Team Blue
                [1] = {82,      151,    255  },
                [2] = {47,      66,     238  },
                [3] = {147,     226,    251  },
            },
            [2] = { -- Second Team Red
                [1] = {231,     0,      0   },
                [2] = {255,     125,    32  },
                [3] = {166,     14,     5   },
            },
            [3] = { -- Third Team Green
                [1] = {10,      232,    32  },
                [2] = {10,      142,    7   },
                [3] = {117,     253,    147 },
            },
            [4] = { -- Fourth Team Purple
                [1] = {200,     102,    246 },
                [2] = {134,     10,     232 },
                [3] = {191,     169,    255 },
            },
            [5] = { -- Fifth Team Yellow
                [1] = {255,     232,    22  },
                [2] = {191,     151,    8   },
                [3] = {255,     243,    135 },
            },
        },

        [6] = { -- Six Teams
            [1] = { -- First Team Blue
                [1] = {82,      151,    255  },
                [2] = {47,      66,     238  },
            },
            [2] = { -- Second Team Red
                [1] = {231,     0,      0   },
                [2] = {166,     14,     5   },
            },
            [3] = { -- Third Team Green
                [1] = {10,      232,    32  },
                [2] = {10,      142,    7   },
            },
            [4] = { -- Fourth Team Purple
                [1] = {200,     102,    246 },
                [2] = {134,     10,     232 },
            },
            [5] = { -- Fifth Team Yellow 
                [1] = {255,     232,    22  },
                [2] = {191,     151,    8   },
            },
            [6] = { -- Sixth team Orange
                [1] = {255,     161,    73  },
                [2] = {222,     93,     0   },
            },
        },
    }

    local OldFFAColors = {
        [1] = {0,       80,     255 },    
        [2] = {255,     16,     5   },    
        [3] = {10,      232,    18  },  
        [4] = {255,     232,    22  }, 
        [5] = {147,     226,    251 },    
        [6] = {255,     125,    32  },  
        [7] = {41,      166,    176 },
        [8] = {229,     18,     120 }, 
        [9] = {191,     169,    255 },
        [10] ={255,     243,    135 }, 
        [11] ={0,       170,    99  },
        [12] ={72,      9,      24  },
        [13] ={117,     253,    147 }, 
        [14] ={251,     167,    120 },
        [15] ={39,      63,     84  },
        [16] ={118,     39,     6   },
        [17] ={127,     170,    255 },
        [18] ={165,     0,      0   },
        [19] ={0,       106,    127 },
        [20] ={130,     130,    0   },
        [21] ={40,      165,    0   },
        [22] ={171,     90,     0   },
        [23] ={0,       38,     117 },
        [24] ={165,     0,      138 },
    }

    local OldTeamColors = {
        
        [2] = { -- Two Teams
            [1] = { -- First Team Blue
                [1] = {0,       80,     255 },    
                [2] = {10,      232,    18  },    
                [3] = {147,     226,    251 },     
                [4] = {41,      166,    176 },     
                [5] = {191,     169,    255 },     
                [6] = {0,       170,    99  },    
                [7] = {117,     253,    147 },    
                [8] = {39,      63,     84  },   
                [9] = {127,     170,    255 },
                [10] = {0,      106,    127 },
                [11] = {40,     165,    0   },
                [12] = {0,      38,     117 },
            },
            [2] = { -- Second Team Red
                [1] = {255,     16,     5   },
                [2] = {255,     232,    22  },
                [3] = {255,     125,    32  },
                [4] = {229,     18,     120 },
                [5] = {255,     243,    135 },
                [6] = {72,      9,      24  },
                [7] = {251,     167,    120 },
                [8] = {118,     39,     6   },
                [9] = {165,     0,      0   },
                [10] = {130,    130,    0   },
                [11] = {171,    90,     0   },
                [12] = {165,    0,      138 },
            },
        },
        
        [3] = { -- Three Teams
            [1] = { -- First Team Blue
                [1] = {82,      151,    255  },
                [2] = {47,      66,     238  },
                [3] = {147,     226,    251  },
                [4] = {8,       37,     190  },
                [5] = {35,      11,     129  },
            },
            [2] = { -- Second Team Red
                [1] = {231,     0,      0   },
                [2] = {255,     125,    32  },
                [3] = {255,     232,    22  },
                [4] = {166,     14,     5   },
                [5] = {118,     39,     6   },
            },
            [3] = { -- Third Team Green
                [1] = {10,      232,    32  },
                [2] = {10,      142,    7   },
                [3] = {117,     253,    147 },
                [4] = {5,       84,     13  },
                [5] = {45,      57,     9   },
            },
        },

        [4] = { -- Four Teams
            [1] = { -- First Team Blue
                [1] = {82,      151,    255  },
                [2] = {47,      66,     238  },
                [3] = {147,     226,    251  },
                [4] = {8,       37,     190  },
            },
            [2] = { -- Second Team Red
                [1] = {231,     0,      0   },
                [2] = {255,     125,    32  },
                [3] = {255,     232,    22  },
                [4] = {166,     14,     5   },
            },
            [3] = { -- Third Team Green
                [1] = {10,      232,    32  },
                [2] = {10,      142,    7   },
                [3] = {117,     253,    147 },
                [4] = {5,       84,     13  },
            },
            [4] = { -- Fourth Team Purple
                [1] = {200,     102,    246 },
                [2] = {134,     10,     232 },
                [3] = {191,     169,    255 },
                [4] = {94,      9,      178 },
            },
        },

        [5] = { -- Five Teams
            [1] = { -- First Team Blue
                [1] = {82,      151,    255  },
                [2] = {47,      66,     238  },
                [3] = {147,     226,    251  },
            },
            [2] = { -- Second Team Red
                [1] = {231,     0,      0   },
                [2] = {255,     125,    32  },
                [3] = {166,     14,     5   },
            },
            [3] = { -- Third Team Green
                [1] = {10,      232,    32  },
                [2] = {10,      142,    7   },
                [3] = {117,     253,    147 },
            },
            [4] = { -- Fourth Team Purple
                [1] = {200,     102,    246 },
                [2] = {134,     10,     232 },
                [3] = {191,     169,    255 },
            },
            [5] = { -- Fifth Team Yellow
                [1] = {255,     232,    22  },
                [2] = {191,     151,    8   },
                [3] = {255,     243,    135 },
            },
        },

        [6] = { -- Six Teams
            [1] = { -- First Team Blue
                [1] = {82,      151,    255  },
                [2] = {47,      66,     238  },
            },
            [2] = { -- Second Team Red
                [1] = {231,     0,      0   },
                [2] = {166,     14,     5   },
            },
            [3] = { -- Third Team Green
                [1] = {10,      232,    32  },
                [2] = {10,      142,    7   },
            },
            [4] = { -- Fourth Team Purple
                [1] = {200,     102,    246 },
                [2] = {134,     10,     232 },
            },
            [5] = { -- Fifth Team Yellow 
                [1] = {255,     232,    22  },
                [2] = {191,     151,    8   },
            },
            [6] = { -- Sixth team Orange
                [1] = {255,     161,    73  },
                [2] = {222,     93,     0   },
            },
        },
    }

    local ScavColor = {97, 36, 97}
    local GaiaColor = {127, 127, 127}
        
    local RandomizedFFAColors = {}
    local RandomizedTeamColors = {}

    local teamList = Spring.GetTeamList()
    local allyTeamList = Spring.GetAllyTeamList()
    local teamNumber = #teamList-1
    local allyTeamNumber = #allyTeamList - 1

    if #teamList == #allyTeamList and teamNumber > 2 then
        isFFA = true
    end

    local ffaCounts = 1
    local ffaLoop = 1
    local allyTeamCounts = 0
    local TeamCounts = {}

    Sequential = false
    -- GenerateRandomizedTeamColorTables
    if Sequential == true then
        RandomizedFFAColors = FFAColors
        RandomizedTeamColors = TeamColors
    else
        while #FFAColors > 0 do
            pickSuccess = false
            while pickSuccess == false do
                for i = 1,#FFAColors do
                    if #FFAColors == 1 or math.random(1,#FFAColors) == 1 then
                        table.insert(RandomizedFFAColors, FFAColors[i])
                        table.remove(FFAColors, i)
                        pickSuccess = true
                        break
                    end
                end
            end
        end

        if TeamColors[allyTeamNumber] then
            for a = 1,#TeamColors[allyTeamNumber] do
                while #TeamColors[allyTeamNumber][a] > 0 do
                    if not RandomizedTeamColors[allyTeamNumber] then
                        RandomizedTeamColors[allyTeamNumber] = {}
                    end
                    if not RandomizedTeamColors[allyTeamNumber][a] then
                        RandomizedTeamColors[allyTeamNumber][a] = {}
                    end
                    pickSuccess = false
                    while pickSuccess == false do
                        for i = 1,#TeamColors[allyTeamNumber][a] do
                            if #TeamColors[allyTeamNumber][a] == 1 or math.random(1,#TeamColors[allyTeamNumber][a]) == 1 then
                                table.insert(RandomizedTeamColors[allyTeamNumber][a], TeamColors[allyTeamNumber][a][i])
                                table.remove(TeamColors[allyTeamNumber][a], i)
                                pickSuccess = true
                                break
                            end
                        end
                    end
                end
            end
        else
            isFFA = true
        end
    end

    local function SetUpTeamColor(teamID, allyTeamID, isAI)
        if isAI and string.find(isAI, "Scavenger") then
            Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", ScavColor[1])
            Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", ScavColor[2])
            Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", ScavColor[3])
        elseif teamID == Spring.GetGaiaTeamID() then
            Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", GaiaColor[1])
            Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", GaiaColor[2])
            Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", GaiaColor[3])
        elseif isFFA then
            if RandomizedFFAColors[ffaCounts] then
                Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", RandomizedFFAColors[ffaCounts][1]+math.random(-ffaLoop,ffaLoop))
                Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", RandomizedFFAColors[ffaCounts][2]+math.random(-ffaLoop,ffaLoop))
                Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", RandomizedFFAColors[ffaCounts][3]+math.random(-ffaLoop,ffaLoop))
                ffaCounts = ffaCounts + 1
            else
                ffaCounts = 1
                ffaLoop = ffaLoop + 15
                if RandomizedFFAColors[ffaCounts] then
                    Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", RandomizedFFAColors[ffaCounts][1]+math.random(-ffaLoop,ffaLoop))
                    Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", RandomizedFFAColors[ffaCounts][2]+math.random(-ffaLoop,ffaLoop))
                    Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", RandomizedFFAColors[ffaCounts][3]+math.random(-ffaLoop,ffaLoop))
                    ffaCounts = ffaCounts + 1
                else
                    Spring.Echo("[AUTOCOLORS] Error: Missing FFA Colors")
                    Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", 255)
                    Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", 255)
                    Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", 255)
                end
            end
        
        
        else
            if not TeamCounts[allyTeamID] then
                allyTeamCounts = allyTeamCounts + 1
                TeamCounts[allyTeamID] = {allyTeamCounts,1, 1}
            end
            if RandomizedTeamColors[allyTeamNumber] then
                if RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]] then
                    if RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]][TeamCounts[allyTeamID][2]] then
                        Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]][TeamCounts[allyTeamID][2]][1]+math.random(-TeamCounts[allyTeamID][3],TeamCounts[allyTeamID][3]))
                        Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]][TeamCounts[allyTeamID][2]][2]+math.random(-TeamCounts[allyTeamID][3],TeamCounts[allyTeamID][3]))
                        Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]][TeamCounts[allyTeamID][2]][3]+math.random(-TeamCounts[allyTeamID][3],TeamCounts[allyTeamID][3]))
                        TeamCounts[allyTeamID][2] = TeamCounts[allyTeamID][2] + 1
                    else
                        TeamCounts[allyTeamID][2] = 1
                        TeamCounts[allyTeamID][3] = TeamCounts[allyTeamID][3] + 50
                        if RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]][TeamCounts[allyTeamID][2]] then
                            Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]][TeamCounts[allyTeamID][2]][1]+math.random(-TeamCounts[allyTeamID][3],TeamCounts[allyTeamID][3]))
                            Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]][TeamCounts[allyTeamID][2]][2]+math.random(-TeamCounts[allyTeamID][3],TeamCounts[allyTeamID][3]))
                            Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]][TeamCounts[allyTeamID][2]][3]+math.random(-TeamCounts[allyTeamID][3],TeamCounts[allyTeamID][3]))
                            TeamCounts[allyTeamID][2] = TeamCounts[allyTeamID][2] + 1
                        else
                            Spring.Echo("[AUTOCOLORS] Error: Missing Team Colors")
                            Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", 255)
                            Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", 255)
                            Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", 255)
                        end
                    end
                end
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
        SetUpTeamColor(teamID, allyTeamID, isAI)
    end
    return
end


local GaiaColor = {127, 127, 127}

local AnonymousModeEnabledModoption = Spring.GetModOptions().teamcolors_anonymous_mode
if AnonymousModeEnabledModoption then
    AnonymousModeEnabled = true
else
    AnonymousModeEnabled = false
end

local IconDevModeEnabledModoption = Spring.GetModOptions().teamcolors_icon_dev_mode
if IconDevModeEnabledModoption == 'disabled' then
    IconDevModeEnabled = false
else
    if IconDevModeEnabledModoption == "armblue" then
        IconDevModeColor = {0, 80, 255}
    elseif IconDevModeEnabledModoption == "corred" then
        IconDevModeColor = {255, 16, 5}
    elseif IconDevModeEnabledModoption == "scavpurp" then
        IconDevModeColor = {97, 36, 97}
    elseif IconDevModeEnabledModoption == "chickenorange" then
        IconDevModeColor = {255, 125, 32}
    elseif IconDevModeEnabledModoption == "gaiagray" then
        IconDevModeColor = {127, 127, 127}
    end
    IconDevModeEnabled = true
end

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



local function UpdateTeamColors()
    local myTeamID = spGetMyTeamID()
    local myAllyTeamID = spGetMyAllyTeamID()
    for i = 1,#teamList do
        local teamID = teamList[i]
        local r = Spring.GetTeamRulesParam(teamID, "AutoTeamColorRed")/255
        local g = Spring.GetTeamRulesParam(teamID, "AutoTeamColorGreen")/255
        local b = Spring.GetTeamRulesParam(teamID, "AutoTeamColorBlue")/255
        
        if iconDevModeEnabled then
            spSetTeamColor(teamID, IconDevModeColor[1]/255, IconDevModeColor[2]/255, IconDevModeColor[3]/255)
        elseif AnonymousModeEnabled then
            local _, leader, isDead, isAiTeam, side, allyTeamID, incomeMultiplier, customTeamKeys = spGetTeamInfo(teamID)
            if allyTeamID == myAllyTeamID or spGetSpectatingState() then
                spSetTeamColor(teamID, r, g, b)
            else
                spSetTeamColor(teamID, GaiaColor[1]/255, GaiaColor[2]/255, GaiaColor[3]/255)
            end
        else
            spSetTeamColor(teamID, r, g, b)
        end
    end
end

UpdateTeamColors()

function gadget:Update()
    if math.random(0,60) == 0 then
        UpdateTeamColors()
    end
end