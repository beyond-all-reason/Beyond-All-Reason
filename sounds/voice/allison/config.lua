-- local function addSound(notifname, notiffile, delay, length, text)
--     Spring.Echo("['" .. notifname .. "'] = {")
--     Spring.Echo("   [1] = {")
--     Spring.Echo("       file = '" .. notiffile[1] .. "',")
--     Spring.Echo("       length = " .. length .. ",")
--     Spring.Echo("       delay = " .. delay .. ",")
--     Spring.Echo("       text = '" .. text .. "',")
--     Spring.Echo("   },")
--     Spring.Echo("},")
-- end

--[[
-- commanders
addSound('EnemyCommanderDied', {soundFolder .. 'EnemyCommanderDied.wav'}, 1, 1.7, 'tips.notifications.enemyCommanderDied')
addSound('FriendlyCommanderDied', {soundFolder .. 'FriendlyCommanderDied.wav'}, 1, 1.75, 'tips.notifications.friendlyCommanderDied')
addSound('FriendlyCommanderSelfD', {soundFolder .. 'AlliedComSelfD.wav'}, 1, 2, 'tips.notifications.friendlyCommanderSelfD')
addSound('ComHeavyDamage', {soundFolder .. 'ComHeavyDamage.wav'}, 12, 2.25, 'tips.notifications.commanderDamage')
addSound('TeamDownLastCommander', {soundFolder .. 'Teamdownlastcommander.wav'}, 30, 3, 'tips.notifications.teamdownlastcommander')
addSound('YouHaveLastCommander', {soundFolder .. 'Youhavelastcommander.wav'}, 30, 3, 'tips.notifications.youhavelastcommander')

-- game status
addSound('ChooseStartLoc', {soundFolder .. 'ChooseStartLoc.wav'}, 90, 2.2, 'tips.notifications.startingLocation')
addSound('GameStarted', {soundFolder .. 'GameStarted.wav'}, 1, 2, 'tips.notifications.gameStarted')
addSound('BattleEnded', {soundFolder .. 'BattleEnded.wav'}, 1, 2, 'tips.notifications.battleEnded')
addSound('GamePause', {soundFolder .. 'GamePause.wav'}, 5, 1, 'tips.notifications.gamePaused')
addSound('PlayerLeft', {soundFolder .. 'PlayerDisconnected.wav'}, 1, 1.65, 'tips.notifications.playerLeft')
addSound('PlayerAdded', {soundFolder .. 'PlayerAdded.wav'}, 1, 2.36, 'tips.notifications.playerAdded')
addSound('PlayerResigned', {soundFolder .. 'PlayerResigned.wav'}, 1, 2.36, 'tips.notifications.playerResigned')
addSound('PlayerTimedout', {soundFolder .. 'PlayerTimedout.wav'}, 1, 2.36, 'tips.notifications.playerTimedout')
addSound('PlayerReconnecting', {soundFolder .. 'PlayerTimedout.wav'}, 1, 2.36, 'tips.notifications.playerReconnecting')

-- awareness
--addSound('IdleBuilder', {soundFolder .. 'IdleBuilder.wav'}, 30, 1.9, 'A builder has finished building')
addSound('UnitsReceived', {soundFolder .. 'UnitReceived.wav'}, 5, 1.75, 'tips.notifications.unitsReceived')
addSound('RadarLost', {soundFolder .. 'RadarLost.wav'}, 12, 1, 'tips.notifications.radarLost')
addSound('AdvRadarLost', {soundFolder .. 'AdvRadarLost.wav'}, 12, 1.32, 'tips.notifications.advancedRadarLost')
addSound('MexLost', {soundFolder .. 'MexLost.wav'}, 10, 1.53, 'tips.notifications.metalExtractorLost')

-- resources
addSound('YouAreOverflowingMetal', {soundFolder .. 'YouAreOverflowingMetal.wav'}, 80, 1.63, 'tips.notifications.overflowingMetal')
--addSound('YouAreOverflowingEnergy', {soundFolder .. 'YouAreOverflowingEnergy.wav'}, 100, 1.7, 'Your are overflowing energy')
--addSound('YouAreWastingMetal', {soundFolder .. 'YouAreWastingMetal.wav'}, 25, 1.5, 'Your are wasting metal')
--addSound('YouAreWastingEnergy', {soundFolder .. 'YouAreWastingEnergy.wav'}, 35, 1.3, 'Your are wasting energy')
addSound('WholeTeamWastingMetal', {soundFolder .. 'WholeTeamWastingMetal.wav'}, 60, 1.82, 'tips.notifications.teamWastingMetal')
addSound('WholeTeamWastingEnergy', {soundFolder .. 'WholeTeamWastingEnergy.wav'}, 120, 2.14, 'tips.notifications.teamWastingEnergy')
--addSound('MetalStorageFull', {soundFolder .. 'metalstorefull.wav'}, 40, 1.62, 'Metal storage is full')
--addSound('EnergyStorageFull', {soundFolder .. 'energystorefull.wav'}, 40, 1.65, 'Energy storage is full')
addSound('LowPower', {soundFolder .. 'LowPower.wav'}, 50, 0.95, 'tips.notifications.lowPower')
addSound('WindNotGood', {soundFolder .. 'WindNotGood.wav'}, 9999999, 3.76, 'tips.notifications.lowWind')

-- alerts
addSound('NukeLaunched', {soundFolder .. 'NukeLaunched.wav'}, 3, 2, 'tips.notifications.nukeLaunched')
addSound('LrpcTargetUnits', {soundFolder .. 'LrpcTargetUnits.wav'}, 9999999, 3.8, 'tips.notifications.lrpcAttacking')

-- unit ready
addSound('VulcanIsReady', {soundFolder .. 'RagnarokIsReady.wav'}, 30, 1.16, 'tips.notifications.vulcanReady')
addSound('BuzzsawIsReady', {soundFolder .. 'CalamityIsReady.wav'}, 30, 1.31, 'tips.notifications.buzzsawReady')
addSound('Tech3UnitReady', {soundFolder .. 'Tech3UnitReady.wav'}, 9999999, 1.78, 'tips.notifications.t3Ready')

-- detections
addSound('T2Detected', {soundFolder .. 'T2UnitDetected.wav'}, 9999999, 1.5, 'tips.notifications.t2Detected')	-- top bar widget calls this
addSound('T3Detected', {soundFolder .. 'T3UnitDetected.wav'}, 9999999, 1.94, 'tips.notifications.t3Detected')	-- top bar widget calls this

addSound('AircraftSpotted', {soundFolder .. 'AircraftSpotted.wav'}, 9999999, 1.25, 'tips.notifications.aircraftSpotted')	-- top bar widget calls this
addSound('MinesDetected', {soundFolder .. 'MinesDetected.wav'}, 200, 2.6, 'tips.notifications.minesDetected')
addSound('IntrusionCountermeasure', {soundFolder .. 'StealthyUnitsInRange.wav'}, 30, 4.8, 'tips.notifications.stealthDetected')

-- unit detections
addSound('LrpcDetected', {soundFolder .. 'LrpcDetected.wav'}, 25, 2.3, 'tips.notifications.lrpcDetected')
addSound('EMPmissilesiloDetected', {soundFolder .. 'EmpSiloDetected.wav'}, 4, 2.1, 'tips.notifications.empSiloDetected')
addSound('TacticalNukeSiloDetected', {soundFolder .. 'TacticalNukeDetected.wav'}, 4, 2, 'tips.notifications.tacticalSiloDetected')
addSound('NuclearSiloDetected', {soundFolder .. 'NuclearSiloDetected.wav'}, 4, 1.7, 'tips.notifications.nukeSiloDetected')
addSound('NuclearBomberDetected', {soundFolder .. 'NuclearBomberDetected.wav'}, 60, 1.6, 'tips.notifications.nukeBomberDetected')
addSound('JuggernautDetected', {soundFolder .. 'BehemothDetected.wav'}, 9999999, 1.4, 'tips.notifications.t3MobileTurretDetected')
addSound('KorgothDetected', {soundFolder .. 'JuggernautDetected.wav'}, 9999999, 1.25, 'tips.notifications.t3AssaultBotDetected')
addSound('BanthaDetected', {soundFolder .. 'TitanDetected.wav'}, 9999999, 1.25, 'tips.notifications.t3AssaultMechDetected')
addSound('FlagshipDetected', {soundFolder .. 'FlagshipDetected.wav'}, 9999999, 1.4, 'tips.notifications.flagshipDetected')
addSound('CommandoDetected', {soundFolder .. 'CommandoDetected.wav'}, 9999999, 1.28, 'tips.notifications.commandoDetected')
addSound('TransportDetected', {soundFolder .. 'TransportDetected.wav'}, 9999999, 1.5, 'tips.notifications.transportDetected')
addSound('AirTransportDetected', {soundFolder .. 'AirTransportDetected.wav'}, 9999999, 1.38, 'tips.notifications.airTransportDetected')
addSound('SeaTransportDetected', {soundFolder .. 'SeaTransportDetected.wav'}, 9999999, 1.95, 'tips.notifications.seaTransportDetected')

-- lava/liquid level change notifications
addSound('LavaRising', {soundFolder .. 'Lavarising.wav'}, 25, 3, 'tips.notifications.lavaRising', true)
addSound('LavaDropping', {soundFolder .. 'Lavadropping.wav'}, 25, 2, 'tips.notifications.lavaDropping', true)

-- tutorial explanations (unlisted)
local td = 'tutorial/'
addSound('t_welcome', {soundFolder .. td ..'welcome.wav'}, 9999999, 9.19, 'tips.notifications.tutorialWelcome', true)
addSound('t_buildmex', {soundFolder .. td ..'buildmex.wav'}, 9999999, 6.31, 'tips.notifications.tutorialBuildMetal', true)
addSound('t_buildenergy', {soundFolder .. td ..'buildenergy.wav'}, 9999999, 6.47, 'tips.notifications.tutorialBuildenergy', true)
addSound('t_makefactory', {soundFolder .. td ..'makefactory.wav'}, 9999999, 8.87, 'tips.notifications.tutorialBuildFactory', true)
addSound('t_factoryair', {soundFolder .. td ..'factoryair.wav'}, 9999999, 8.2, 'tips.notifications.tutorialFactoryAir', true)
addSound('t_factoryairsea', {soundFolder .. td ..'factoryairsea.wav'}, 9999999, 7.39, 'tips.notifications.tutorialFactorySeaplanes', true)
addSound('t_factorybots', {soundFolder .. td ..'factorybots.wav'}, 9999999, 8.54, 'tips.notifications.tutorialFactoryBots', true)
addSound('t_factoryhovercraft', {soundFolder .. td ..'factoryhovercraft.wav'}, 9999999, 6.91, 'tips.notifications.tutorialFactoryHovercraft', true)
addSound('t_factoryvehicles', {soundFolder .. td ..'factoryvehicles.wav'}, 9999999, 11.92, 'tips.notifications.tutorialFactoryVehicles', true)
addSound('t_factoryships', {soundFolder .. td ..'factoryships.wav'}, 9999999, 15.82, 'tips.notifications.tutorialFactoryShips', true)
addSound('t_readyfortech2', {soundFolder .. td ..'readyfortecht2.wav'}, 9999999, 9.4, 'tips.notifications.tutorialT2Ready', true)
addSound('t_duplicatefactory', {soundFolder .. td ..'duplicatefactory.wav'}, 9999999, 6.1, 'tips.notifications.tutorialDuplicateFactory', true)
addSound('t_paralyzer', {soundFolder .. td ..'paralyzer.wav'}, 9999999, 9.66, 'tips.notifications.tutorialParalyzer', true)

]]

local soundsTable = {

    -- Commanders

    ['EnemyCommanderDied'] = {
       [1] = {
           file = 'EnemyCommanderDied.wav',
           length = 1.7,
           delay = 1,
           text = 'tips.notifications.enemyCommanderDied',
       },
    },
    ['FriendlyCommanderDied'] = {
       [1] = {
           file = 'FriendlyCommanderDied.wav',
           length = 1.75,
           delay = 1,
           text = 'tips.notifications.friendlyCommanderDied',
       },
    },
    ['FriendlyCommanderSelfD'] = {
       [1] = {
           file = 'AlliedComSelfD.wav',
           length = 2,
           delay = 1,
           text = 'tips.notifications.friendlyCommanderSelfD',
       },
    },
    ['ComHeavyDamage'] = {
       [1] = {
           file = 'ComHeavyDamage.wav',
           length = 2.25,
           delay = 12,
           text = 'tips.notifications.commanderDamage',
       },
    },
    ['TeamDownLastCommander'] = {
       [1] = {
           file = 'Teamdownlastcommander.wav',
           length = 3,
           delay = 30,
           text = 'tips.notifications.teamdownlastcommander',
       },
    },
    ['YouHaveLastCommander'] = {
       [1] = {
           file = 'Youhavelastcommander.wav',
           length = 3,
           delay = 30,
           text = 'tips.notifications.youhavelastcommander',
       },
    },

    -- Game Status

    ['ChooseStartLoc'] = {
       [1] = {
           file = 'ChooseStartLoc.wav',
           length = 2.2,
           delay = 90,
           text = 'tips.notifications.startingLocation',
       },
    },
    ['GameStarted'] = {
       [1] = {
           file = 'GameStarted.wav',
           length = 2,
           delay = 1,
           text = 'tips.notifications.gameStarted',
       },
    },
    ['BattleEnded'] = {
       [1] = {
           file = 'BattleEnded.wav',
           length = 2,
           delay = 1,
           text = 'tips.notifications.battleEnded',
       },
    },
    ['GamePause'] = {
       [1] = {
           file = 'GamePause.wav',
           length = 1,
           delay = 5,
           text = 'tips.notifications.gamePaused',
       },
    },
    ['PlayerLeft'] = {
       [1] = {
           file = 'PlayerDisconnected.wav',
           length = 1.65,
           delay = 1,
           text = 'tips.notifications.playerLeft',
       },
    },
    ['PlayerAdded'] = {
       [1] = {
           file = 'PlayerAdded.wav',
           length = 2.36,
           delay = 1,
           text = 'tips.notifications.playerAdded',
       },
    },
    ['PlayerResigned'] = {
       [1] = {
           file = 'PlayerResigned.wav',
           length = 2.36,
           delay = 1,
           text = 'tips.notifications.playerResigned',
       },
    },
    ['PlayerTimedout'] = {
       [1] = {
           file = 'PlayerTimedout.wav',
           length = 2.36,
           delay = 1,
           text = 'tips.notifications.playerTimedout',
       },
    },
    ['PlayerReconnecting'] = {
       [1] = {
           file = 'PlayerTimedout.wav',
           length = 2.36,
           delay = 1,
           text = 'tips.notifications.playerReconnecting',
       },
    },

    -- Awareness

    ['UnitsReceived'] = {
       [1] = {
           file = 'UnitReceived.wav',
           length = 1.75,
           delay = 5,
           text = 'tips.notifications.unitsReceived',
       },
    },
    ['RadarLost'] = {
       [1] = {
           file = 'RadarLost.wav',
           length = 1,
           delay = 12,
           text = 'tips.notifications.radarLost',
       },
    },
    ['AdvRadarLost'] = {
       [1] = {
           file = 'AdvRadarLost.wav',
           length = 1.32,
           delay = 12,
           text = 'tips.notifications.advancedRadarLost',
       },
    },
    ['MexLost'] = {
       [1] = {
           file = 'MexLost.wav',
           length = 1.52,
           delay = 10,
           text = 'tips.notifications.metalExtractorLost',
       },
    },

    -- Resources

    ['YouAreOverflowingMetal'] = {
       [1] = {
           file = 'YouAreOverflowingMetal.wav',
           length = 1.63,
           delay = 80,
           text = 'tips.notifications.overflowingMetal',
       },
    },
    ['WholeTeamWastingMetal'] = {
       [1] = {
           file = 'WholeTeamWastingMetal.wav',
           length = 1.82,
           delay = 60,
           text = 'tips.notifications.teamWastingMetal',
       },
    },
    ['WholeTeamWastingEnergy'] = {
       [1] = {
           file = 'WholeTeamWastingEnergy.wav',
           length = 2.14,
           delay = 120,
           text = 'tips.notifications.teamWastingEnergy',
       },
    },
    ['LowPower'] = {
       [1] = {
           file = 'LowPower.wav',
           length = 0.95,
           delay = 50,
           text = 'tips.notifications.lowPower',
       },
    },
    ['WindNotGood'] = {
       [1] = {
           file = 'WindNotGood.wav',
           length = 3.76,
           delay = 9999999,
           text = 'tips.notifications.lowWind',
       },
    },

    -- Alerts

    ['NukeLaunched'] = {
       [1] = {
           file = 'NukeLaunched.wav',
           length = 2,
           delay = 3,
           text = 'tips.notifications.nukeLaunched',
       },
    },
    ['LrpcTargetUnits'] = {
       [1] = {
           file = 'LrpcTargetUnits.wav',
           length = 3.8,
           delay = 9999999,
           text = 'tips.notifications.lrpcAttacking',
       },
    },

    -- Unit Ready

    ['VulcanIsReady'] = {
       [1] = {
           file = 'RagnarokIsReady.wav',
           length = 1.16,
           delay = 30,
           text = 'tips.notifications.vulcanReady',
       },
    },
    ['BuzzsawIsReady'] = {
       [1] = {
           file = 'CalamityIsReady.wav',
           length = 1.31,
           delay = 30,
           text = 'tips.notifications.buzzsawReady',
       },
    },
    ['Tech3UnitReady'] = {
       [1] = {
           file = 'Tech3UnitReady.wav',
           length = 1.78,
           delay = 9999999,
           text = 'tips.notifications.t3Ready',
       },
    },

    -- Units Detected

    ['T2Detected'] = {
       [1] = {
           file = 'T2UnitDetected.wav',
           length = 1.5,
           delay = 9999999,
           text = 'tips.notifications.t2Detected',
       },
    },
    ['T3Detected'] = {
       [1] = {
           file = 'T3UnitDetected.wav',
           length = 1.94,
           delay = 9999999,
           text = 'tips.notifications.t3Detected',
       },
    },
    ['AircraftSpotted'] = {
       [1] = {
           file = 'AircraftSpotted.wav',
           length = 1.25,
           delay = 9999999,
           text = 'tips.notifications.aircraftSpotted',
       },
    },
    ['MinesDetected'] = {
       [1] = {
           file = 'MinesDetected.wav',
           length = 2.6,
           delay = 200,
           text = 'tips.notifications.minesDetected',
       },
    },
    ['IntrusionCountermeasure'] = {
       [1] = {
           file = 'StealthyUnitsInRange.wav',
           length = 4.8,
           delay = 30,
           text = 'tips.notifications.stealthDetected',
       },
    },
    ['LrpcDetected'] = {
       [1] = {
           file = 'LrpcDetected.wav',
           length = 2.3,
           delay = 25,
           text = 'tips.notifications.lrpcDetected',
       },
    },
    ['EMPmissilesiloDetected'] = {
       [1] = {
           file = 'EmpSiloDetected.wav',
           length = 2.1,
           delay = 4,
           text = 'tips.notifications.empSiloDetected',
       },
    },
    ['TacticalNukeSiloDetected'] = {
       [1] = {
           file = 'TacticalNukeDetected.wav',
           length = 2,
           delay = 4,
           text = 'tips.notifications.tacticalSiloDetected',
       },
    },
    ['NuclearSiloDetected'] = {
       [1] = {
           file = 'NuclearSiloDetected.wav',
           length = 1.7,
           delay = 4,
           text = 'tips.notifications.nukeSiloDetected',
       },
    },
    ['NuclearBomberDetected'] = {
       [1] = {
           file = 'NuclearBomberDetected.wav',
           length = 1.6,
           delay = 60,
           text = 'tips.notifications.nukeBomberDetected',
       },
    },
    ['JuggernautDetected'] = {
       [1] = {
           file = 'BehemothDetected.wav',
           length = 1.4,
           delay = 9999999,
           text = 'tips.notifications.t3MobileTurretDetected',
       },
    },
    ['KorgothDetected'] = {
       [1] = {
           file = 'JuggernautDetected.wav',
           length = 1.25,
           delay = 9999999,
           text = 'tips.notifications.t3AssaultBotDetected',
       },
    },
    ['BanthaDetected'] = {
       [1] = {
           file = 'TitanDetected.wav',
           length = 1.25,
           delay = 9999999,
           text = 'tips.notifications.t3AssaultMechDetected',
       },
    },
    ['FlagshipDetected'] = {
       [1] = {
           file = 'FlagshipDetected.wav',
           length = 1.4,
           delay = 9999999,
           text = 'tips.notifications.flagshipDetected',
       },
    },
    ['CommandoDetected'] = {
       [1] = {
           file = 'CommandoDetected.wav',
           length = 1.28,
           delay = 9999999,
           text = 'tips.notifications.commandoDetected',
       },
    },
    ['TransportDetected'] = {
       [1] = {
           file = 'TransportDetected.wav',
           length = 1.5,
           delay = 9999999,
           text = 'tips.notifications.transportDetected',
       },
    },
    ['AirTransportDetected'] = {
       [1] = {
           file = 'AirTransportDetected.wav',
           length = 1.38,
           delay = 9999999,
           text = 'tips.notifications.airTransportDetected',
       },
    },
    ['SeaTransportDetected'] = {
       [1] = {
           file = 'SeaTransportDetected.wav',
           length = 1.95,
           delay = 9999999,
           text = 'tips.notifications.seaTransportDetected',
       },
    },

    -- Lava

    ['LavaRising'] = {
       [1] = {
           file = 'Lavarising.wav',
           length = 3,
           delay = 25,
           text = 'tips.notifications.lavaRising',
           unlisted = true,
       },
    },
    ['LavaDropping'] = {
       [1] = {
           file = 'Lavadropping.wav',
           length = 2,
           delay = 25,
           text = 'tips.notifications.lavaDropping',
           unlisted = true,
       },
    },

    -- Tutorials

    ['t_welcome'] = {
       [1] = {
           file = 'tutorial/welcome.wav',
           length = 9.19,
           delay = 9999999,
           text = 'tips.notifications.tutorialWelcome',
           unlisted = true,
       },
    },
    ['t_buildmex'] = {
       [1] = {
           file = 'tutorial/buildmex.wav',
           length = 6.3,
           delay = 9999999,
           text = 'tips.notifications.tutorialBuildMetal',
           unlisted = true,
       },
    },
    ['t_buildenergy'] = {
       [1] = {
           file = 'tutorial/buildenergy.wav',
           length = 6.47,
           delay = 9999999,
           text = 'tips.notifications.tutorialBuildenergy',
           unlisted = true,
       },
    },
    ['t_makefactory'] = {
       [1] = {
           file = 'tutorial/makefactory.wav',
           length = 8.87,
           delay = 9999999,
           text = 'tips.notifications.tutorialBuildFactory',
           unlisted = true,
       },
    },
    ['t_factoryair'] = {
       [1] = {
           file = 'tutorial/factoryair.wav',
           length = 8.2,
           delay = 9999999,
           text = 'tips.notifications.tutorialFactoryAir',
           unlisted = true,
       },
    },
    ['t_factoryairsea'] = {
       [1] = {
           file = 'tutorial/factoryairsea.wav',
           length = 7.39,
           delay = 9999999,
           text = 'tips.notifications.tutorialFactorySeaplanes',
           unlisted = true,
       },
    },
    ['t_factorybots'] = {
       [1] = {
           file = 'tutorial/factorybots.wav',
           length = 8.54,
           delay = 9999999,
           text = 'tips.notifications.tutorialFactoryBots',
           unlisted = true,
       },
    },
    ['t_factoryhovercraft'] = {
       [1] = {
           file = 'tutorial/factoryhovercraft.wav',
           length = 6.91,
           delay = 9999999,
           text = 'tips.notifications.tutorialFactoryHovercraft',
           unlisted = true,
       },
    },
    ['t_factoryvehicles'] = {
       [1] = {
           file = 'tutorial/factoryvehicles.wav',
           length = 11.92,
           delay = 9999999,
           text = 'tips.notifications.tutorialFactoryVehicles',
           unlisted = true,
       },
    },
    ['t_factoryships'] = {
       [1] = {
           file = 'tutorial/factoryships.wav',
           length = 15.82,
           delay = 9999999,
           text = 'tips.notifications.tutorialFactoryShips',
           unlisted = true,
       },
    },
    ['t_readyfortech2'] = {
       [1] = {
           file = 'tutorial/readyfortecht2.wav',
           length = 9.4,
           delay = 9999999,
           text = 'tips.notifications.tutorialT2Ready',
           unlisted = true,
       },
    },
    ['t_duplicatefactory'] = {
       [1] = {
           file = 'tutorial/duplicatefactory.wav',
           length = 6.1,
           delay = 9999999,
           text = 'tips.notifications.tutorialDuplicateFactory',
           unlisted = true,
       },
    },
    ['t_paralyzer'] = {
       [1] = {
           file = 'tutorial/paralyzer.wav',
           length = 9.66,
           delay = 9999999,
           text = 'tips.notifications.tutorialParalyzer',
           unlisted = true,
       },
    },
}

for notifID, notifVariation in pairs(soundsTable) do -- Temporary to keep it working for now
    local notifFiles = {}
    local maxLength = 0
    local maxDelay = 0
    local text = notifVariation[1].text
    for i = 1,#notifVariation do
        notifFiles[i] = soundFolder .. notifVariation[i].file
        if notifVariation[i].length > maxLength then
            maxLength = notifVariation[i].length
        end
        if notifVariation[i].delay > maxDelay then
            maxDelay = notifVariation[i].delay
        end
    end
    addSound(notifID, notifFiles, maxDelay, maxLength, text, notifVariation[1].unlisted)
end

