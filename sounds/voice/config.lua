--[[
EventName = {
	delay = integrer - Minimum seconds that have to pass to play this notification again.
	stackedDelay = bool - Reset the delay even when attempted to play the notif under cooldown. 
							Useful for stuff you want to be able to hear often, but not repeatedly if the condition didn't change.
	resetOtherEventDelay = string - Name of 'fallback' event that will get it's delay reset. 
							For example, UnitLost, is a general notif for losing units, but we have MetalExtractorLost, or RadarLost. I want those to reset UnitLost as well.
	soundEffect = string - Sound Effect to play alongside the notification, located in 'sounds/voice-soundeffects'
	tutorial = bool - Sound effect used for the tutorial messages, there's a whole different handling of those. (WIP)
}
]]


return {

	-- Commanders
	EnemyCommanderDied = {
		delay = 1,
		soundEffect = "EnemyComDead",
	},
	FriendlyCommanderDied = {
		delay = 1,
		soundEffect = "FriendlyComDead",
	},
	FriendlyCommanderSelfD = {
		delay = 1,
		soundEffect = "FriendlyComDead",
	},
	NeutralCommanderDied = {
		delay = 1,
		soundEffect = "NeutralComDead",
	},
	NeutralCommanderSelfD = {
		delay = 1,
		soundEffect = "NeutralComDead",
	},
	ComHeavyDamage = {
		delay = 10,
		stackedDelay = true,
		soundEffect = "CommanderHeavilyDamaged",
	},
	TeamDownLastCommander = {
		delay = 30,
		soundEffect = "YourTeamHasTheLastCommander",
	},
	YouHaveLastCommander = {
		delay = 30,
		soundEffect = "YouHaveTheLastCommander",
	},

	-- Game Status
	ChooseStartLoc = {
		delay = 90,
	},
	GameStarted = {
		delay = 1,
	},
	GameUnpaused = {
		delay = 1,
	},
	BattleEnded = {
		delay = 1,
		soundEffect = "GameEnd",
	},
	BattleVictory = {
		delay = 1,
		soundEffect = "GameEnd",
	},
	BattleDefeat = {
		delay = 1,
		soundEffect = "GameEnd",
	},
	GamePaused = {
		delay = 1,
	},

	TeammateCaughtUp = {
		delay = 5,
	},
	TeammateDisconnected = {
		delay = 5,
	},
	TeammateLagging = {
		delay = 5,
	},
	TeammateReconnected = {
		delay = 5,
	},
	TeammateResigned = {
		delay = 5,
	},
	TeammateTimedout = {
		delay = 5,
	},

	EnemyPlayerCaughtUp = {
		delay = 5,
	},
	EnemyPlayerDisconnected = {
		delay = 5,
	},
	EnemyPlayerLagging = {
		delay = 5,
	},
	EnemyPlayerReconnected = {
		delay = 5,
	},
	EnemyPlayerResigned = {
		delay = 5,
	},
	EnemyPlayerTimedout = {
		delay = 5,
	},

	NeutralPlayerCaughtUp = {
		delay = 5,
	},
	NeutralPlayerDisconnected = {
		delay = 5,
	},
	NeutralPlayerLagging = {
		delay = 5,
	},
	NeutralPlayerReconnected = {
		delay = 5,
	},
	NeutralPlayerResigned = {
		delay = 5,
	},
	NeutralPlayerTimedout = {
		delay = 5,
	},
	RaptorsAndScavsMixed = {
		delay = 15,
	},

	-- Awareness
	MaxUnitsReached = {
		delay = 90,
	},
	BaseUnderAttack = {
		delay = 30,
		stackedDelay = true,
		resetOtherEventDelay = "UnitsUnderAttack",
		soundEffect = "UnitUnderAttack",
	},
	UnitsCaptured = {
		delay = 5,
	},
	UnitsReceived = {
		delay = 5,
	},
	CommanderUnderAttack = {
		delay = 10,
		stackedDelay = true,
		resetOtherEventDelay = "UnitsUnderAttack",
		soundEffect = "CommanderUnderAttack",
	},
	UnitsUnderAttack = {
		delay = 60,
		stackedDelay = true,
		soundEffect = "UnitUnderAttack",
	},
	UnitLost = {
		delay = 60,
		stackedDelay = true,
		soundEffect = "UnitUnderAttack",
	},
	RadarLost = {
		delay = 30,
		stackedDelay = true,
		resetOtherEventDelay = "UnitLost",
		soundEffect = "UnitUnderAttack",
	},
	AdvancedRadarLost = {
		delay = 30,
		stackedDelay = true,
		resetOtherEventDelay = "UnitLost",
		soundEffect = "UnitUnderAttack",
	},
	MetalExtractorLost = {
		delay = 30,
		stackedDelay = true,
		resetOtherEventDelay = "UnitLost",
		soundEffect = "UnitUnderAttack",
	},

	-- Resources
	YouAreOverflowingMetal = {
		delay = 60,
		stackedDelay = true,
	},
	WholeTeamWastingMetal = {
		delay = 60,
		stackedDelay = true,
	},
	WholeTeamWastingEnergy = {
		delay = 120,
		stackedDelay = true,
	},
	YouAreWastingMetal = {
		delay = 60,
		stackedDelay = true,
	},
	YouAreWastingEnergy = {
		delay = 120,
		stackedDelay = true,
	},
	LowPower = {
		delay = 10,
		stackedDelay = true,
	},

	-- Alerts
	NukeLaunched = {
		delay = 3,
		soundEffect = "NukeAlert",
	},
	LrpcTargetUnits = {
		delay = 30,
		stackedDelay = true,
	},

	-- Unit Ready
	RagnarokIsReady = {
		delay = 120,
		stackedDelay = true,
	},
	CalamityIsReady = {
		delay = 120,
		stackedDelay = true,
	},
	StarfallIsReady = {
		delay = 120,
		stackedDelay = true,
	},
	AstraeusIsReady = {
		delay = 120,
		stackedDelay = true,
	},
	SolinvictusIsReady = {
		delay = 120,
		stackedDelay = true,
	},
	TitanIsReady = {
		delay = 120,
		stackedDelay = true,
	},
	ThorIsReady = {
		delay = 120,
		stackedDelay = true,
	},
	JuggernautIsReady = {
		delay = 120,
		stackedDelay = true,
	},
	BehemothIsReady = {
		delay = 120,
		stackedDelay = true,
	},
	FlagshipIsReady = {
		delay = 120,
		stackedDelay = true,
	},
	Tech2UnitReady = {
		delay = 9999999,
	},
	Tech3UnitReady = {
		delay = 9999999,
	},
	Tech4UnitReady = {
		delay = 9999999,
	},
	Tech2TeamReached = {
		delay = 9999999,
	},
	Tech3TeamReached = {
		delay = 9999999,
	},
	Tech4TeamReached = {
		delay = 9999999,
	},

	-- Units Detected
	Tech2UnitDetected = {
		delay = 9999999,
	},
	Tech3UnitDetected = {
		delay = 9999999,
	},
	Tech4UnitDetected = {
		delay = 9999999,
	},
	EnemyDetected = {
		delay = 120,
		stackedDelay = true,
	},
	AircraftDetected = {
		delay = 120,
		stackedDelay = true,
	},
	MinesDetected = {
		delay = 60,
		stackedDelay = true,
	},
	StealthyUnitsDetected = {
		delay = 30,
		stackedDelay = true,
	},
	LrpcDetected = {
		delay = 25,
		stackedDelay = true,
	},
	EmpSiloDetected = {
		delay = 25,
		stackedDelay = true,
	},
	TacticalNukeSiloDetected = {
		delay = 25,
		stackedDelay = true,
	},
	LongRangeNapalmLauncherDetected = {
		delay = 25,
		stackedDelay = true,
	},
	NuclearSiloDetected = {
		delay = 25,
		stackedDelay = true,
	},
	CalamityDetected = {
		delay = 25,
		stackedDelay = true,
	},
	RagnarokDetected = {
		delay = 25,
		stackedDelay = true,
	},
	StarfallDetected = {
		delay = 25,
		stackedDelay = true,
	},
	NuclearBomberDetected = {
		delay = 60,
		stackedDelay = true,
	},
	BehemothDetected = {
		delay = 120,
		stackedDelay = true,
	},
	SolinvictusDetected = {
		delay = 120,
		stackedDelay = true,
	},
	JuggernautDetected = {
		delay = 120,
		stackedDelay = true,
	},
	TitanDetected = {
		delay = 120,
		stackedDelay = true,
	},
	ThorDetected = {
		delay = 120,
		stackedDelay = true,
	},
	FlagshipDetected = {
		delay = 120,
		stackedDelay = true,
	},
	AstraeusDetected = {
		delay = 120,
		stackedDelay = true,
	},
	AirTransportDetected = {
		delay = 120,
		stackedDelay = true,
	},

	-- Lava
	LavaRising = {
		delay = 25,
		soundEffect = "LavaAlert",
	},
	LavaDropping = {
		delay = 25,
		soundEffect = "LavaAlert",
	},

	-- Tutorial / tips
	Welcome = {
		delay = 9999999,
	},
	BuildMetal = {
		delay = 9999999,
		tutorial = true,
	},
	BuildEnergy = {
		delay = 9999999,
		tutorial = true,
	},
	BuildFactory = {
		delay = 9999999,
		tutorial = true,
	},
	BuildRadar = {
		delay = 9999999,
		tutorial = true,
	},
	FactoryAir = {
		delay = 9999999,
		tutorial = true,
	},
	FactoryAirplanes = {
		delay = 9999999,
		tutorial = true,
	},
	FactoryBots = {
		delay = 9999999,
		tutorial = true,
	},
	FactoryHovercraft = {
		delay = 9999999,
		tutorial = true,
	},
	FactoryVehicles = {
		delay = 9999999,
		tutorial = true,
	},
	FactoryShips = {
		delay = 9999999,
		tutorial = true,
	},
	ReadyForTech2 = {
		delay = 9999999,
		tutorial = true,
	},
	BuildIntrusionCounterMeasure = {
		delay = 9999999,
		tutorial = true,
	},
	-- UpgradeMexT2 = {
	-- 	delay = 9999999,
	-- 	tutorial = true,
	-- },
	-- for the future
	DuplicateFactory = {
		delay = 9999999,
		tutorial = true,
	},
	Paralyzer = {
		delay = 9999999,
		tutorial = true,
	},

	-- Raptors/Scavs ----------------------------------------------------------------------
	["PvE/AntiNukeReminder"] = {
		delay = 10,
	},

	-- Raptor Queen Hatch Progress
	["PvE/Raptor_Queen50Ready"] = {
		delay = 10,
	},
	["PvE/Raptor_Queen75Ready"] = {
		delay = 10,
	},
	["PvE/Raptor_Queen90Ready"] = {
		delay = 10,
	},
	["PvE/Raptor_Queen95Ready"] = {
		delay = 10,
	},
	["PvE/Raptor_Queen98Ready"] = {
		delay = 10,
	},
	["PvE/Raptor_QueenIsReady"] = {
		delay = 10,
	},

	-- Raptor Queen Health
	["PvE/Raptor_Queen50HealthLeft"] = {
		delay = 10,
	},
	["PvE/Raptor_Queen25HealthLeft"] = {
		delay = 10,
	},
	["PvE/Raptor_Queen10HealthLeft"] = {
		delay = 10,
	},
	["PvE/Raptor_Queen5HealthLeft"] = {
		delay = 10,
	},
	["PvE/Raptor_QueenIsDestroyed"] = {
		delay = 10,
	},

	-- Scavenger Boss Construction Progress
	["PvE/Scav_Boss50Ready"] = {
		delay = 10,
	},
	["PvE/Scav_Boss75Ready"] = {
		delay = 10,
	},
	["PvE/Scav_Boss90Ready"] = {
		delay = 10,
	},
	["PvE/Scav_Boss95Ready"] = {
		delay = 10,
	},
	["PvE/Scav_Boss98Ready"] = {
		delay = 10,
	},
	["PvE/Scav_BossIsReady"] = {
		delay = 10,
	},

	-- Scavenger Boss Health
	["PvE/Scav_Boss50HealthLeft"] = {
		delay = 10,
	},
	["PvE/Scav_Boss25HealthLeft"] = {
		delay = 10,
	},
	["PvE/Scav_Boss10HealthLeft"] = {
		delay = 10,
	},
	["PvE/Scav_Boss5HealthLeft"] = {
		delay = 10,
	},
	["PvE/Scav_BossIsDestroyed"] = {
		delay = 10,
	},

}
