local scavengersAIEnabled = false
local scavengerAllyTeamID
local teams = Spring.GetTeamList()
for i = 1,#teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
		scavengersAIEnabled = true
		scavengerAllyTeamID = select(6, Spring.GetTeamInfo(i - 1))
		break
	end
end

local ruinSpawnEnabled = false
if (Spring.GetModOptions and (Spring.GetModOptions().ruins or "disabled") == "enabled") or (Spring.GetModOptions and (Spring.GetModOptions().scavonlyruins or "enabled") == "enabled" and scavengersAIEnabled == true) then
	ruinSpawnEnabled = true
end

function gadget:GetInfo()
    return {
      name      = "flyby aircraft spawner",
      desc      = "123",
      author    = "Damgam",
      date      = "2021",
      layer     = -100,
      enabled   = ruinSpawnEnabled,
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local math_random = math.random
local GaiaTeamID = Spring.GetGaiaTeamID()

local mapsizex = Game.mapSizeX
local mapsizez = Game.mapSizeZ
local mapheightmin, mapheightmax = Spring.GetGroundExtremes()

local flyByChance = 60 -- bigger = less
local lastFlyByFrame = 0
local minimumFlyByDelay = 30*30 -- seconds*framesPerSecond

local moveCtrlQueue = {}

local flyByFormations = { -- {x,z}
    [1] = {
        {0,0},
    },
    [2] = {
        {0,0},
        {-32,128},
        {-32,-128},
    },
    [3] = {
        {0,0},
        {-32,128},
        {-32,-128},
        {-64,-256},
        {-64,256},
    },
    [4] = {
        {0,0},
        {-32,128},
        {-32,-128},
        {-64,-256},
        {-64,256},
        {-96,-384},
        {-96,384},
    },
    [5] = {
        {0,0},
        {-32,128},
        {-32,-128},
        {-200,0},
        {-232,128},
        {-232,-128},
        {-264,-256},
        {-264,256},
    },
    [6] = {
        {0,0},
        {-32,128},
        {-32,-128},
        {-64,-256},
        {-64,256},
        {-200,0},
        {-232,128},
        {-232,-128},
        {-264,-256},
        {-264,256},
        {-296,-384},
        {-296,384},
    },
    [7] = {
        {0,0},
        {-32,128},
        {-32,-128},
        {-200,0},
        {-232,128},
        {-232,-128},
        {-264,-256},
        {-264,256},
        {-400,0},
        {-432,128},
        {-432,-128},
        {-464,-256},
        {-464,256},
        {-496,-384},
        {-496,384},
    },
}

local flyByUnits = {
    "armatlas",
    "armca",
    "armfig",
    "armkam",
    "armpeep",
    "armthund",
    "armaca",
    "armawac",
    "armblade",
    "armbrawl",
    "armdfly",
    "armhawk",
    "armlance",
    "armliche",
    "armpnix",
    "armstil",
    "armcsa",
    "armsaber",
    "armsb",
    "armseap",
    "armsehak",
    "armsfig",
    "corbw",
    "corca",
    "corfink",
    "corshad",
    "corvalk",
    "corveng",
    "coraca",
    "corape",
    "corawac",
    "corcrw",
    "corhurc",
    "corseah",
    "cortitan",
    "corvamp",
    "corcsa",
    "corcut",
    "corhunt",
    "corsb",
    "corseap",
    "corsfig",
}

function gadget:GameFrame(n)
    if n%30 == 10 then
        local flyByRandom = math_random(1,flyByChance)
        if flyByRandom == 1 and n > lastFlyByFrame+minimumFlyByDelay then
            lastFlyByFrame = n
            local flyByZPosition = math_random(-1000,mapsizez+1000)
            local flyByFormation = flyByFormations[math_random(1,#flyByFormations)]
            local flyByUnit = flyByUnits[math_random(1,#flyByUnits)]
            local speed = UnitDefNames[flyByUnit].speed
            if not speed or speed < 1 then
                speed = 1
            end
            speed = speed*0.04
            local posx = 0
            local posz = flyByZPosition
            local posy = mapheightmax+math_random(100,1000)
            for i = 1,#flyByFormation do
                local unit = Spring.CreateUnit(flyByUnit.."_scav", posx, posy, posz, 1, GaiaTeamID)
                Spring.SetUnitNoDraw(unit, true)
                local posx = posx+flyByFormation[i][1]-15000
                local posz = posz+flyByFormation[i][2]
                Spring.MoveCtrl.Enable(unit)
                Spring.MoveCtrl.SetNoBlocking(unit, true)
                Spring.MoveCtrl.SetProgressState(unit, "active")
                Spring.MoveCtrl.SetLimits(unit, -10000, 0, -10000, 10000, 99999, 10000)
	            Spring.MoveCtrl.SetPosition(unit, posx, posy, posz)
                Spring.MoveCtrl.SetVelocity(unit, speed, 0, 0)
                Spring.MoveCtrl.Disable(unit)

                Spring.SetUnitMaxHealth(unit, 10000000)
	            Spring.SetUnitHealth(unit, 10000000)
                Spring.SetUnitStealth(unit, true)
	            Spring.SetUnitNoSelect(unit, true)
	            Spring.SetUnitNoMinimap(unit, true)
                Spring.SetUnitAlwaysVisible(unit, true)
                Spring.SetUnitNeutral(unit, true)
				Spring.GiveOrderToUnit(unit,CMD.FIRE_STATE,{0},0)
                Spring.GiveOrderToUnit(unit,CMD.MOVE_STATE,{0},0)

                Spring.GiveOrderToUnit(unit, CMD.MOVE, {mapsizex*0.5,posy,mapsizez*0.5}, {})

                moveCtrlQueue[#moveCtrlQueue+1] = {unit, speed, posx, posy, posz}
            end
        end
    end
    if n%30 == 9 then
        if #moveCtrlQueue > 0 then
            for i = 1, #moveCtrlQueue do
                local unit = moveCtrlQueue[i][1]
                local speed = moveCtrlQueue[i][2]
                local posx = moveCtrlQueue[i][3]
                local posy = moveCtrlQueue[i][4]
                local posz = moveCtrlQueue[i][5]
                Spring.MoveCtrl.Enable(unit)
                Spring.MoveCtrl.SetPosition(unit, posx, posy, posz)
                Spring.MoveCtrl.SetRotation(unit, 0, 0, 0)
                Spring.MoveCtrl.SetHeading(unit, 16384)
                Spring.MoveCtrl.SetVelocity(unit, speed, 0, 0)

                Spring.SetUnitNoDraw(unit, false)
            end
            moveCtrlQueue = {}
        end
    end
end
