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

local myPlayerID = Spring.GetMyPlayerID()

local allyCounter = 0
local enemyCounter = 0

PlayerColor = {0, 80, 255} -- Armada Blue
SimpleAllyColor = {0,255,0} -- Full Green
SimpleEnemyColor = {255, 16, 5} -- Cortex Red


AllyColors = {
    [1] = {53, 189, 240}, -- Light Blue
    [2] = {147, 226, 251}, -- Very Light Blue
    [3] = {29, 249, 170}, -- Blueish Green
    [4] = {0,255,0}, -- Full Green
    [5] = {151, 255, 151}, -- Bleached Green
    [6] = {0, 100, 0}, -- Dark Green
    [7] = {118, 0, 225}, -- Purple
    [8] = {185, 106, 255}, -- Light Purple
    -- Do we need more?
    [9] = {56, 0, 106}, -- Dark Purple
    [10] = {0, 0, 0},
    [11] = {0, 0, 0},
    [12] = {0, 0, 0},
    [13] = {0, 0, 0},
    [14] = {0, 0, 0},
    [15] = {0, 0, 0},
    [16] = {0, 0, 0},
}

EnemyColors = {
    [1] = {255, 16, 5}, -- Cortex Red
    [2] = {255, 220, 34}, -- Yellow
    [3] = {255, 125, 32}, -- Orange
    [4] = {229, 18, 120}, -- Pink
    [5] = {255, 243, 135}, -- Light Yellow
    [6] = {118, 39, 6}, -- Brown
    [7] = {220, 139, 104}, -- Light Brown
    [8] = {175, 32, 0}, -- Brownish Orange
    -- Do we need more?
    [9] = {0, 0, 0},
    [10] = {0, 0, 0},
    [11] = {0, 0, 0},
    [12] = {0, 0, 0},
    [13] = {0, 0, 0},
    [14] = {0, 0, 0},
    [15] = {0, 0, 0},
    [16] = {0, 0, 0},
}

ScavColor = {0.38, 0.14, 0.38}
ChickenColor = {1, 0, 0}
GaiaColor = {0.5, 0.5, 0.5}


local function UpdatePlayerColors()
    local teams = spGetTeamList()
    local myTeam = spGetMyTeamID()
    local myAllyTeam = spGetMyAllyTeamID()
    for i = 1,#teams do
        local teamID = teams[i]
        if teamID == myTeam then
            spSetTeamColor(teamID, PlayerColor[1]/255, PlayerColor[2]/255, PlayerColor[3]/255)
        else
            local _, leader, isDead, isAiTeam, side, allyTeam, incomeMultiplier, customTeamKeys = spGetTeamInfo(teamID)
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




