-- local function addSound(notifname, notiffile, delay, length, text, unlisted)
--     Spring.Echo("['" .. notifname .. "'] = {")
--     Spring.Echo("   sound = {")
--     Spring.Echo("       [1] = {")
--     Spring.Echo("           file = '" .. notiffile[1] .. "',")
--     Spring.Echo("           text = '" .. text .. "',")
--     Spring.Echo("       },")
--     Spring.Echo("   },")
--     Spring.Echo("   length = " .. length .. ",")
--     Spring.Echo("   delay = " .. delay .. ",")
--     if unlisted then
--     Spring.Echo("   unlisted = true,")
--     end
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
addSound('GamePause', {soundFolder .. 'GamePause.wav'}, 2, 1, 'tips.notifications.gamePaused')
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
       sound = {
           [1] = {
               file = 'EnemyCommanderDied.wav',
               text = 'tips.notifications.enemyCommanderDied',
           },
       },
       length = 1.7,
       delay = 1,
    },
    ['FriendlyCommanderDied'] = {
       sound = {
           [1] = {
               file = 'FriendlyCommanderDied.wav',
               text = 'tips.notifications.friendlyCommanderDied',
           },
       },
       length = 1.75,
       delay = 1,
    },
    ['FriendlyCommanderSelfD'] = {
       sound = {
           [1] = {
               file = 'AlliedComSelfD.wav',
               text = 'tips.notifications.friendlyCommanderSelfD',
           },
       },
       length = 2,
       delay = 1,
    },
    ['ComHeavyDamage'] = {
       sound = {
           [1] = {
               file = 'ComHeavyDamage.wav',
               text = 'tips.notifications.commanderDamage',
           },
       },
       length = 2.25,
       delay = 12,
    },
    ['TeamDownLastCommander'] = {
       sound = {
           [1] = {
               file = 'Teamdownlastcommander.wav',
               text = 'tips.notifications.teamdownlastcommander',
           },
       },
       length = 3,
       delay = 30,
    },
    ['YouHaveLastCommander'] = {
       sound = {
           [1] = {
               file = 'Youhavelastcommander.wav',
               text = 'tips.notifications.youhavelastcommander',
           },
       },
       length = 3,
       delay = 30,
    },

    -- Game Status


    ['ChooseStartLoc'] = {
       sound = {
           [1] = {
               file = 'ChooseStartLoc.wav',
               text = 'tips.notifications.startingLocation',
           },
       },
       length = 2.2,
       delay = 90,
    },
    ['GameStarted'] = {
       sound = {
           [1] = {
               file = 'GameStarted.wav',
               text = 'tips.notifications.gameStarted',
           },
       },
       length = 2,
       delay = 1,
    },
    ['BattleEnded'] = {
       sound = {
           [1] = {
               file = 'BattleEnded.wav',
               text = 'tips.notifications.battleEnded',
           },
       },
       length = 2,
       delay = 1,
    },
    ['GamePause'] = {
       sound = {
           [1] = {
               file = 'GamePause.wav',
               text = 'tips.notifications.gamePaused',
           },
       },
       length = 1,
       delay = 5,
    },
    ['PlayerLeft'] = {
       sound = {
           [1] = {
               file = 'PlayerDisconnected.wav',
               text = 'tips.notifications.playerLeft',
           },
       },
       length = 1.65,
       delay = 1,
    },
    ['PlayerAdded'] = {
       sound = {
           [1] = {
               file = 'PlayerAdded.wav',
               text = 'tips.notifications.playerAdded',
           },
       },
       length = 2.36,
       delay = 1,
    },
    ['PlayerResigned'] = {
       sound = {
           [1] = {
               file = 'PlayerResigned.wav',
               text = 'tips.notifications.playerResigned',
           },
       },
       length = 2.36,
       delay = 1,
    },
    ['PlayerTimedout'] = {
       sound = {
           [1] = {
               file = 'PlayerTimedout.wav',
               text = 'tips.notifications.playerTimedout',
           },
       },
       length = 2.36,
       delay = 1,
    },
    ['PlayerReconnecting'] = {
       sound = {
           [1] = {
               file = 'PlayerTimedout.wav',
               text = 'tips.notifications.playerReconnecting',
           },
       },
       length = 2.36,
       delay = 1,
    },

    -- Awareness


    ['UnitsReceived'] = {
       sound = {
           [1] = {
               file = 'UnitReceived.wav',
               text = 'tips.notifications.unitsReceived',
           },
       },
       length = 1.75,
       delay = 5,
    },
    ['RadarLost'] = {
       sound = {
           [1] = {
               file = 'RadarLost.wav',
               text = 'tips.notifications.radarLost',
           },
       },
       length = 1,
       delay = 12,
    },
    ['AdvRadarLost'] = {
       sound = {
           [1] = {
               file = 'AdvRadarLost.wav',
               text = 'tips.notifications.advancedRadarLost',
           },
       },
       length = 1.32,
       delay = 12,
    },
    ['MexLost'] = {
       sound = {
           [1] = {
               file = 'MexLost.wav',
               text = 'tips.notifications.metalExtractorLost',
           },
       },
       length = 1.53,
       delay = 10,
    },

    -- Resources


    ['YouAreOverflowingMetal'] = {
       sound = {
           [1] = {
               file = 'YouAreOverflowingMetal.wav',
               text = 'tips.notifications.overflowingMetal',
           },
       },
       length = 1.63,
       delay = 80,
    },
    ['WholeTeamWastingMetal'] = {
       sound = {
           [1] = {
               file = 'WholeTeamWastingMetal.wav',
               text = 'tips.notifications.teamWastingMetal',
           },
       },
       length = 1.82,
       delay = 60,
    },
    ['WholeTeamWastingEnergy'] = {
       sound = {
           [1] = {
               file = 'WholeTeamWastingEnergy.wav',
               text = 'tips.notifications.teamWastingEnergy',
           },
       },
       length = 2.14,
       delay = 120,
    },
    ['LowPower'] = {
       sound = {
           [1] = {
               file = 'LowPower.wav',
               text = 'tips.notifications.lowPower',
           },
       },
       length = 0.95,
       delay = 50,
    },
    ['WindNotGood'] = {
       sound = {
           [1] = {
               file = 'WindNotGood.wav',
               text = 'tips.notifications.lowWind',
           },
       },
       length = 3.76,
       delay = 9999999,
    },

    -- Alerts

    ['NukeLaunched'] = {
       sound = {
           [1] = {
               file = 'NukeLaunched.wav',
               text = 'tips.notifications.nukeLaunched',
           },
       },
       length = 2,
       delay = 3,
    },
    ['LrpcTargetUnits'] = {
       sound = {
           [1] = {
               file = 'LrpcTargetUnits.wav',
               text = 'tips.notifications.lrpcAttacking',
           },
       },
       length = 3.8,
       delay = 9999999,
    },

    -- Unit Ready


    ['VulcanIsReady'] = {
       sound = {
           [1] = {
               file = 'RagnarokIsReady.wav',
               text = 'tips.notifications.vulcanReady',
           },
       },
       length = 1.16,
       delay = 30,
    },
    ['BuzzsawIsReady'] = {
       sound = {
           [1] = {
               file = 'CalamityIsReady.wav',
               text = 'tips.notifications.buzzsawReady',
           },
       },
       length = 1.31,
       delay = 30,
    },
    ['Tech3UnitReady'] = {
       sound = {
           [1] = {
               file = 'Tech3UnitReady.wav',
               text = 'tips.notifications.t3Ready',
           },
       },
       length = 1.78,
       delay = 9999999,
    },

    -- Units Detected

    ['T2Detected'] = {
       sound = {
           [1] = {
               file = 'T2UnitDetected.wav',
               text = 'tips.notifications.t2Detected',
           },
       },
       length = 1.5,
       delay = 9999999,
    },
    ['T3Detected'] = {
       sound = {
           [1] = {
               file = 'T3UnitDetected.wav',
               text = 'tips.notifications.t3Detected',
           },
       },
       length = 1.94,
       delay = 9999999,
    },
    ['AircraftSpotted'] = {
       sound = {
           [1] = {
               file = 'AircraftSpotted.wav',
               text = 'tips.notifications.aircraftSpotted',
           },
       },
       length = 1.25,
       delay = 9999999,
    },
    ['MinesDetected'] = {
       sound = {
           [1] = {
               file = 'MinesDetected.wav',
               text = 'tips.notifications.minesDetected',
           },
       },
       length = 2.6,
       delay = 200,
    },
    ['IntrusionCountermeasure'] = {
       sound = {
           [1] = {
               file = 'StealthyUnitsInRange.wav',
               text = 'tips.notifications.stealthDetected',
           },
       },
       length = 4.8,
       delay = 30,
    },
    ['LrpcDetected'] = {
       sound = {
           [1] = {
               file = 'LrpcDetected.wav',
               text = 'tips.notifications.lrpcDetected',
           },
       },
       length = 2.3,
       delay = 25,
    },
    ['EMPmissilesiloDetected'] = {
       sound = {
           [1] = {
               file = 'EmpSiloDetected.wav',
               text = 'tips.notifications.empSiloDetected',
           },
       },
       length = 2.1,
       delay = 4,
    },
    ['TacticalNukeSiloDetected'] = {
       sound = {
           [1] = {
               file = 'TacticalNukeDetected.wav',
               text = 'tips.notifications.tacticalSiloDetected',
           },
       },
       length = 2,
       delay = 4,
    },
    ['NuclearSiloDetected'] = {
       sound = {
           [1] = {
               file = 'NuclearSiloDetected.wav',
               text = 'tips.notifications.nukeSiloDetected',
           },
       },
       length = 1.7,
       delay = 4,
    },
    ['NuclearBomberDetected'] = {
       sound = {
           [1] = {
               file = 'NuclearBomberDetected.wav',
               text = 'tips.notifications.nukeBomberDetected',
           },
       },
       length = 1.6,
       delay = 60,
    },
    ['JuggernautDetected'] = {
       sound = {
           [1] = {
               file = 'BehemothDetected.wav',
               text = 'tips.notifications.t3MobileTurretDetected',
           },
       },
       length = 1.4,
       delay = 9999999,
    },
    ['KorgothDetected'] = {
       sound = {
           [1] = {
               file = 'JuggernautDetected.wav',
               text = 'tips.notifications.t3AssaultBotDetected',
           },
       },
       length = 1.25,
       delay = 9999999,
    },
    ['BanthaDetected'] = {
       sound = {
           [1] = {
               file = 'TitanDetected.wav',
               text = 'tips.notifications.t3AssaultMechDetected',
           },
       },
       length = 1.25,
       delay = 9999999,
    },
    ['FlagshipDetected'] = {
       sound = {
           [1] = {
               file = 'FlagshipDetected.wav',
               text = 'tips.notifications.flagshipDetected',
           },
       },
       length = 1.4,
       delay = 9999999,
    },
    ['CommandoDetected'] = {
       sound = {
           [1] = {
               file = 'CommandoDetected.wav',
               text = 'tips.notifications.commandoDetected',
           },
       },
       length = 1.28,
       delay = 9999999,
    },
    ['TransportDetected'] = {
       sound = {
           [1] = {
               file = 'TransportDetected.wav',
               text = 'tips.notifications.transportDetected',
           },
       },
       length = 1.5,
       delay = 9999999,
    },
    ['AirTransportDetected'] = {
       sound = {
           [1] = {
               file = 'AirTransportDetected.wav',
               text = 'tips.notifications.airTransportDetected',
           },
       },
       length = 1.38,
       delay = 9999999,
    },
    ['SeaTransportDetected'] = {
       sound = {
           [1] = {
               file = 'SeaTransportDetected.wav',
               text = 'tips.notifications.seaTransportDetected',
           },
       },
       length = 1.95,
       delay = 9999999,
    },

    -- Lava

    ['LavaRising'] = {
       sound = {
           [1] = {
               file = 'Lavarising.wav',
               text = 'tips.notifications.lavaRising',
           },
       },
       length = 3,
       delay = 25,
       unlisted = true,
    },
    ['LavaDropping'] = {
       sound = {
           [1] = {
               file = 'Lavadropping.wav',
               text = 'tips.notifications.lavaDropping',
           },
       },
       length = 2,
       delay = 25,
       unlisted = true,
    },

    -- Tutorials

    ['t_welcome'] = {
       sound = {
           [1] = {
               file = 'tutorial/welcome.wav',
               text = 'tips.notifications.tutorialWelcome',
           },
       },
       length = 9.19,
       delay = 9999999,
       unlisted = true,
    },
    ['t_buildmex'] = {
       sound = {
           [1] = {
               file = 'tutorial/buildmex.wav',
               text = 'tips.notifications.tutorialBuildMetal',
           },
       },
       length = 6.31,
       delay = 9999999,
       unlisted = true,
    },
    ['t_buildenergy'] = {
       sound = {
           [1] = {
               file = 'tutorial/buildenergy.wav',
               text = 'tips.notifications.tutorialBuildenergy',
           },
       },
       length = 6.47,
       delay = 9999999,
       unlisted = true,
    },
    ['t_makefactory'] = {
       sound = {
           [1] = {
               file = 'tutorial/makefactory.wav',
               text = 'tips.notifications.tutorialBuildFactory',
           },
       },
       length = 8.87,
       delay = 9999999,
       unlisted = true,
    },
    ['t_factoryair'] = {
       sound = {
           [1] = {
               file = 'tutorial/factoryair.wav',
               text = 'tips.notifications.tutorialFactoryAir',
           },
       },
       length = 8.2,
       delay = 9999999,
       unlisted = true,
    },
    ['t_factoryairsea'] = {
       sound = {
           [1] = {
               file = 'tutorial/factoryairsea.wav',
               text = 'tips.notifications.tutorialFactorySeaplanes',
           },
       },
       length = 7.39,
       delay = 9999999,
       unlisted = true,
    },
    ['t_factorybots'] = {
       sound = {
           [1] = {
               file = 'tutorial/factorybots.wav',
               text = 'tips.notifications.tutorialFactoryBots',
           },
       },
       length = 8.54,
       delay = 9999999,
       unlisted = true,
    },
    ['t_factoryhovercraft'] = {
       sound = {
           [1] = {
               file = 'tutorial/factoryhovercraft.wav',
               text = 'tips.notifications.tutorialFactoryHovercraft',
           },
       },
       length = 6.91,
       delay = 9999999,
       unlisted = true,
    },
    ['t_factoryvehicles'] = {
       sound = {
           [1] = {
               file = 'tutorial/factoryvehicles.wav',
               text = 'tips.notifications.tutorialFactoryVehicles',
           },
       },
       length = 11.92,
       delay = 9999999,
       unlisted = true,
    },
    ['t_factoryships'] = {
       sound = {
           [1] = {
               file = 'tutorial/factoryships.wav',
               text = 'tips.notifications.tutorialFactoryShips',
           },
       },
       length = 15.82,
       delay = 9999999,
       unlisted = true,
    },
    ['t_readyfortech2'] = {
       sound = {
           [1] = {
               file = 'tutorial/readyfortecht2.wav',
               text = 'tips.notifications.tutorialT2Ready',
           },
       },
       length = 9.4,
       delay = 9999999,
       unlisted = true,
    },
    ['t_duplicatefactory'] = {
       sound = {
           [1] = {
               file = 'tutorial/duplicatefactory.wav',
               text = 'tips.notifications.tutorialDuplicateFactory',
           },
       },
       length = 6.1,
       delay = 9999999,
       unlisted = true,
    },
    ['t_paralyzer'] = {
       sound = {
           [1] = {
               file = 'tutorial/paralyzer.wav',
               text = 'tips.notifications.tutorialParalyzer',
           },
       },
       length = 9.66,
       delay = 9999999,
       unlisted = true,
    },
}

for notifID, notifDef in pairs(soundsTable) do -- Temporary to keep it working for now
    local notifSounds = {}
    local notifTexts = {}
    for i = 1,#notifDef.sound do
        notifSounds[i] = soundFolder .. notifDef.sound[i].file
        notifTexts[i] = notifDef.sound[i].text
    end
    --addSound(notifID, notifSounds, notifDef.delay, notifDef.length, notifTexts, notifDef.unlisted)
    addSound(notifID, notifSounds, notifDef.delay, notifDef.length, notifDef.sound[1].text, notifDef.unlisted) -- bandaid, picking text from first variation always.
end
