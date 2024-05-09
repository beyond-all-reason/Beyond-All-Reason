return {

    -- Commanders
    ['EnemyCommanderDied'] = {
       sound = {
           [1] = {
               file = 'EnemyCommanderDied.wav',
               text = 'tips.notifications.enemyCommanderDied',
           },
       }, 
       delay = 1,
    },
    ['FriendlyCommanderDied'] = {
       sound = {
           [1] = {
               file = 'FriendlyCommanderDied.wav',
               text = 'tips.notifications.friendlyCommanderDied',
           },
       }, 
       delay = 1,
    },
    ['FriendlyCommanderSelfD'] = {
       sound = {
           [1] = {
               file = 'AlliedComSelfD.wav',
               text = 'tips.notifications.friendlyCommanderSelfD',
           },
       }, 
       delay = 1,
    },
    ['ComHeavyDamage'] = {
       sound = {
           [1] = {
               file = 'ComHeavyDamage.wav',
               text = 'tips.notifications.commanderDamage',
           },
       }, 
       delay = 12,
    },
    ['TeamDownLastCommander'] = {
       sound = {
           [1] = {
               file = 'Teamdownlastcommander.wav',
               text = 'tips.notifications.teamdownlastcommander',
           },
       }, 
       delay = 30,
    },
    ['YouHaveLastCommander'] = {
       sound = {
           [1] = {
               file = 'Youhavelastcommander.wav',
               text = 'tips.notifications.youhavelastcommander',
           },
       }, 
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
       delay = 90,
    },
    ['GameStarted'] = {
       sound = {
           [1] = {
               file = 'GameStarted.wav',
               text = 'tips.notifications.gameStarted',
           },
       }, 
       delay = 1,
    },
    ['BattleEnded'] = {
       sound = {
           [1] = {
               file = 'BattleEnded.wav',
               text = 'tips.notifications.battleEnded',
           },
       }, 
       delay = 1,
    },
    ['GamePause'] = {
       sound = {
           [1] = {
               file = 'GamePause.wav',
               text = 'tips.notifications.gamePaused',
           },
       }, 
       delay = 5,
    },
    ['PlayerLeft'] = {
       sound = {
           [1] = {
               file = 'PlayerDisconnected.wav',
               text = 'tips.notifications.playerLeft',
           },
       }, 
       delay = 1,
    },
    ['PlayerAdded'] = {
       sound = {
           [1] = {
               file = 'PlayerAdded.wav',
               text = 'tips.notifications.playerAdded',
           },
       }, 
       delay = 1,
    },
    ['PlayerResigned'] = {
       sound = {
           [1] = {
               file = 'PlayerResigned.wav',
               text = 'tips.notifications.playerResigned',
           },
       }, 
       delay = 1,
    },
    ['PlayerTimedout'] = {
       sound = {
           [1] = {
               file = 'PlayerTimedout.wav',
               text = 'tips.notifications.playerTimedout',
           },
       }, 
       delay = 1,
    },
    ['PlayerReconnecting'] = {
       sound = {
           [1] = {
               file = 'PlayerTimedout.wav',
               text = 'tips.notifications.playerReconnecting',
           },
       }, 
       delay = 1,
    },
    ['RaptorsAndScavsMixed'] = {
        sound = {
            [1] = {
                file = 'RaptorsAndScavsMixed.wav',
                text = 'tips.notifications.raptorsAndScavsMixed',
            },
        }, 
        delay = 15,
    },

    -- Awareness


	['MaxUnitsReached'] = {
		sound = {
			[1] = {
				--file = 'MaxUnitsReached.wav',
				text = 'tips.notifications.maxUnitsReached',
			},
		}, 
		delay = 90,
	},
    ['UnitsReceived'] = {
       sound = {
           [1] = {
               file = 'UnitReceived.wav',
               text = 'tips.notifications.unitsReceived',
           },
       }, 
       delay = 5,
    },
    ['RadarLost'] = {
       sound = {
           [1] = {
               file = 'RadarLost.wav',
               text = 'tips.notifications.radarLost',
           },
       }, 
       delay = 12,
    },
    ['AdvRadarLost'] = {
       sound = {
           [1] = {
               file = 'AdvRadarLost.wav',
               text = 'tips.notifications.advancedRadarLost',
           },
       }, 
       delay = 12,
    },
    ['MexLost'] = {
       sound = {
           [1] = {
               file = 'MexLost.wav',
               text = 'tips.notifications.metalExtractorLost',
           },
       }, 
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
       delay = 80,
    },
    ['WholeTeamWastingMetal'] = {
       sound = {
           [1] = {
               file = 'WholeTeamWastingMetal.wav',
               text = 'tips.notifications.teamWastingMetal',
           },
       }, 
       delay = 60,
    },
    ['WholeTeamWastingEnergy'] = {
       sound = {
           [1] = {
               file = 'WholeTeamWastingEnergy.wav',
               text = 'tips.notifications.teamWastingEnergy',
           },
       }, 
       delay = 120,
    },
    ['LowPower'] = {
       sound = {
           [1] = {
               file = 'LowPower.wav',
               text = 'tips.notifications.lowPower',
           },
       }, 
       delay = 50,
    },
    ['WindNotGood'] = {
       sound = {
           [1] = {
               file = 'WindNotGood.wav',
               text = 'tips.notifications.lowWind',
           },
       }, 
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
       delay = 3,
    },
    ['LrpcTargetUnits'] = {
       sound = {
           [1] = {
               file = 'LrpcTargetUnits.wav',
               text = 'tips.notifications.lrpcAttacking',
           },
       }, 
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
       delay = 30,
    },
    ['BuzzsawIsReady'] = {
       sound = {
           [1] = {
               file = 'CalamityIsReady.wav',
               text = 'tips.notifications.buzzsawReady',
           },
       }, 
       delay = 30,
    },
    ['Tech3UnitReady'] = {
       sound = {
           [1] = {
               file = 'Tech3UnitReady.wav',
               text = 'tips.notifications.t3Ready',
           },
       }, 
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
       delay = 9999999,
    },
    ['T3Detected'] = {
       sound = {
           [1] = {
               file = 'T3UnitDetected.wav',
               text = 'tips.notifications.t3Detected',
           },
       }, 
       delay = 9999999,
    },
    ['AircraftSpotted'] = {
       sound = {
           [1] = {
               file = 'AircraftSpotted.wav',
               text = 'tips.notifications.aircraftSpotted',
           },
       }, 
       delay = 9999999,
    },
    ['MinesDetected'] = {
       sound = {
           [1] = {
               file = 'MinesDetected.wav',
               text = 'tips.notifications.minesDetected',
           },
       }, 
       delay = 200,
    },
    ['IntrusionCountermeasure'] = {
       sound = {
           [1] = {
               file = 'StealthyUnitsInRange.wav',
               text = 'tips.notifications.stealthDetected',
           },
       }, 
       delay = 55,
    },
    ['LrpcDetected'] = {
       sound = {
           [1] = {
               file = 'LrpcDetected.wav',
               text = 'tips.notifications.lrpcDetected',
           },
       }, 
       delay = 25,
    },
    ['EMPmissilesiloDetected'] = {
       sound = {
           [1] = {
               file = 'EmpSiloDetected.wav',
               text = 'tips.notifications.empSiloDetected',
           },
       }, 
       delay = 4,
    },
    ['TacticalNukeSiloDetected'] = {
       sound = {
           [1] = {
               file = 'TacticalNukeDetected.wav',
               text = 'tips.notifications.tacticalSiloDetected',
           },
       }, 
       delay = 4,
    },
    ['NuclearSiloDetected'] = {
       sound = {
           [1] = {
               file = 'NuclearSiloDetected.wav',
               text = 'tips.notifications.nukeSiloDetected',
           },
       }, 
       delay = 4,
    },
    ['NuclearBomberDetected'] = {
       sound = {
           [1] = {
               file = 'NuclearBomberDetected.wav',
               text = 'tips.notifications.nukeBomberDetected',
           },
       }, 
       delay = 60,
    },
    ['JuggernautDetected'] = {
       sound = {
           [1] = {
               file = 'BehemothDetected.wav',
               text = 'tips.notifications.t3MobileTurretDetected',
           },
       }, 
       delay = 9999999,
    },
    ['KorgothDetected'] = {
       sound = {
           [1] = {
               file = 'JuggernautDetected.wav',
               text = 'tips.notifications.t3AssaultBotDetected',
           },
       }, 
       delay = 9999999,
    },
    ['BanthaDetected'] = {
       sound = {
           [1] = {
               file = 'TitanDetected.wav',
               text = 'tips.notifications.t3AssaultMechDetected',
           },
       }, 
       delay = 9999999,
    },
    ['FlagshipDetected'] = {
       sound = {
           [1] = {
               file = 'FlagshipDetected.wav',
               text = 'tips.notifications.flagshipDetected',
           },
       }, 
       delay = 9999999,
    },
    ['CommandoDetected'] = {
       sound = {
           [1] = {
               file = 'CommandoDetected.wav',
               text = 'tips.notifications.commandoDetected',
           },
       }, 
       delay = 9999999,
    },
    ['TransportDetected'] = {
       sound = {
           [1] = {
               file = 'TransportDetected.wav',
               text = 'tips.notifications.transportDetected',
           },
       }, 
       delay = 9999999,
    },
    ['AirTransportDetected'] = {
       sound = {
           [1] = {
               file = 'AirTransportDetected.wav',
               text = 'tips.notifications.airTransportDetected',
           },
       }, 
       delay = 9999999,
    },
    ['SeaTransportDetected'] = {
       sound = {
           [1] = {
               file = 'SeaTransportDetected.wav',
               text = 'tips.notifications.seaTransportDetected',
           },
       }, 
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
       delay = 9999999,
       unlisted = true,
    },
}
