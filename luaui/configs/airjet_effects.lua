
return {

	-- land vechs
	["cortorch"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 5, length = 24, piece = "thruster1", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 8, length = 32, piece = "thruster2", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 12, length = 64, piece = "thruster3", light = 1 },
	},

	-- scouts
	["armpeep"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 20, piece = "jet1" },
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 20, piece = "jet2" },
	},
	["corfink"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 2.3, length = 18, piece = "thrusta" },
		{ color = { 0.7, 0.4, 0.1 }, width = 2.3, length = 18, piece = "thrustb" },
	},
	-- fighters
	["armfig"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 45, piece = "thrust" },
	},
	["corveng"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 3.3, length = 24, piece = "thrust1" },
		{ color = { 0.7, 0.4, 0.1 }, width = 3.3, length = 24, piece = "thrust2" },
	},
	["armsfig"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 4, length = 25, piece = "thrust" },
	},
	["armsfig2"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 8, length = 45, piece = "thrust" },
	},
	["corsfig"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 3, length = 32, piece = "thrust" },
	},
	["corsfig2"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 8, length = 45, piece = "thrust" },
	},
	["armhawk"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 7, length = 45, piece = "thrust", light = 1 },
	},
	["corvamp"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 35, piece = "thrusta" },
	},
	["legfig"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 2, length = 15, piece = "thrust" },
	},
	["legionnaire"] = {
		{ color = { 0.2, 0.4, 0.5 }, width = 3.5, length = 30, piece = "thrusta" },
	},
	["legvenator"] = {
		{ color = { 0.1, 0.6, 0.4 }, width = 3, length = 24, piece = "lthrust" },
		{ color = { 0.1, 0.6, 0.4 }, width = 3, length = 24, piece = "rthrust" },
	},
	-- radar
	["armawac"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 30, piece = "thrust", light = 1 },
	},
	["corawac"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 4, length = 25, piece = "lthrust", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 4, length = 50, piece = "mthrust", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 4, length = 25, piece = "rthrust", light = 1 },
	},
	["legwhisper"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 5, length = 37, piece = "bigAirJet1", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 2, length = 50, piece = "littleAirJet", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 5, length = 38, piece = "bigAirJet2", light = 1 },
	},
	["legafigdef"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 3, length = 37, piece = "rightAirjet", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 6, length = 50, piece = "mainAirjet", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 3, length = 38, piece = "leftAirjet", light = 1 },
	},
	["corhunt"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 4, length = 37, piece = "thrust", light = 1 },
	},
	--["armsehak"] = {
	--	{ color = { 0.2, 0.8, 0.2 }, width = 3.5, length = 37, piece = "thrust", light = 1 },
	--},
	--drones

	["armdroneold"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 1.5, length = 6, piece = "thrustl", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 1.5, length = 6, piece = "thrustr", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 2, length = 8, piece = "thrustm", light = 1 }, --, xzVelocity = 1.5 -- removed xzVelocity else the other thrusters get disabled as well
	},
	["armdrone"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 1.5, length = 6, piece = "thrustl", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 1.5, length = 6, piece = "thrustr", light = 1 },
	},
	["armtdrone"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 1.5, length = 6, piece = "thrustl", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 1.5, length = 6, piece = "thrustr", light = 1 },
	},
	-- transports
	["armatlas"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 3, length = 12, piece = "thrustl", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 3, length = 12, piece = "thrustr", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 15, piece = "thrustm", light = 1 }, --, xzVelocity = 1.5 -- removed xzVelocity else the other thrusters get disabled as well
	},
	["armhvytrans"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 5, length = 16, piece = "thrustfl", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 5, length = 16, piece = "thrustfr", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 15, piece = "thrustbl", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 15, piece = "thrustbr", light = 1 }, --, xzVelocity = 1.5 -- removed xzVelocity else the other thrusters get disabled as well
	},
	["corvalk"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 17, piece = "thrust1", emitVector = { 0, 1, 0 }, light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 17, piece = "thrust3", emitVector = { 0, 1, 0 }, light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 17, piece = "thrust2", emitVector = { 0, 1, 0 }, light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 17, piece = "thrust4", emitVector = { 0, 1, 0 }, light = 1 },
	},
	["corhvytrans"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 17, piece = "thrustfl", emitVector = { 0, 1, 0 }, light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 17, piece = "thrustfr", emitVector = { 0, 1, 0 }, light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 17, piece = "thrustbl", emitVector = { 0, 1, 0 }, light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 17, piece = "thrustbr", emitVector = { 0, 1, 0 }, light = 1 },
	},
	["armdfly"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 35, piece = "thrusta", xzVelocity = 1.5, light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 35, piece = "thrustb", xzVelocity = 1.5, light = 1 },
	},
	["corseah"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 13, length = 25, piece = "thrustrra", emitVector = { 0, 1, 0 }, light = 0.75 },
		{ color = { 0.1, 0.4, 0.6 }, width = 13, length = 25, piece = "thrustrla", emitVector = { 0, 1, 0 }, light = 0.75 },
		{ color = { 0.1, 0.4, 0.6 }, width = 10, length = 25, piece = "thrustfra", emitVector = { 0, 1, 0 }, light = 0.75 },
		{ color = { 0.1, 0.4, 0.6 }, width = 10, length = 25, piece = "thrustfla", emitVector = { 0, 1, 0 }, light = 0.75 },
	},
	["legatrans"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 17, piece = "rightGroundThrust", emitVector = { 0, 1, 0 }, light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 17, piece = "leftGroundThrust", emitVector = { 0, 1, 0 }, light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 17, piece = "rightMainThrust", emitVector = { 0, 1, 0 }, light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 17, piece = "leftMainThrust", emitVector = { 0, 1, 0 }, light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 2, length = 8.5, piece = "rightMiniThrust", emitVector = { 0, 1, 0 }, light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 2, length = 8.5, piece = "leftMiniThrust", emitVector = { 0, 1, 0 }, light = 1 },
	},
	["legstronghold"] = {
		{ color = { 0.1, 0.6, 0.4 }, width = 3, length = 24, piece = "bthrust1", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 3, length = 24, piece = "bthrust2", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 3, length = 24, piece = "lthrust1", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 3, length = 24, piece = "lthrust2", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 3, length = 24, piece = "rthrust1", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 3, length = 24, piece = "rthrust2", emitVector = { 0, 1, 0 }, light = 0.6 },
	},

	-- gunships
	["armkam"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 3, length = 28, piece = "thrusta", xzVelocity = 1.5, light = 1, emitVector = { 0, 1, 0 } },
		{ color = { 0.7, 0.4, 0.1 }, width = 3, length = 28, piece = "thrustb", xzVelocity = 1.5, light = 1, emitVector = { 0, 1, 0 } },
	},
	["armblade"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 25, piece = "thrust", light = 1, xzVelocity = 1.5 },
	},
	["legmos"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 3, length = 12, piece = "thrust", emitVector = { 0, 0, -1 }, xzVelocity = 1.2, light = 1 },
	},
	["legmost3"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 4, length = 32, piece = "thrust", emitVector = { 0, 0, -1 }, xzVelocity = 3, light = 1 },
	},
	["legheavydrone"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 2, length = 16, piece = "thrusttrail", emitVector = { 0, 0, -1 }, xzVelocity = 1.5, light = 1 },
	},
	["corape"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 4, length = 24, piece = "rthrust", emitVector = { 0, 0, -1 }, xzVelocity = 1.5, light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 4, length = 24, piece = "lthrust", emitVector = { 0, 0, -1 }, xzVelocity = 1.5, light = 1 },
		--{color={0.1,0.4,0.6}, width=2.2, length=4.7, piece="lhthrust1", emitVector= {1,0,0}, light=1},
		--{color={0.1,0.4,0.6}, width=2.2, length=4.7, piece="rhthrust2", emitVector= {1,0,0}, light=1},
		--{color={0.1,0.4,0.6}, width=2.2, length=4.7, piece="lhthrust2", emitVector= {-1,0,0}, light=1},
		--{color={0.1,0.4,0.6}, width=2.2, length=4.7, piece="rhthrust1", emitVector= {-1,0,0}, light=1},
	},
	["armseap"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 5, length = 35, piece = "thrustm", light = 1 },
	},
	["corseap"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 3, length = 32, piece = "thrust", light = 1 },
	},
	["corcrw"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 12, length = 36, piece = "thrustrra", emitVector = { 0, 1, -1 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 12, length = 36, piece = "thrustrla", emitVector = { 0, 1, -1 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 10, length = 30, piece = "thrustfra", emitVector = { 0, 1, -1 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 10, length = 30, piece = "thrustfla", emitVector = { 0, 1, -1 }, light = 0.6 },
	},
	["corcrwh"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 12, length = 36, piece = "thrustrra", emitVector = { 0, 1, -1 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 12, length = 36, piece = "thrustrla", emitVector = { 0, 1, -1 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 10, length = 30, piece = "thrustfra", emitVector = { 0, 1, -1 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 10, length = 30, piece = "thrustfla", emitVector = { 0, 1, -1 }, light = 0.6 },
	},
	["corcrwt4"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 19, length = 50, piece = "thrustrra", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 19, length = 50, piece = "thrustrla", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 17, length = 44, piece = "thrustfra", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 17, length = 44, piece = "thrustfla", emitVector = { 0, 1, 0 }, light = 0.6 },
	},
	["legfort"] = {
		{ color = { 0.1, 0.6, 0.4 }, width = 3, length = 24, piece = "thrust1", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 3, length = 24, piece = "thrust2", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 3, length = 24, piece = "thrust3", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 3, length = 24, piece = "thrust4", emitVector = { 0, 1, 0 }, light = 0.6 },

		{ color = { 0.1, 0.6, 0.4 }, width = 3, length = 24, piece = "thrust5", emitVector = { 1, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 3, length = 24, piece = "thrust6", emitVector = { 1, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 3, length = 24, piece = "thrust7", emitVector = { 1, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 3, length = 24, piece = "thrust8", emitVector = { 1, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 6, length = 32, piece = "thrust9", emitVector = { 1, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 6, length = 32, piece = "thrust10", emitVector = { 1, 1, 0 }, light = 0.6 },
	},
	["legfortt4"] = {
		{ color = { 0.1, 0.6, 0.4 }, width = 6, length = 48, piece = "thrust1", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 6, length = 48, piece = "thrust2", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 6, length = 48, piece = "thrust3", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 6, length = 48, piece = "thrust4", emitVector = { 0, 1, 0 }, light = 0.6 },

		{ color = { 0.1, 0.6, 0.4 }, width = 6, length = 48, piece = "thrust5", emitVector = { 1, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 6, length = 48, piece = "thrust6", emitVector = { 1, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 6, length = 48, piece = "thrust7", emitVector = { 1, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 6, length = 48, piece = "thrust8", emitVector = { 1, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 12, length = 64, piece = "thrust9", emitVector = { 1, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 12, length = 64, piece = "thrust10", emitVector = { 1, 1, 0 }, light = 0.6 },
	},
	["corcut"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 3.7, length = 15, piece = "thrusta", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 3.7, length = 15, piece = "thrustb", light = 1 },
	},
	--["armbrawl"] = {
	--	{ color = { 0.1, 0.4, 0.6 }, width = 3.7, length = 15, piece = "thrust1", light = 1 },
	--	{ color = { 0.1, 0.4, 0.6 }, width = 3.7, length = 15, piece = "thrust2", light = 1 },
	--},

	-- bladewing
	["corbw"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 1.8, length = 7.5, piece = "thrusta" },
		{ color = { 0.1, 0.4, 0.6 }, width = 1.8, length = 7.5, piece = "thrustb" },
	},
	["cordroneold"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 1.2, length = 5, piece = "thrusta" },
		{ color = { 0.1, 0.4, 0.6 }, width = 1.2, length = 5, piece = "thrustb" },
	},
	["cordrone"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 1.2, length = 5, piece = "thrusta" },
		{ color = { 0.1, 0.4, 0.6 }, width = 1.2, length = 5, piece = "thrustb" },
	},
	["cortdrone"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 1.2, length = 5, piece = "thrusta" },
		{ color = { 0.1, 0.4, 0.6 }, width = 1.2, length = 5, piece = "thrustb" },
	},

	-- bombers
	["armstil"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 40, piece = "thrusta", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 40, piece = "thrustb", light = 1 },
	},
	["armthund"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 2, length = 17, piece = "thrust1", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 2, length = 17, piece = "thrust2" },
		{ color = { 0.7, 0.4, 0.1 }, width = 2, length = 17, piece = "thrust3" },
		{ color = { 0.7, 0.4, 0.1 }, width = 2, length = 17, piece = "thrust4", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 25, piece = "thrustc", light = 1.3 },
	},
	["armthundt4"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 9, length = 60, piece = "thrust1", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 9, length = 60, piece = "thrust2" },
		{ color = { 0.7, 0.4, 0.1 }, width = 9, length = 60, piece = "thrust3" },
		{ color = { 0.7, 0.4, 0.1 }, width = 9, length = 60, piece = "thrust4", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 13, length = 85, piece = "thrustc", light = 1.3 },
	},
	["armpnix"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 7, length = 35, piece = "thrusta", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 7, length = 35, piece = "thrustb", light = 1 },
	},
	["corshad"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 24, piece = "thrusta1", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 24, piece = "thrusta2", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 5, length = 33, piece = "thrustb", light = 1 },
	},
	["armliche"] = {
		{ color = { 0.8, 0.15, 0.15 }, width = 3.5, length = 44, piece = "thrusta", light = 1 },
		{ color = { 0.8, 0.15, 0.15 }, width = 3.5, length = 44, piece = "thrustb", light = 1 },
		{ color = { 0.8, 0.15, 0.15 }, width = 3.5, length = 44, piece = "thrustc", light = 1 },
	},
	["armlichet4"] = {
		{ color = { 0.8, 0.15, 0.15 }, width = 10.5, length = 132, piece = "thrusta", light = 1.5 },
		{ color = { 0.8, 0.15, 0.15 }, width = 10.5, length = 132, piece = "thrustb", light = 1.5 },
		{ color = { 0.8, 0.15, 0.15 }, width = 10.5, length = 132, piece = "thrustc", light = 1.5 },
	},
	["cortitan"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 35, piece = "thrusta1", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 35, piece = "thrusta2", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 35, piece = "thrustb1", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 35, piece = "thrustb2", light = 1 },
	},
	["armlance"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 40, piece = "thrust1", light = 1 },
	},
	["corhurc"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 8, length = 50, piece = "thrustb", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 35, piece = "thrusta1" },
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 35, piece = "thrusta2" },
	},
	["legnap"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 8, length = 50, piece = "thrustb", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 35, piece = "thrusta1" },
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 35, piece = "thrusta2" },
	},
	["legcib"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 25, piece = "lThrust", light = 1.3 },
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 25, piece = "rThrust", light = 1.3 },
	},
	["legkam"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 4, length = 25, piece = "thrust", light = 1 },
	},
	["legatorpbomber"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 4, length = 25, piece = "rightAJet", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 4, length = 25, piece = "leftAJet", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 3, length = 19, piece = "rightBJet", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 3, length = 19, piece = "leftBJet", light = 1 },
	},
	["legaca"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 5, length = 15, piece = "airjet1", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 5, length = 15, piece = "airjet2", light = 1 },
	},
	["armsb"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 4, length = 36, piece = "thrustc", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 2.2, length = 18, piece = "thrusta", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 2.2, length = 18, piece = "thrustb", light = 1 },
	},
	["corsb"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 3.3, length = 40, piece = "thrusta", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 3.3, length = 40, piece = "thrustb", light = 1 },
	},
	["legmineb"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 3.3, length = 40, piece = "lthrusttrail", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 3.3, length = 40, piece = "rthrusttrail", light = 1 },
	},
	["cords"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 10, length = 25, piece = "flarefl", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 10, length = 25, piece = "flarefr", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 10, length = 25, piece = "flarebl", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 10, length = 25, piece = "flarebr", emitVector = { 0, 1, 0 }, light = 0.6 },
	},
	["legphoenix"] = {
		{ color = { 0.1, 0.6, 0.4 }, width = 5, length = 36, piece = "rthrust", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 5, length = 36, piece = "rrthrust", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 5, length = 36, piece = "lthrust", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.6, 0.4 }, width = 5, length = 36, piece = "llthrust", emitVector = { 0, 1, 0 }, light = 0.6 },
	},
	["leglts"] = {
		{ color = { 0.1, 0.6, 0.4 }, width = 5, length = 32, piece = "lthrust", emitVector = { 0, 1, 0 }, light = 0.5 },
		{ color = { 0.1, 0.6, 0.4 }, width = 5, length = 32, piece = "rthrust", emitVector = { 0, 1, 0 }, light = 0.5 },
	},
	-- construction
	["armca"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 24, piece = "thrust", xzVelocity = 1.2 },
	},
	["armaca"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 6, length = 22, piece = "thrust", xzVelocity = 1.2 },
	},
	["corca"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 4, length = 15, piece = "thrust", xzVelocity = 1.2 },
	},
	["legca"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 4, length = 15, piece = "mainThrust", xzVelocity = 1.2 },
		{ color = { 0.1, 0.4, 0.6 }, width = 2, length = 7, piece = "thrustA", xzVelocity = 1.2 },
		{ color = { 0.1, 0.4, 0.6 }, width = 2, length = 7, piece = "thrustB", xzVelocity = 1.2 },
	},
	["coraca"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 6, length = 22, piece = "thrust", xzVelocity = 1.2 },
	},
	["armcsa"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 5, length = 17, piece = "thrusta" },
		{ color = { 0.2, 0.8, 0.2 }, width = 5, length = 17, piece = "thrustb" },
	},
	["corcsa"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 5, length = 17, piece = "thrust1" },
		{ color = { 0.2, 0.8, 0.2 }, width = 5, length = 17, piece = "thrust2" },
	},


	-- flying ships
	["armfepocht4"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 13, length = 27, piece = "thrustl1", light = 0.62 },
		{ color = { 0.7, 0.4, 0.1 }, width = 13, length = 27, piece = "thrustr1", light = 0.62 },
		{ color = { 0.7, 0.4, 0.1 }, width = 17, length = 38, piece = "thrustl2", light = 0.62 },
		{ color = { 0.7, 0.4, 0.1 }, width = 17, length = 38, piece = "thrustr2", light = 0.62 },
	},
	["corfblackhyt4"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 14, length = 27, piece = "thrustl1", light = 0.62 },
		{ color = { 0.7, 0.4, 0.1 }, width = 14, length = 27, piece = "thrustr1", light = 0.62 },
		{ color = { 0.7, 0.4, 0.1 }, width = 19, length = 38, piece = "thrustl2", light = 0.62 },
		{ color = { 0.7, 0.4, 0.1 }, width = 19, length = 38, piece = "thrustr2", light = 0.62 },
	},
	["cordronecarryair"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 13, length = 25, piece = "thrustl1", light = 0.58 },
		{ color = { 0.7, 0.4, 0.1 }, width = 13, length = 25, piece = "thrustr1", light = 0.58 },
		{ color = { 0.7, 0.4, 0.1 }, width = 13, length = 25, piece = "thrustl2", light = 0.58 },
		{ color = { 0.7, 0.4, 0.1 }, width = 13, length = 25, piece = "thrustr2", light = 0.58 },
	},
}
