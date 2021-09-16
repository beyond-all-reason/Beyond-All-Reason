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
        [20] ={185,     185,    0   },
        [21] ={40,      165,    0   },
        [22] ={171,     90,     0   },
        [23] ={0,       59,     178 },
        [24] ={165,     0,      138 },
    }

    local TeamColors = {
        
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
                [12] = {0,      59,     178 },
            },
            [2] = { -- Second Team Red
                [1] = {255,     16,     5   },      -- Cortex Red
                [2] = {255,     232,    22  },      -- Yellow
                [3] = {255,     125,    32  },      -- Orange
                [4] = {229,     18,     120 },      -- Pink
                [5] = {255,     243,    135 },      -- Bleached Yellow
                [6] = {72,      9,      24  },      -- Blood
                [7] = {251,     167,    120 },      -- Skin? lol
                [8] = {118,     39,     6   },      -- Brown
                [9] = {165,     0,      0   },
                [10] = {185,    185,    0   },
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

    if #teamList == #allyTeamList then -- FFA
        isFFA = true
    end

    local ffaCounts = 1
    local allyTeamCounts = 0
    local TeamCounts = {}


    -- GenerateRandomizedTeamColorTables
    while #FFAColors > 0 do
        pickSuccess = false
        while pickSuccess == false do
            for i = 1,#FFAColors do
                if #FFAColors == 1 or math.random(1,#FFAColors) == 1 then
                    table.insert(RandomizedFFAColors, FFAColors[i])
                    --RandomizedFFAColors[#RandomizedFFAColors+1] = FFAColors[i]
                    table.remove(FFAColors, i)
                    pickSuccess = true
                    break
                end
            end
        end
    end

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
                        --RandomizedTeamColors[a][#RandomizedTeamColors+1] = TeamColors[a][i]
                        table.remove(TeamColors[allyTeamNumber][a], i)
                        pickSuccess = true
                        break
                    end
                end
            end
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
                Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", RandomizedFFAColors[ffaCounts][1])
                Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", RandomizedFFAColors[ffaCounts][2])
                Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", RandomizedFFAColors[ffaCounts][3])
                ffaCounts = ffaCounts + 1
            else
                ffaCounts = 1
                if RandomizedFFAColors[ffaCounts] then
                    Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", RandomizedFFAColors[ffaCounts][1])
                    Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", RandomizedFFAColors[ffaCounts][2])
                    Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", RandomizedFFAColors[ffaCounts][3])
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
                TeamCounts[allyTeamID] = {allyTeamCounts,1}
            end
            if RandomizedTeamColors[allyTeamNumber] then
                if RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]] then
                    if RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]][TeamCounts[allyTeamID][2]] then
                        Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]][TeamCounts[allyTeamID][2]][1])
                        Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]][TeamCounts[allyTeamID][2]][2])
                        Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]][TeamCounts[allyTeamID][2]][3])
                        TeamCounts[allyTeamID][2] = TeamCounts[allyTeamID][2] + 1
                    else
                        TeamCounts[allyTeamID][2] = 1
                        if RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]][TeamCounts[allyTeamID][2]] then
                            Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]][TeamCounts[allyTeamID][2]][1])
                            Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]][TeamCounts[allyTeamID][2]][2])
                            Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", RandomizedTeamColors[allyTeamNumber][TeamCounts[allyTeamID][1]][TeamCounts[allyTeamID][2]][3])
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

































-- local ffaCounter = 0
-- local allyCounter = 0
-- local enemyCounter = 0
-- local simpleColorsUpdateCounter = 0

-- SimpleColorsEnabled = Spring.GetConfigInt("simple_auto_colors", 0) -- Floris plz add option here
-- local DynamicTeamColorsEnabledModoption = Spring.GetModOptions().teamcolors_dynamic
-- if DynamicTeamColorsEnabledModoption then
--     DynamicTeamColorsEnabled = true
-- else
--     DynamicTeamColorsEnabled = false
-- end
-- local AnonymousModeEnabledModoption = Spring.GetModOptions().teamcolors_anonymous_mode
-- if AnonymousModeEnabledModoption then
--     AnonymousModeEnabled = true
-- else
--     AnonymousModeEnabled = false
-- end

-- SimplePlayerColor = {0, 80, 255} -- Armada Blue
-- SimpleAllyColor = {0,255,0} -- Full Green
-- SimpleEnemyColor = {255, 16, 5} -- Cortex Red


-- local function MissingColorHandler(teamID, allyTeam, myTeam, myAllyTeam, allyTeamCount)
--     --local myTeam = spGetMyTeamID()
--     --local myAllyTeam = spGetMyAllyTeamID()
--     -- if teamID == myTeam then
--     --     spSetTeamColor(teamID, SimplePlayerColor[1]/255, SimplePlayerColor[2]/255, SimplePlayerColor[3]/255)
--     if allyTeam == myAllyTeam then -- elseif allyTeam == myAllyTeam then
--         allyCounter = 1
--         if AllyColors[allyTeamCount] then
--             if AllyColors[allyTeamCount][allyCounter] then
--                 spSetTeamColor(
--                     teamID, 
--                     AllyColors[allyTeamCount][allyCounter][1]/255, 
--                     AllyColors[allyTeamCount][allyCounter][2]/255, 
--                     AllyColors[allyTeamCount][allyCounter][3]/255
--                 )
--             else
--                 spSetTeamColor(teamID, 255, 255, 255)
--             end
--         else
--             spSetTeamColor(teamID, 255, 255, 255)
--         end
--     else
--         EATeamsCount[allyTeam] = 1
--         if EnemyColors[allyTeamCount] then
--             if EnemyColors[allyTeamCount][EACount[allyTeam]] then
--                 if EnemyColors[allyTeamCount][EACount[allyTeam]][EATeamsCount[allyTeam]] then
--                     spSetTeamColor(
--                         teamID, 
--                         EnemyColors[allyTeamCount][EACount[allyTeam]][EATeamsCount[allyTeam]][1]/255, 
--                         EnemyColors[allyTeamCount][EACount[allyTeam]][EATeamsCount[allyTeam]][2]/255,
--                         EnemyColors[allyTeamCount][EACount[allyTeam]][EATeamsCount[allyTeam]][3]/255
--                     )
--                 else
--                     spSetTeamColor(teamID, 255, 255, 255)
--                 end
--             else
--                 spSetTeamColor(teamID, 255, 255, 255)
--             end
--         else
--             spSetTeamColor(teamID, 255, 255, 255)
--         end
--     end
-- end

-- local function SimpleColorHandler(teamID, allyTeam)
--     local myTeam = spGetMyTeamID()
--     local myAllyTeam = spGetMyAllyTeamID()
--     if teamID == myTeam then
--         spSetTeamColor(teamID, SimplePlayerColor[1]/255, SimplePlayerColor[2]/255, SimplePlayerColor[3]/255)
--     elseif allyTeam == myAllyTeam then
--         spSetTeamColor(teamID, SimpleAllyColor[1]/255, SimpleAllyColor[2]/255, SimpleAllyColor[3]/255)
--     else
--         spSetTeamColor(teamID, SimpleEnemyColor[1]/255, SimpleEnemyColor[2]/255, SimpleEnemyColor[3]/255)
--     end
-- end

-- local function EnemyColorHandler(teamID, allyTeam, allyTeamCount, myTeam, myAllyTeam)
--     if not EATeams[allyTeam] then
--         EATeams[allyTeam] = true
--         if EACountNumber then
--             EACount[allyTeam] = EACountNumber + 1
--             EACountNumber = EACountNumber + 1
--         else
--             EACount[allyTeam] = 1
--             EACountNumber = 1
--         end
--         EATeamsCount[allyTeam] = 0
--     end
--     EATeamsCount[allyTeam] = EATeamsCount[allyTeam] + 1
--     --Spring.Echo("allyTeamCount "..allyTeamCount)
--     --Spring.Echo("EACount[allyTeam] "..EACount[allyTeam])
--     --Spring.Echo("EATeams[allyTeam] "..EATeams[allyTeam])
--     --Spring.Echo("EATeamsCount[allyTeam] "..EATeamsCount[allyTeam])
--     if EnemyColors[allyTeamCount] then
--         if EnemyColors[allyTeamCount][EACount[allyTeam]] then
--             if EnemyColors[allyTeamCount][EACount[allyTeam]][EATeamsCount[allyTeam]] then
--                 spSetTeamColor(
--                     teamID, 
--                     EnemyColors[allyTeamCount][EACount[allyTeam]][EATeamsCount[allyTeam]][1] /255, 
--                     EnemyColors[allyTeamCount][EACount[allyTeam]][EATeamsCount[allyTeam]][2] /255,
--                     EnemyColors[allyTeamCount][EACount[allyTeam]][EATeamsCount[allyTeam]][3] /255
--                 )
--             else
--                 MissingColorHandler(teamID, allyTeam, myTeam, myAllyTeam, allyTeamCount)
--             end
--         else
--             MissingColorHandler(teamID, allyTeam, myTeam, myAllyTeam, allyTeamCount)
--         end
--     else
--         MissingColorHandler(teamID, allyTeam, myTeam, myAllyTeam, allyTeamCount)
--     end
--     -- planned
-- end

-- local function UpdatePlayerColors()
--     local teams = spGetTeamList()
--     local allyteams = spGetAllyTeamList()
--     local myTeam = spGetMyTeamID()
--     local myAllyTeam = spGetMyAllyTeamID()
--     local spectator = spGetSpectatingState()
--     EATeams = {}
--     EACount = {}
--     EATeamsCount = {}
--     for i = 1,#teams do
--         local teamID = teams[i]
--         local _, leader, isDead, isAiTeam, side, allyTeam, incomeMultiplier, customTeamKeys = spGetTeamInfo(teamID)
--         local luaAI = spGetTeamLuaAI(teamID)
--         if isAiTeam and (luaAI and (string.find(luaAI, "Scavenger"))) then
--             if string.find(luaAI, "Scavenger") then
--                 spSetTeamColor(teamID, ScavColor[1]/255, ScavColor[2]/255, ScavColor[3]/255)
--             end
--         elseif spGetGaiaTeamID() == teamID then
--             spSetTeamColor(teamID, GaiaColor[1]/255, GaiaColor[2]/255, GaiaColor[3]/255)
--         else
--             if SimpleColorsEnabled == 1 then -- SimpleColors
--                 SimpleColorHandler(teamID, allyTeam)
--             elseif (AnonymousModeEnabled and allyTeam ~= myAllyTeam) and (not spectator) then
--                 spSetTeamColor(teamID, SimpleEnemyColor[1]/255, SimpleEnemyColor[2]/255, SimpleEnemyColor[3]/255)
--             elseif #teams == #allyteams then -- FFA
--                 ffaCounter = ffaCounter+1
--                 if AnonymousModeEnabled and teamID == myTeam and (not spectator) then
--                     spSetTeamColor(teamID, SimplePlayerColor[1]/255, SimplePlayerColor[2]/255, SimplePlayerColor[3]/255)
--                 elseif FFAColors[ffaCounter] then
--                     spSetTeamColor(teamID, FFAColors[ffaCounter][1] /255, FFAColors[ffaCounter][2] /255, FFAColors[ffaCounter][3] /255)
--                 else
--                     ffaCounter = 1
--                     spSetTeamColor(teamID, FFAColors[ffaCounter][1] /255, FFAColors[ffaCounter][2] /255, FFAColors[ffaCounter][3] /255)
--                 end
--             else
--                 if spectator or (not AnonymousModeEnabled and (not DynamicTeamColorsEnabled)) then
--                     myTeam = 0
--                     myAllyTeam = 0
--                 end
--                 if allyTeam == myAllyTeam then
--                     allyCounter = allyCounter+1
--                     if AllyColors[#allyteams-1] then
--                         if AllyColors[#allyteams-1][allyCounter] then
--                             spSetTeamColor(teamID, AllyColors[#allyteams-1][allyCounter][1] /255, AllyColors[#allyteams-1][allyCounter][2] /255, AllyColors[#allyteams-1][allyCounter][3] /255)
--                         else
--                             MissingColorHandler(teamID, allyTeam, myTeam, myAllyTeam, #allyteams-1)
--                         end
--                     else
--                         MissingColorHandler(teamID, allyTeam, myTeam, myAllyTeam, #allyteams-1)
--                     end
--                 else
--                     EnemyColorHandler(teamID, allyTeam, #allyteams-1, myTeam, myAllyTeam)
--                 end
--             end
--         end
--         if IconDevModeEnabled == true then
--             spSetTeamColor(teamID, IconDevModeColor[1] /255, IconDevModeColor[2] /255, IconDevModeColor[3] /255)
--         end
--     end
--     myTeam = nil
--     myAllyTeam = nil
--     ffaCounter = 0
--     allyCounter = 0
--     EATeams = nil
--     EACount = nil
--     EATeamsCount = nil
--     EACountNumber = nil
-- end

-- function gadget:Initialize()
--     UpdatePlayerColors()
-- end

-- function gadget:PlayerChanged(playerID)
--     if playerID == myPlayerID then
--         UpdatePlayerColors()
--     end
-- end

-- function gadget:Update()
--     simpleColorsUpdateCounter = simpleColorsUpdateCounter + spGetLastUpdateSeconds()
--     if simpleColorsUpdateCounter > 1 then
--         simpleColorsUpdateCounter = 0
--         local PreviousSimpleColorsEnabled = SimpleColorsEnabled
--         SimpleColorsEnabled = spGetConfigInt("simple_auto_colors", 0)
--         if PreviousSimpleColorsEnabled ~= SimpleColorsEnabled then
--             UpdatePlayerColors()
--         end
--     end

--     if math.random(0,60) == 0 then
--         UpdatePlayerColors()
--     end
-- end




