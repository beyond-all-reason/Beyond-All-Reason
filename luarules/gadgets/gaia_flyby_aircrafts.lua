local scavengersAIEnabled = Spring.Utilities.Gametype.IsScavengers()

local ruinSpawnEnabled = false
if Spring.GetModOptions().ruins == "enabled" or (Spring.GetModOptions().ruins == "scav-only" and scavengersAIEnabled) then
	ruinSpawnEnabled = true
end

function gadget:GetInfo()
    return {
      name      = "flyby aircraft spawner",
      desc      = "123",
      author    = "Damgam",
      date      = "2021",
	  license   = "GNU GPL, v2 or later",
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

local lastFlyByFrame = 0

local flyByChance = 900 -- bigger = less
local minimumFlyByDelay = 60*30 -- seconds*framesPerSecond

-- for testing
-- local flyByChance = 1 -- bigger = less
-- local minimumFlyByDelay = 1*30 -- seconds*framesPerSecond

local moveCtrlQueue = {}

local flyByFormations = { -- {x,z}
    [1] = {
        {0,0},
    },
    [2] = {
        {0,0},
        {-64,128},
        {-64,-128},
    },
    [3] = {
        {0,0},
        {-64,128},
        {-64,-128},
        {-128,-256},
        {-128,256},
    },
    [4] = {
        {0,0},
        {-64,128},
        {-64,-128},
        {-128,-256},
        {-128,256},
        {-192,-384},
        {-192,384},
    },
    [5] = {
        {0,0},
        {-64,128},
        {-64,-128},
        {-200,0},
        {-264,128},
        {-264,-128},
        {-328,-256},
        {-328,256},
    },
    [6] = {
        {0,0},
        {-64,128},
        {-64,-128},
        {-128,-256},
        {-128,256},
        {-200,0},
        {-264,128},
        {-264,-128},
        {-328,-256},
        {-328,256},
        {-392,-384},
        {-392,384},
    },
    [7] = {
        {0,0},
        {-64,128},
        {-64,-128},
        {-200,0},
        {-264,128},
        {-264,-128},
        {-328,-256},
        {-328,256},
        {-400,0},
        {-464,128},
        {-464,-128},
        {-528,-256},
        {-528,256},
        {-596,-384},
        {-596,384},
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
    "corcrwh",
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

            local flipRandom = math_random(0,3)

			local swapXandZ = false
			local flipXorZ = 1 -- don't
			local flyByHeading = 16384
			local flyByPosZ = 0
			local flyByPosX = 0
            if flipRandom == 0 then
                swapXandZ = false
                flipXorZ = 1 -- don't
                flyByHeading = 16384
            end
            if flipRandom == 1 then
                swapXandZ = false
                flipXorZ = -1 -- flip
                flyByHeading = -16384
            end
            if flipRandom == 2 then
                swapXandZ = true
                flipXorZ = 1 -- don't
                flyByHeading = 0
            end
            if flipRandom == 3 then
                swapXandZ = true
                flipXorZ = -1 -- flip
                flyByHeading = 32768
            end

            if swapXandZ == false then
                flyByPosZ = math_random(-1000,mapsizez+1000)
                flyByPosX = 0
            else
                flyByPosX = math_random(-1000,mapsizex+1000)
                flyByPosZ = 0
            end

            local flyByFormation = flyByFormations[math_random(1,#flyByFormations)]
            local flyByUnit = flyByUnits[math_random(1,#flyByUnits)]

            local speed = UnitDefNames[flyByUnit].speed
            if not speed or speed < 1 then
                speed = 1
            end
            speed = speed*0.04

            local posx = flyByPosX
            local posz = flyByPosZ
            local posy = mapheightmax+math_random(100,1000)

            for i = 1,#flyByFormation do
                local unit = Spring.CreateUnit(flyByUnit.."_scav", posx, posy, posz, 1, GaiaTeamID)
				if unit then		-- sometimes nil
					Spring.SetUnitNoDraw(unit, true)
					if swapXandZ == false then
						posx = flyByPosX+(flyByFormation[i][1]*flipXorZ)-15000*flipXorZ
						posz = flyByPosZ+flyByFormation[i][2]
					else
						posx = flyByPosX+flyByFormation[i][2]
						posz = flyByPosZ+(flyByFormation[i][1]*flipXorZ)-15000*flipXorZ
					end
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

					moveCtrlQueue[#moveCtrlQueue+1] = {unit, speed, posx, posy, posz, swapXandZ, flipXorZ, flyByHeading}
				end
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
                local swapXandZ = moveCtrlQueue[i][6]
                local flipXorZ = moveCtrlQueue[i][7]
                local flyByHeading = moveCtrlQueue[i][8]
                Spring.MoveCtrl.Enable(unit)
                Spring.MoveCtrl.SetPosition(unit, posx, posy, posz)
                Spring.MoveCtrl.SetRotation(unit, 0, 0, 0)
                Spring.MoveCtrl.SetHeading(unit, flyByHeading)
                if swapXandZ == false then
                    if flipXorZ == 1 then
                        Spring.MoveCtrl.SetVelocity(unit, speed, 0, 0)
                    else
                        Spring.MoveCtrl.SetVelocity(unit, -speed, 0, 0)
                    end
                else
                    if flipXorZ == -1 then
                        Spring.MoveCtrl.SetVelocity(unit, 0, 0, -speed)
                    else
                        Spring.MoveCtrl.SetVelocity(unit, 0, 0, speed)
                    end
                end

                Spring.SetUnitNoDraw(unit, false)
            end
            moveCtrlQueue = {}
        end
    end
end
