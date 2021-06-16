if gadgetHandler:IsSyncedCode() then
    return
end

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

local ffaCounter = 0
local allyCounter = 0
local enemyCounter = 0
local simpleColorsUpdateCounter = 0

SimpleColorsEnabled = Spring.GetConfigInt("simple_auto_colors", 0) -- Floris plz add option here
AnonymousModeEnabled = false -- needs modoption

SimplePlayerColor = {0, 80, 255} -- Armada Blue
SimpleAllyColor = {0,255,0} -- Full Green
SimpleEnemyColor = {255, 16, 5} -- Cortex Red

-- FFA
FFAColors = {
    [1] = {82,      151,    255 },      -- Blue
    [2] = {255,     0,      0   },      -- Red
    [3] = {10,      232,    18  },      -- Green
    [4] = {255,     232,    22  },      -- Yellow
    [5] = {94,      9,      178 },      -- Purple
    [6] = {255,     125,    32  },      -- Orange
    [7] = {47,      66,     238 },      -- Darker Blue
    [8] = {229,     18,     120 },      -- Pink
    [9] = {191,     169,    255 },      -- Lavender
    [10] ={255,     243,    135 },      -- Bleached Yellow
    [11] ={0,       170,    99  },      -- Grass
    [12] ={166,     14,     5   },      -- Blood
    [13] ={178,     255,    227 },      -- Aqua
    [14] ={251,     167,    120 },      -- Skin? lol
    [15] ={8,       37,     190 },      -- Dark Blue
    [16] ={118,     39,     6   },      -- Brown
}


AllyColors = {
    [2] = { -- Two Teams
        [1] = {0,       80,     255 },      -- Armada Blue
        [2] = {10,      232,    18  },      -- Green
        [3] = {94,      9,      178 },      -- Purple
        [4] = {82,      151,    255 },      -- Darker Blue
        [5] = {191,     169,    255 },      -- Lavender
        [6] = {0,       170,    99  },      -- Grass
        [7] = {178,     255,    227 },      -- Aqua
        [8] = {8,       37,     190 },      -- Dark Blue
    },
    [3] = { -- Three Teams
        [1] = {82,      151,    255  },
        [2] = {47,      66,     238  },
        [3] = {147,     226,    251  },
        [4] = {8,       37,     190  },
        [5] = {35,      11,     129  },
    },
    [4] = { -- Four Teams
        [1] = {82,      151,    255  },
        [2] = {47,      66,     238  },
        [3] = {147,     226,    251  },
        [4] = {8,       37,     190  },
    },
    [5] = { -- Five Teams
        [1] = {82,      151,    255  },
        [2] = {47,      66,     238  },
        [3] = {147,     226,    251  },
    },
}

EnemyColors = {
    [2] = { -- Two Teams
        [1] = {
            [1] = {255,     16,     5   },      -- Cortex Red
            [2] = {255,     232,    22  },      -- Yellow
            [3] = {255,     125,    32  },      -- Orange
            [4] = {229,     18,     120 },      -- Pink
            [5] = {255,     243,    135 },      -- Bleached Yellow
            [6] = {166,     14,     5   },      -- Blood
            [7] = {251,     167,    120 },      -- Skin? lol
            [8] = {118,     39,     6   },      -- Brown
        },
    },
    [3] = { -- Three Teams
        [1] = { -- First Enemy Team
            [1] = {231,     0,      0   },
            [2] = {255,     125,    32  },
            [3] = {255,     232,    22  },
            [4] = {166,     14,     5   },
            [5] = {118,     39,     6   },
        },
        [2] = { -- Second Enemy Team
            [1] = {10,      232,    32  },
            [2] = {10,      142,    7   },
            [3] = {117,     253,    147 },
            [4] = {5,       84,     13  },
            [5] = {45,      57,     9   },
        },
    },
    [4] = { -- Four Teams
        [1] = { -- First Enemy Team
            [1] = {231,     0,      0   },
            [2] = {255,     125,    32  },
            [3] = {255,     232,    22  },
            [4] = {166,     14,     5   },
        },
        [2] = { -- Second Enemy Team
            [1] = {10,      232,    32  },
            [2] = {10,      142,    7   },
            [3] = {117,     253,    147 },
            [4] = {5,       84,     13  },
        },
        [3] = { -- Third Enemy Team
            [1] = {200,     102,    246 },
            [2] = {134,     10,     232 },
            [3] = {191,     169,    255 },
            [4] = {94,      9,      178 },
        },
    },
    [5] = { -- Four Teams
        [1] = { -- First Enemy Team
            [1] = {231,     0,      0   },
            [2] = {255,     125,    32  },
            [3] = {166,     14,     5   },
        },
        [2] = { -- Second Enemy Team
            [1] = {10,      232,    32  },
            [2] = {10,      142,    7   },
            [3] = {117,     253,    147 },
        },
        [3] = { -- Third Enemy Team
            [1] = {200,     102,    246 },
            [2] = {134,     10,     232 },
            [3] = {191,     169,    255 },
        },
        [4] = { -- Fourth Enemy Team
            [1] = {255,     232,    22  },
            [2] = {191,     151,    8   },
            [3] = {255,     243,    135 },
        },
    },
}

ScavColor = {97, 36, 97}
ChickenColor = {255, 0, 0}
GaiaColor = {127, 127, 127}

local function MissingColorHandler(teamID, allyTeam, myTeam, myAllyTeam)
    if teamID == myTeam then
        spSetTeamColor(teamID, SimplePlayerColor[1]/255, SimplePlayerColor[2]/255, SimplePlayerColor[3]/255)
    elseif allyTeam == myAllyTeam then
        spSetTeamColor(teamID, SimpleAllyColor[1]/255, SimpleAllyColor[2]/255, SimpleAllyColor[3]/255)
    else
        spSetTeamColor(teamID, SimpleEnemyColor[1]/255, SimpleEnemyColor[2]/255, SimpleEnemyColor[3]/255)
    end
    Spring.Echo("Missing Team Color for TeamID: ".. teamID)
end

local function EnemyColorHandler(teamID, allyTeam, allyTeamCount)
    local myTeam = spGetMyTeamID()
    local myAllyTeam = spGetMyAllyTeamID()
    --local spectator = spGetSpectatingState()
    if not EATeams[allyTeam] then
        EATeams[allyTeam] = true
        if EACountNumber then
            EACount[allyTeam] = EACountNumber + 1
            EACountNumber = EACountNumber + 1
        else
            EACount[allyTeam] = 1
            EACountNumber = 1
        end
        EATeamsCount[allyTeam] = 0
    end
    EATeamsCount[allyTeam] = EATeamsCount[allyTeam] + 1
    --Spring.Echo("allyTeamCount "..allyTeamCount)
    --Spring.Echo("EACount[allyTeam] "..EACount[allyTeam])
    --Spring.Echo("EATeams[allyTeam] "..EATeams[allyTeam])
    --Spring.Echo("EATeamsCount[allyTeam] "..EATeamsCount[allyTeam])
    if EnemyColors[allyTeamCount] then
        if EnemyColors[allyTeamCount][EACount[allyTeam]] then
            if EnemyColors[allyTeamCount][EACount[allyTeam]][EATeamsCount[allyTeam]] then
                spSetTeamColor(
                    teamID, 
                    EnemyColors[allyTeamCount][EACount[allyTeam]][EATeamsCount[allyTeam]][1] /255, 
                    EnemyColors[allyTeamCount][EACount[allyTeam]][EATeamsCount[allyTeam]][2] /255,
                    EnemyColors[allyTeamCount][EACount[allyTeam]][EATeamsCount[allyTeam]][3] /255
                )
            else
                MissingColorHandler(teamID, allyTeam, myTeam, myAllyTeam)
            end
        else
            MissingColorHandler(teamID, allyTeam, myTeam, myAllyTeam)
        end
    else
        MissingColorHandler(teamID, allyTeam, myTeam, myAllyTeam)
    end
    -- planned
end

local function UpdatePlayerColors()
    local teams = spGetTeamList()
    local allyteams = spGetAllyTeamList()
    local myTeam = spGetMyTeamID()
    local myAllyTeam = spGetMyAllyTeamID()
    local spectator = spGetSpectatingState()
    EATeams = {}
    EACount = {}
    EATeamsCount = {}
    for i = 1,#teams do
        local teamID = teams[i]
        local _, leader, isDead, isAiTeam, side, allyTeam, incomeMultiplier, customTeamKeys = spGetTeamInfo(teamID)
        local luaAI = spGetTeamLuaAI(teamID)
        if isAiTeam and (luaAI and (string.find(luaAI, "Scavenger") or string.find(luaAI, "Chicken"))) then
            if string.find(luaAI, "Scavenger") then
                spSetTeamColor(teamID, ScavColor[1]/255, ScavColor[2]/255, ScavColor[3]/255)
            elseif string.find(luaAI, "Chicken") then
                spSetTeamColor(teamID, ChickenColor[1]/255, ChickenColor[2]/255, ChickenColor[3]/255)
            end
        elseif spGetGaiaTeamID() == teamID then
            spSetTeamColor(teamID, GaiaColor[1]/255, GaiaColor[2]/255, GaiaColor[3]/255)
        else
            if SimpleColorsEnabled == 1 then -- SimpleColors
                if teamID == myTeam then
                    spSetTeamColor(teamID, SimplePlayerColor[1]/255, SimplePlayerColor[2]/255, SimplePlayerColor[3]/255)
                elseif allyTeam == myAllyTeam then
                    spSetTeamColor(teamID, SimpleAllyColor[1]/255, SimpleAllyColor[2]/255, SimpleAllyColor[3]/255)
                else
                    spSetTeamColor(teamID, SimpleEnemyColor[1]/255, SimpleEnemyColor[2]/255, SimpleEnemyColor[3]/255)
                end
            elseif (AnonymousModeEnabled and allyTeam ~= myAllyTeam) and (not spectator) then
                spSetTeamColor(teamID, SimpleEnemyColor[1]/255, SimpleEnemyColor[2]/255, SimpleEnemyColor[3]/255)
            elseif #teams == #allyteams then -- FFA
                ffaCounter = ffaCounter+1
                if AnonymousModeEnabled and teamID == myTeam and (not spectator) then
                    spSetTeamColor(teamID, SimplePlayerColor[1]/255, SimplePlayerColor[2]/255, SimplePlayerColor[3]/255)
                elseif FFAColors[ffaCounter] then
                    spSetTeamColor(teamID, FFAColors[ffaCounter][1] /255, FFAColors[ffaCounter][2] /255, FFAColors[ffaCounter][3] /255)
                else
                    MissingColorHandler(teamID, allyTeam, myTeam, myAllyTeam)
                end
            else
                if allyTeam == myAllyTeam then
                    allyCounter = allyCounter+1
                    if AllyColors[#allyteams-1] then
                        if AllyColors[#allyteams-1][allyCounter] then
                            spSetTeamColor(teamID, AllyColors[#allyteams-1][allyCounter][1] /255, AllyColors[#allyteams-1][allyCounter][2] /255, AllyColors[#allyteams-1][allyCounter][3] /255)
                        else
                            MissingColorHandler(teamID, allyTeam, myTeam, myAllyTeam)
                        end
                    else
                        MissingColorHandler(teamID, allyTeam, myTeam, myAllyTeam)
                    end
                else
                    EnemyColorHandler(teamID, allyTeam, #allyteams-1)
                end
            end
        end
    end
    ffaCounter = 0
    allyCounter = 0
    EATeams = nil
    EACount = nil
    EATeamsCount = nil
    EACountNumber = nil
end

function gadget:Initialize()
    UpdatePlayerColors()
end

function gadget:PlayerChanged(playerID)
    if playerID == myPlayerID then
        UpdatePlayerColors()
    end
end

function gadget:Update()
    simpleColorsUpdateCounter = simpleColorsUpdateCounter + spGetLastUpdateSeconds()
    if simpleColorsUpdateCounter > 1 then
        simpleColorsUpdateCounter = 0
        local PreviousSimpleColorsEnabled = SimpleColorsEnabled
        SimpleColorsEnabled = spGetConfigInt("simple_auto_colors", 0)
        if PreviousSimpleColorsEnabled ~= SimpleColorsEnabled then
            UpdatePlayerColors()
        end
    end
end




