function gadget:GetInfo()
	return {
		name = "AutoColorPicker",
		desc = "Automatically assigns colors to teams",
		author = "Damgam",
		date = "2021",
		layer = -100,
		enabled = false,
	}
end

if gadgetHandler:IsSyncedCode() then
    return
end

local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamList = Spring.GetTeamList
local spGetAllyTeamList= Spring.GetAllyTeamList
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spSetTeamColor = Spring.SetTeamColor
local spGetTeamLuaAI = Spring.GetTeamLuaAI
local spGetGaiaTeamID = Spring.GetGaiaTeamID

local myPlayerID = Spring.GetMyPlayerID()

local ffaCounter = 0
local allyCounter = 0
local enemyCounter1 = 0

SimplePlayerColor = {0, 80, 255} -- Armada Blue
SimpleAllyColor = {0,255,0} -- Full Green
SimpleEnemyColor = {255, 16, 5} -- Cortex Red

SingleTeamFFAColors = {
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

TwoTeamAllyColors = {
    [1] = {82,      151,    255 },      -- Blue
    [2] = {10,      232,    18  },      -- Green
    [3] = {94,      9,      178 },      -- Purple
    [4] = {47,      66,     238 },      -- Darker Blue
    [5] = {191,     169,    255 },      -- Lavender
    [6] = {0,       170,    99  },      -- Grass
    [7] = {178,     255,    227 },      -- Aqua
    [8] = {8,       37,     190 },      -- Dark Blue
}

TwoTeamEnemyColors = {
    [1] = {255,     0,      0   },      -- Red
    [2] = {255,     232,    22  },      -- Yellow
    [3] = {255,     125,    32  },      -- Orange
    [4] = {229,     18,     120 },      -- Pink
    [5] = {255,     243,    135 },      -- Bleached Yellow
    [6] = {166,     14,     5   },      -- Blood
    [7] = {251,     167,    120 },      -- Skin? lol
    [8] = {118,     39,     6   },      -- Brown
}

ScavColor = {97, 36, 97}
ChickenColor = {255, 0, 0}
GaiaColor = {127, 127, 127}

local function MissingColorHandler(teamID)
    spSetTeamColor(teamID, math.random(0,255)/255, math.random(0,255)/255, math.random(0,255)/255)
    Spring.Echo("Missing Team Color for TeamID: ".. teamID)
end


local function UpdatePlayerColors()
    local teams = spGetTeamList()
    local allyteams = spGetAllyTeamList()
    local myTeam = spGetMyTeamID()
    local myAllyTeam = spGetMyAllyTeamID()
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
        --elseif teamID == myTeam then
            --spSetTeamColor(teamID, PlayerColor[1]/255, PlayerColor[2]/255, PlayerColor[3]/255)
        else
            if #teams == #allyteams then -- FFA
                ffaCounter = ffaCounter+1
                if SingleTeamFFAColors[ffaCounter] then
                    spSetTeamColor(teamID, SingleTeamFFAColors[ffaCounter][1] /255, SingleTeamFFAColors[ffaCounter][2] /255, SingleTeamFFAColors[ffaCounter][3] /255)
                else
                    MissingColorHandler(teamID)
                end
            elseif #allyteams == 3 then
                if allyTeam == myAllyTeam then
                    allyCounter = allyCounter+1
                    if TwoTeamAllyColors[allyCounter] then
                        spSetTeamColor(teamID, TwoTeamAllyColors[allyCounter][1] /255, TwoTeamAllyColors[allyCounter][2] /255, TwoTeamAllyColors[allyCounter][3] /255)
                    else
                        MissingColorHandler(teamID)
                    end
                else
                    enemyCounter1 = enemyCounter1+1
                    if TwoTeamEnemyColors[enemyCounter1] then
                        spSetTeamColor(teamID, TwoTeamEnemyColors[enemyCounter1][1] /255, TwoTeamEnemyColors[enemyCounter1][2] /255, TwoTeamEnemyColors[enemyCounter1][3] /255)
                    else
                        MissingColorHandler(teamID)
                    end
                end
            end
        end
    end
    ffaCounter = 0
    allyCounter = 0
    enemyCounter1 = 0
end

function gadget:Initialize()
    UpdatePlayerColors()
end

function gadget:PlayerChanged(playerID)
    if playerID == myPlayerID then
        UpdatePlayerColors()
    end
end




