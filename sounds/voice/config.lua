--[[
EventName = {
	Regular stuff:
		delay = integrer - Minimum seconds that have to pass to play this notification again.
		stackedDelay = bool - Reset the delay even when attempted to play the notif under cooldown. 
								Useful for stuff you want to be able to hear often, but not repeatedly if the condition didn't change.
		resetOtherEventDelay = table of strings - Names of other events that will get it's delay reset. 
								For example, UnitLost, is a general notif for losing units, but we have MetalExtractorLost, or RadarLost. I want those to reset UnitLost as well.
		soundEffect = string - Sound Effect to play alongside the notification, located in 'sounds/voice-soundeffects'
		notext = bool - hide the text part of the notification
		notifText = string - This is intended for custom widgets that cannot write I18N directly, overrides the I18N visible text.
		tutorial = bool - Sound effect used for the tutorial messages, there's a whole different handling of those. (WIP)

	Conditional Rules: 
		rulesEnable = table of strings - List of rules this notif will enable
		rulesDisable = table of strings - List of rules this notif will disable
		rulesPlayOnlyIfEnabled = table of strings - List of rules that are required to be enabled for this notification to work
		rulesPlayOnlyIfDisabled = table of strings - List of rules that are required to be disabled for this notification to work
}
]]

--[[
	-- Custom Widgets can now create custom notifications as well!
	-- Here's an example of widget code that makes it work!
	-- Copy Paste this entire block into a new widget and start using it!

	function widget:GetInfo()
		return {
			name = "Custom Notifications Example",
			desc = "Does various voice/text notifications",
			author = "Damgam",
			date = "2026",
			license = "GNU GPL, v2 or later",
			version = 1,
			layer = 5,
			enabled = true,
	        handler = true,

		}
	end

	local widgetInfo = widget:GetInfo()

	local function init()
	    WG['notifications'].registerCustomNotifWidget(widgetInfo.name) -- Register the custom notifs widget.

	    -- Adding Custom Notification Defs. See the original config file for instructions: https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/sounds/voice/config.lua
	    local customNotifDefs = {

	        PawnDetected = {
	            delay = 25,
	    		stackedDelay = true,
	            notifText = "Pawn Detected",
	            soundEffect = "NukeAlert",
	        },
	        GruntDetected = {
	            delay = 25,
	    		stackedDelay = true,
	            notifText = "Grunt Detected",
	            soundEffect = "NukeAlert",
	        },
	        ThisIsATest = {
	            delay = 10,
	            notifText = "Can you hear me?",
	            soundEffect = "AllyRequest",
	        },

	    }
	    WG['notifications'].addNotificationDefs(customNotifDefs) -- Calling out the Notifications widget to add these custom definitions

	    WG['notifications'].addUnitDetected("armpw", "PawnDetected") -- Adds Pawn to units of interest and assigns the PawnDetected notification to it.
	    WG['notifications'].addUnitDetected("corak", "GruntDetected") -- Adds Grunt to units of interest and assigns the GruntDetected notification to it.

	    if widgetHandler:IsWidgetKnown("Options") then -- Restart Options widget to load all your custom notifs to the list of notifs.
	        widgetHandler:DisableWidget("Options")
		    widgetHandler:EnableWidget("Options")
	    end
	end

	function widget:Update(dt)
	    if not WG['notifications'].registeredCustomNotifWidgets()[widgetInfo.name] then -- Checks if the widget have been registered in the notifications. If not, initialise it.
	        init()
	    end

	    WG['notifications'].queueNotification("ThisIsATest") -- Calls a notification based on an event, in this case though, every frame
	end
]]


return {

	-- Commanders
	EnemyCommanderDied = {
		delay = 1,
		soundEffect = "EnemyComDead",
		resetOtherEventDelay = {"NeutralCommanderDied"},
	},
	FriendlyCommanderDied = {
		delay = 1,
		soundEffect = "FriendlyComDead",
		resetOtherEventDelay = {"NeutralCommanderDied"},
	},
	FriendlyCommanderSelfD = {
		delay = 1,
		soundEffect = "FriendlyComDead",
		resetOtherEventDelay = {"NeutralCommanderSelfD"},
	},
	NeutralCommanderDied = {
		delay = 1,
		soundEffect = "NeutralComDead",
	},
	NeutralCommanderSelfD = {
		delay = 1,
		soundEffect = "NeutralComDead",
	},

	TeamDownLastCommander = {
		delay = 30,
		soundEffect = "YourTeamHasTheLastCommander",
	},
	YouHaveLastCommander = {
		delay = 30,
		soundEffect = "YouHaveTheLastCommander",
	},

	["RespawningCommanders/CommanderTransposed"] = {
		delay = 5,
	},
	["RespawningCommanders/AlliedCommanderTransposed"] = {
		delay = 5,
	},
	["RespawningCommanders/EnemyCommanderTransposed"] = {
		delay = 5,
	},
	["RespawningCommanders/CommanderEffigyLost"] = {
		delay = 5,
	},

	-- Game Status
	ChooseStartLoc = {
		delay = 90,
		notext = true,
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
	["TerritorialDomination/EnemyTeamEliminated"] = {
		delay = 2,
	},
	["TerritorialDomination/YourTeamEliminated"] = {
		delay = 2,
	},
	["TerritorialDomination/GainedLead"] = {
		delay = 20,
	},
	["TerritorialDomination/LostLead"] = {
		delay = 20,
	},

	TeammateCaughtUp = {
		delay = 5,
		resetOtherEventDelay = {"NeutralPlayerCaughtUp"},
	},
	TeammateDisconnected = {
		delay = 5,
		resetOtherEventDelay = {"NeutralPlayerDisconnected"},
	},
	TeammateLagging = {
		delay = 5,
		resetOtherEventDelay = {"NeutralPlayerLagging"},
	},
	TeammateReconnected = {
		delay = 5,
		resetOtherEventDelay = {"NeutralPlayerReconnected"},
	},
	TeammateResigned = {
		delay = 5,
		resetOtherEventDelay = {"NeutralPlayerResigned"},
	},
	TeammateTimedout = {
		delay = 5,
		resetOtherEventDelay = {"NeutralPlayerTimedout"},
	},

	EnemyPlayerCaughtUp = {
		delay = 5,
		resetOtherEventDelay = {"NeutralPlayerCaughtUp"},
	},
	EnemyPlayerDisconnected = {
		delay = 5,
		resetOtherEventDelay = {"NeutralPlayerDisconnected"},
	},
	EnemyPlayerLagging = {
		delay = 5,
		resetOtherEventDelay = {"NeutralPlayerLagging"},
	},
	EnemyPlayerReconnected = {
		delay = 5,
		resetOtherEventDelay = {"NeutralPlayerReconnected"},
	},
	EnemyPlayerResigned = {
		delay = 5,
		resetOtherEventDelay = {"NeutralPlayerResigned"},
	},
	EnemyPlayerTimedout = {
		delay = 5,
		resetOtherEventDelay = {"NeutralPlayerTimedout"},
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
		delay = 10,
		stackedDelay = true,
	},
	UnitsCaptured = {
		delay = 5,
	},
	UnitsReceived = {
		delay = 5,
	},


	UnitsUnderAttack = {
		delay = 60,
		stackedDelay = true,
		resetOtherEventDelay = {"DefenseUnderAttack"},
		soundEffect = "UnitUnderAttack",
	},
	DefenseUnderAttack = {
		delay = 60,
		stackedDelay = true,
		resetOtherEventDelay = {"UnitsUnderAttack"},
		soundEffect = "UnitUnderAttack",
	},

	EconomyUnderAttack = {
		delay = 30,
		stackedDelay = true,
		resetOtherEventDelay = {"UnitsUnderAttack", "DefenseUnderAttack"},
		soundEffect = "UnitUnderAttack",
	},
	FactoryUnderAttack = {
		delay = 30,
		stackedDelay = true,
		resetOtherEventDelay = {"UnitsUnderAttack", "DefenseUnderAttack"},
		soundEffect = "UnitUnderAttack",
	},
	CommanderUnderAttack = {
		delay = 10,
		stackedDelay = true,
		resetOtherEventDelay = {"UnitsUnderAttack", "DefenseUnderAttack"},
		soundEffect = "CommanderUnderAttack",
	},
	ComHeavyDamage = {
		delay = 10,
		stackedDelay = true,
		resetOtherEventDelay = {"UnitsUnderAttack", "DefenseUnderAttack", "CommanderUnderAttack"},
		soundEffect = "CommanderHeavilyDamaged",
	},


	UnitLost = { -- Master Event
		delay = 60,
		stackedDelay = true,
		soundEffect = "UnitUnderAttack",
	},

	RadarLost = {
		delay = 30,
		stackedDelay = true,
		resetOtherEventDelay = {"UnitLost", "RadarLost"},
		soundEffect = "UnitUnderAttack",
	},
	AdvancedRadarLost = {
		delay = 30,
		stackedDelay = true,
		resetOtherEventDelay = {"UnitLost", "AdvancedRadarLost"},
		soundEffect = "UnitUnderAttack",
	},

	MetalExtractorLost = {
		delay = 30,
		stackedDelay = true,
		resetOtherEventDelay = {"UnitLost"},
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
	LowMetal = {
		delay = 20,
		stackedDelay = true,
	},
	AllyRequestEnergy = {
		delay = 10,
		stackedDelay = true,
		soundEffect = "AllyRequest",
	},
	AllyRequestMetal = {
		delay = 10,
		stackedDelay = true,
		soundEffect = "AllyRequest",
	},
	IdleConstructors = {
		delay = 45,
		stackedDelay = true,
	},

	-- Alerts
	NukeLaunched = {
		delay = 5,
		soundEffect = "NukeAlert",
		resetOtherEventDelay = {"AlliedNukeLaunched"},
		stackedDelay = true,
	},
	AlliedNukeLaunched = {
		delay = 5,
		soundEffect = "NukeAlert",
		stackedDelay = true,
	},
	LrpcTargetUnits = {
		delay = 30,
		stackedDelay = true,
	},

	-- Unit Ready
	["UnitReady/RagnarokIsReady"] = {
		delay = 120,
		stackedDelay = true,
	},
	["UnitReady/CalamityIsReady"] = {
		delay = 120,
		stackedDelay = true,
	},
	["UnitReady/StarfallIsReady"] = {
		delay = 120,
		stackedDelay = true,
	},
	["UnitReady/AstraeusIsReady"] = {
		delay = 120,
		stackedDelay = true,
	},
	["UnitReady/SolinvictusIsReady"] = {
		delay = 120,
		stackedDelay = true,
	},
	["UnitReady/TitanIsReady"] = {
		delay = 120,
		stackedDelay = true,
	},
	["UnitReady/ThorIsReady"] = {
		delay = 120,
		stackedDelay = true,
	},
	["UnitReady/JuggernautIsReady"] = {
		delay = 120,
		stackedDelay = true,
	},
	["UnitReady/BehemothIsReady"] = {
		delay = 120,
		stackedDelay = true,
	},
	["UnitReady/FlagshipIsReady"] = {
		delay = 120,
		stackedDelay = true,
	},
	["UnitReady/FusionIsReady"] = {
		delay = 120,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"AdvancedFusionIsReady"},
	},
	["UnitReady/AdvancedFusionIsReady"] = {
		delay = 120,
		stackedDelay = true,
		rulesEnable = {"AdvancedFusionIsReady"},
	},
	["UnitReady/NuclearSiloIsReady"] = {
		delay = 120,
		stackedDelay = true,
	},
	["UnitReady/Tech2UnitReady"] = {
		delay = 9999999,
		rulesEnable = {"PlayerHasTech2"},
	},
	["UnitReady/Tech3UnitReady"] = {
		delay = 9999999,
		rulesEnable = {"PlayerHasTech2", "PlayerHasTech3"},
	},
	["UnitReady/Tech4UnitReady"] = {
		delay = 9999999,
		rulesEnable = {"PlayerHasTech2", "PlayerHasTech3","PlayerHasTech4"},
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
	["UnitDetected/Tech2UnitDetected"] = {
		delay = 9999999,
		rulesEnable = {"Tech2UnitDetected"},
	},
	["UnitDetected/Tech3UnitDetected"] = {
		delay = 9999999,
		rulesEnable = {"Tech2UnitDetected", "Tech3UnitDetected"},
	},
	["UnitDetected/Tech4UnitDetected"] = {
		delay = 9999999,
		rulesEnable = {"Tech2UnitDetected", "Tech3UnitDetected", "Tech4UnitDetected"},
	},
	--FatboyDetected = {
	--	delay = 300,
	--	stackedDelay = true,
	--	rulesPlayOnlyIfDisabled = {"Tech3UnitDetected", "Tech4UnitDetected"},
	--},

	-- Generic Detected
	["UnitDetected/EnemyDetected"] = {
		delay = 120,
		stackedDelay = true,
	},
	["UnitDetected/AircraftDetected"] = {
		delay = 120,
		stackedDelay = true,
	},
	["UnitDetected/AirTransportDetected"] = {
		delay = 120,
		stackedDelay = true,
	},
	["UnitDetected/DroneDetected"] = {
		delay = 120,
		stackedDelay = true,
	},

	-- Game Enders - 30 sec delay
	["UnitDetected/NuclearSiloDetected"] = {
		delay = 30,
		stackedDelay = true,
	},
	["UnitDetected/CalamityDetected"] = {
		delay = 30,
		stackedDelay = true,
	},
	["UnitDetected/RagnarokDetected"] = {
		delay = 30,
		stackedDelay = true,
	},
	["UnitDetected/StarfallDetected"] = {
		delay = 30,
		stackedDelay = true,
	},

	-- Urgent Generic - 30 sec delay
	["UnitDetected/MinesDetected"] = {
		delay = 30,
		stackedDelay = true,
	},
	["UnitDetected/StealthyUnitsDetected"] = {
		delay = 30,
		stackedDelay = true,
	},
	["UnitDetected/LrpcDetected"] = {
		delay = 30,
		stackedDelay = true,
	},
	["UnitDetected/EmpSiloDetected"] = {
		delay = 30,
		stackedDelay = true,
	},
	["UnitDetected/TacticalNukeSiloDetected"] = {
		delay = 30,
		stackedDelay = true,
	},
	["UnitDetected/LongRangeNapalmLauncherDetected"] = {
		delay = 30,
		stackedDelay = true,
	},

	-- Tech 4 - 120 sec delay

	-- Tech 3.5 - 120 sec delay
	-- Armada
	["UnitDetected/TitanDetected"] = {
		delay = 120,
		stackedDelay = true,
		rulesEnable = {"Tech3-5UnitDetected"},
	},
	["UnitDetected/ThorDetected"] = {
		delay = 120,
		stackedDelay = true,
		rulesEnable = {"Tech3-5UnitDetected"},
	},
	-- Cortex
	["UnitDetected/JuggernautDetected"] = {
		delay = 120,
		stackedDelay = true,
		rulesEnable = {"Tech3-5UnitDetected"},
	},
	["UnitDetected/BehemothDetected"] = {
		delay = 120,
		stackedDelay = true,
		rulesEnable = {"Tech3-5UnitDetected"},
	},
	-- Legion
	["UnitDetected/SolinvictusDetected"] = {
		delay = 120,
		stackedDelay = true,
		rulesEnable = {"Tech3-5UnitDetected"},
	},
	["UnitDetected/AstraeusDetected"] = {
		delay = 120,
		stackedDelay = true,
		rulesEnable = {"Tech3-5UnitDetected"},
	},

	-- Tech 3 - 180 sec delay
	-- Armada
	["UnitDetected/RazorbackDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	["UnitDetected/MarauderDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	["UnitDetected/VanguardDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	["UnitDetected/LunkheadDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	["UnitDetected/EpochDetected"] = { -- Flagships should be considered T3 for this context, despite being built from T2 factory.
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	-- Cortex
	["UnitDetected/DemonDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	["UnitDetected/ShivaDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	["UnitDetected/CataphractDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	["UnitDetected/KarganethDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	["UnitDetected/CatapultDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	["UnitDetected/BlackHydraDetected"] = { -- Flagships should be considered T3 for this context, despite being built from T2 factory.
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	-- Legion
	["UnitDetected/PraetorianDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	["UnitDetected/JavelinDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	["UnitDetected/MyrmidonDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	["UnitDetected/KeresDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	["UnitDetected/CharybdisDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	["UnitDetected/DaedalusDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	["UnitDetected/NeptuneDetected"] = { -- Flagships should be considered T3 for this context, despite being built from T2 factory.
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	["UnitDetected/CorinthDetected"] = { -- Flagships should be considered T3 for this context, despite being built from T2 factory.
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech4UnitDetected"},
		rulesEnable = {"Tech3UnitDetected"},
	},
	-- Other
	["UnitDetected/FlagshipDetected"] = { -- Flagships should be considered T3 for this context, despite being built from T2 factory.
		delay = 180,
		stackedDelay = true,
	},

	-- Tech 2.5 - 180 sec delay
	-- Armada
	["UnitDetected/StarlightDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	["UnitDetected/AmbassadorDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	["UnitDetected/FatboyDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	["UnitDetected/SharpshooterDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	-- Cortex
	["UnitDetected/MammothDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	["UnitDetected/ArbiterDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	["UnitDetected/TzarDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	["UnitDetected/NegotiatorDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	["UnitDetected/TremorDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	["UnitDetected/BanisherDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	["UnitDetected/DragonDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	-- Legion
	["UnitDetected/ThanatosDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	["UnitDetected/ArquebusDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	["UnitDetected/IncineratorDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	["UnitDetected/PrometheusDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	["UnitDetected/MedusaDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	["UnitDetected/InfernoDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	["UnitDetected/TyrannusDetected"] = {
		delay = 180,
		stackedDelay = true,
		rulesPlayOnlyIfDisabled = {"Tech3-5UnitDetected", "Tech4UnitDetected"},
		rulesEnable = {"Tech2-5UnitDetected"},
	},
	["UnitDetected/LicheDetected"] = { -- Scary one, so shorter delay
		delay = 30,
		stackedDelay = true,
	},

	-- Tech 2 - 240 sec delay

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
	WelcomeShort = {
		delay = 0,
		notext = true,
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
