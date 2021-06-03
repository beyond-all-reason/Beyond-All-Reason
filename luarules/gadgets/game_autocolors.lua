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
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spSetTeamColor = Spring.SetTeamColor
local spGetTeamLuaAI = Spring.GetTeamLuaAI
local spGetGaiaTeamID = Spring.GetGaiaTeamID

local myPlayerID = Spring.GetMyPlayerID()

local allyCounter = 0
local enemyCounter = 0

PlayerColor = {0, 80, 255} -- Armada Blue
SimpleAllyColor = {0,255,0} -- Full Green
SimpleEnemyColor = {255, 16, 5} -- Cortex Red


AllyColors = {
    [1] = {82, 151, 255}, -- Light Blue
    [2] = {94, 9, 178}, -- Purple
    [3] = {191, 169, 255}, -- Lavender
    [4] = {81, 66, 251}, -- Royal Blue
    [5] = {11, 232, 18}, -- Light Green
    [6] = {178, 255, 227}, -- Aqua
    [7] = {0, 170, 99}, -- Grass
    [8] = {0, 255, 0},
    [9] = {0, 255, 0},
    [10] = {0, 255, 0},
    [11] = {0, 255, 0},
    [12] = {0, 255, 0},
    [13] = {0, 255, 0},
    [14] = {0, 255, 0},
    [15] = {0, 255, 0},
    [16] = {0, 255, 0},
    [17] = {0, 255, 0},
    [18] = {0, 255, 0},
    [19] = {0, 255, 0},
    [20] = {0, 255, 0},
    [21] = {0, 255, 0},
    [22] = {0, 255, 0},
    [23] = {0, 255, 0},
    [24] = {0, 255, 0},
    [25] = {0, 255, 0},
    [26] = {0, 255, 0},
    [27] = {0, 255, 0},
    [28] = {0, 255, 0},
    [29] = {0, 255, 0},
    [30] = {0, 255, 0},
    [31] = {0, 255, 0},
    [32] = {0, 255, 0},
}

EnemyColors = {
    [1] = {255, 16, 5}, -- Cortex Red
    [2] = {255, 220, 34}, -- Yellow
    [3] = {255, 125, 32}, -- Pumpkin
    [4] = {229, 18, 120}, -- Hot Pink
    [5] = {255, 243, 135}, -- Light Yellow
    [6] = {118, 39, 6}, -- Rust
    [7] = {251, 167, 120}, -- Salmon
    [8] = {166, 14, 5}, -- Blood
    [9] = {255, 0, 0},
    [10] = {255, 0, 0},
    [11] = {255, 0, 0},
    [12] = {255, 0, 0},
    [13] = {255, 0, 0},
    [14] = {255, 0, 0},
    [15] = {255, 0, 0},
    [16] = {255, 0, 0},
    [17] = {255, 0, 0},
    [18] = {255, 0, 0},
    [19] = {255, 0, 0},
    [20] = {255, 0, 0},
    [21] = {255, 0, 0},
    [22] = {255, 0, 0},
    [23] = {255, 0, 0},
    [24] = {255, 0, 0},
    [25] = {255, 0, 0},
    [26] = {255, 0, 0},
    [27] = {255, 0, 0},
    [28] = {255, 0, 0},
    [29] = {255, 0, 0},
    [30] = {255, 0, 0},
    [31] = {255, 0, 0},
    [32] = {255, 0, 0},
}

ScavColor = {97, 36, 97}
ChickenColor = {255, 0, 0}
GaiaColor = {127, 127, 127}


local function UpdatePlayerColors()
    local teams = spGetTeamList()
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
        elseif teamID == myTeam then
            spSetTeamColor(teamID, PlayerColor[1]/255, PlayerColor[2]/255, PlayerColor[3]/255)
        else
            if allyTeam == myAllyTeam then
                allyCounter = allyCounter+1
                spSetTeamColor(teamID, AllyColors[allyCounter][1] /255, AllyColors[allyCounter][2] /255, AllyColors[allyCounter][3] /255)
            else
                enemyCounter = enemyCounter+1
                spSetTeamColor(teamID, EnemyColors[enemyCounter][1] /255, EnemyColors[enemyCounter][2] /255, EnemyColors[enemyCounter][3] /255)
            end
        end
    end
    allyCounter = 0
    enemyCounter = 0
end

function gadget:Initialize()
    UpdatePlayerColors()
end

function gadget:PlayerChanged(playerID)
    if playerID == myPlayerID then
        UpdatePlayerColors()
    end
end




